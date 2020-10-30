package main

import (
	"context"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	empty "github.com/golang/protobuf/ptypes/empty"
	expect "github.com/google/goexpect"
	"github.com/lithammer/shortuuid"
	pb "github.com/redhat-nfvpe/container-perf-tools/standalone-testpmd/rpc"
	"google.golang.org/grpc"
	"k8s.io/kubernetes/pkg/kubelet/cm/cpuset"
)

type server struct {
	pb.UnimplementedTestpmdServer
}

const (
	startTimeout = 60 * time.Second
	cmdTimeout   = 1 * time.Second
	pciDeviceDir = "/sys/bus/pci/devices/"
	pciDriverDir = "/sys/bus/pci/drivers/"
)

var (
	promptRE = regexp.MustCompile(`testpmd>`)
)

type testpmd struct {
	fwdMode    string
	running    bool
	filePrefix string
	e          *expect.GExpect
}

var pTestpmd *testpmd

func (t *testpmd) init(pci pciArray, queues int, ring int, testpmdPath string) error {
	ports := len(pci)
	nPmd := ports * queues
	// one extra core for mgmt in addition to the pmd
	nCores := nPmd + 1
	cset := getProcCpuset()
	if nCores > cset.Size() {
		log.Fatal("insufficient cores!")
	}
	clist := intToString(cset.ToSlice()[:nCores], ",")
	t.filePrefix = shortuuid.New()
	// use 1024,1024 so no need to worry about numa node
	cmd := fmt.Sprintf("%s --socket-mem 1024,1024 -n 4 --proc-type auto", testpmdPath)
	cmd = fmt.Sprintf("%s -l %s", cmd, clist)
	// use a unique file-prefix
	cmd = fmt.Sprintf("%s --file-prefix %s", cmd, t.filePrefix)
	// add each pci address
	for _, p := range pci {
		cmd = fmt.Sprintf("%s -w %s", cmd, p)
	}
	// this has to go first before the rest
	cmd = fmt.Sprintf("%s -- -i", cmd)
	cmd = fmt.Sprintf("%s --nb-cores=%d", cmd, nPmd)
	cmd = fmt.Sprintf("%s --nb-ports=%d", cmd, ports)
	cmd = fmt.Sprintf("%s --portmask=%s", cmd, portMask(ports))
	cmd = fmt.Sprintf("%s --rxq=%d", cmd, queues)
	cmd = fmt.Sprintf("%s --txq=%d", cmd, queues)
	cmd = fmt.Sprintf("%s --rxd=%d", cmd, ring)
	cmd = fmt.Sprintf("%s --txd=%d", cmd, ring)
	log.Printf("cmd: %s", cmd)
	e, _, err := expect.Spawn(cmd, startTimeout)
	if err != nil {
		log.Fatal(err)
	}
	t.e = e
	if _, _, err := t.e.Expect(promptRE, cmdTimeout); err != nil {
		return err
	}
	return nil
}

func (t *testpmd) stop() error {
	t.e.Close()
	return nil
}

func (t *testpmd) runCmd(cmd string) (string, error) {
	t.e.Send(cmd + "\n")
	output, _, err := t.e.Expect(promptRE, cmdTimeout)
	return output, err
}

func (t *testpmd) setFwdMode(mode string) error {
	if t.running {
		if _, err := t.runCmd("stop"); err != nil {
			return err
		}
		t.running = false
	}
	if _, err := t.runCmd("set fwd " + mode); err != nil {
		return err
	}
	if _, err := t.runCmd("start"); err != nil {
		return err
	}
	t.running = true
	return nil
}

func (t *testpmd) icmpMode() error {
	return t.setFwdMode("icmpecho")
}

func (t *testpmd) ioMode() error {
	return t.setFwdMode("io")
}

func (t *testpmd) macMode() error {
	return t.setFwdMode("mac")
}

func (t *testpmd) getMacAddress(pci string) (string, error) {
	output, err := t.runCmd("show device info " + pci)
	if err != nil {
		return "", err
	}
	macRe := regexp.MustCompile(`MAC address:\s*(([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2})`)
	mac := macRe.FindStringSubmatch(output)[1]
	if strings.Contains(mac, ":") {
		return mac, nil
	}
	return "", fmt.Errorf("couldn't get mac address for pci slot %s", pci)
}

func (t *testpmd) setPeerMac(portNum int32, peerMac string) error {
	cmd := fmt.Sprintf("set eth-peer %d %s", portNum, peerMac)
	_, err := t.runCmd(cmd)
	return err
}

func (t *testpmd) listPorts() (string, error) {
	return t.runCmd("show device info all")
}

func (t *testpmd) getPortInfo(pci string) (string, error) {
	return t.runCmd("show device info " + pci)
}

func intToString(a []int, delim string) string {
	b := ""
	for _, v := range a {
		if len(b) > 0 {
			b += delim
		}
		b += strconv.Itoa(v)
	}
	return b
}

func portMask(ports int) string {
	var a uint8
	for i := 0; i < ports; i++ {
		a = a | (1 << i)
	}
	return fmt.Sprintf("%#x", a)
}

type pciArray []string

//pci info, 1:1 map to pci array
type pciInfo struct {
	//driver previously
	driverPre string
	//driver current
	driverCur string
	//kernel driver
	//was this a kernel port before
	wasKernelPort bool
	//kernel driver
	kmod   string
	vendor string
	device string
}

//normalize PCI address with prefix 0000:
func normalizePci(pci string) string {
	var npci string
	if !strings.HasPrefix(pci, "0000:") {
		npci = "0000:" + pci
	} else {
		npci = pci
	}
	return npci
}

func (p *pciArray) String() string {
	return strings.Join(*p, " ")
}

func (p *pciArray) Set(value string) error {
	// normalize pci address to start with 0000: prefix
	pci := normalizePci(value)
	if _, err := os.Stat(pciDeviceDir + pci); os.IsNotExist(err) {
		log.Fatalf("invalid pci %s", value)
		return fmt.Errorf("invalid pci %s", value)
	}
	*p = append(*p, pci)
	return nil
}

func getProcCpuset() cpuset.CPUSet {
	content, err := ioutil.ReadFile("/proc/self/status")
	if err != nil {
		panic(err)
	}
	r := regexp.MustCompile(`Cpus_allowed_list:\s*([0-9,-]*)\r?\n`)
	cpus := r.FindStringSubmatch(string(content))[1]
	return cpuset.MustParse(cpus)
}

func isKernelDevice(pci string) bool {
	if _, err := os.Stat(pciDeviceDir + pci + "/net"); !os.IsNotExist(err) {
		log.Printf("isKernelDevice: %s is kernel port", pci)
		return true
	}
	log.Printf("isKernelDevice: %s not kernel port", pci)
	return false
}

func isDeviceBound(pci string) (bool, string) {
	driverPath := pciDeviceDir + pci + "/driver"
	if _, err := os.Stat(driverPath); !os.IsNotExist(err) {
		cmd := exec.Command("readlink", "-f", driverPath)
		out, _ := cmd.Output()
		d := strings.Split(strings.TrimSpace(string(out)), "/")
		driver := d[len(d)-1]
		log.Printf("isDeviceBound: %s is bound to %s", pci, driver)
		return true, driver
	}
	log.Printf("isDeviceBound: %s", driverPath)
	log.Printf("isDeviceBound: %s not bound", pci)
	return false, ""
}

func unbind(pci string) error {
	driverPath := pciDeviceDir + pci + "/driver"
	cmd := exec.Command("readlink", "-f", driverPath)
	out, _ := cmd.Output()
	log.Printf("unbind: echo %s > %s\n", pci, strings.TrimSpace(string(out))+"/unbind")
	return ioutil.WriteFile(strings.TrimSpace(string(out))+"/unbind", []byte(pci), 0200)
}

func bind(pci string, driver string) error {
	driverPath := pciDriverDir + driver
	log.Printf("bind: echo %s > %s\n", pci, driverPath+"/bind")
	return ioutil.WriteFile(driverPath+"/bind", []byte(pci), 0200)
}

func pciNewID(vendor string, device string, driver string) error {
	newIDPath := pciDriverDir + driver + "/new_id"
	log.Printf("pciNewID: echo %s %s > %s\n", vendor, device, newIDPath)
	return ioutil.WriteFile(newIDPath, []byte(vendor+" "+device), 0200)
}

func pciRemoveID(vendor string, device string, driver string) error {
	removeIDPath := pciDriverDir + driver + "/remove_id"
	log.Printf("pciRemoveID: echo %s %s > %s\n", vendor, device, removeIDPath)
	return ioutil.WriteFile(removeIDPath, []byte(vendor+" "+device), 0200)
}

type deviceDriver struct {
	device string
	vendor string
	kmod   string
}

var driverArray = []deviceDriver{
	{
		vendor: "0x8086",
		device: "0x158b",
		kmod:   "i40e",
	},
}

func getDriverFromDeviceVendor(vendor string, device string) (string, error) {
	for _, d := range driverArray {
		if d.vendor == vendor && d.device == device {
			return d.kmod, nil
		}
	}
	return "", fmt.Errorf("kmod not defined for vendor %s device %s", vendor, device)
}

func setupDpdkPorts(dpdkDriver string, pci pciArray, record map[string]*pciInfo) error {
	log.Printf("setupPorts: %+q\n", pci)
	for _, p := range pci {
		log.Printf("setupPorts: %s\n", p)
		info := &pciInfo{}
		record[p] = info
		info.wasKernelPort = false
		out, _ := ioutil.ReadFile(pciDeviceDir + p + "/vendor")
		info.vendor = strings.TrimSpace(string(out))
		out, _ = ioutil.ReadFile(pciDeviceDir + p + "/device")
		info.device = strings.TrimSpace(string(out))
		kmod, err := getDriverFromDeviceVendor(info.vendor, info.device)
		if err != nil {
			log.Fatal(err)
		}
		info.kmod = kmod
		bound, driver := isDeviceBound(p)
		if bound {
			info.driverPre = driver
			if isKernelDevice(p) {
				info.kmod = driver
				info.wasKernelPort = true
			} else if driver == dpdkDriver {
				// already on dpdk driver, skip
				info.driverCur = dpdkDriver
				continue
			}
			// unbind first
			unbind(p)
		}
		// set up new_id if not done yet
		if err := pciNewID(info.vendor, info.device, dpdkDriver); err != nil {
			return err
		}
		// small sleep to get new_id kick in
		time.Sleep(20 * time.Millisecond)
		if success, _ := isDeviceBound(p); !success {
			// bind the driver only if new_id didn't do the trick
			if err := bind(p, dpdkDriver); err != nil {
				return err
			}
		}
		info.driverCur = dpdkDriver
		pciRemoveID(info.vendor, info.device, dpdkDriver)
		time.Sleep(20 * time.Millisecond)
	}
	return nil
}

func restoreKernalPorts(pci pciArray, record map[string]*pciInfo) error {
	for _, p := range pci {
		if record[p].wasKernelPort {
			log.Printf("bind %s to %s\n", p, record[p].kmod)
			if err := unbind(p); err != nil {
				return err
			}
			time.Sleep(20 * time.Millisecond)
			if err := bind(p, record[p].kmod); err != nil {
				return err
			}
			time.Sleep(20 * time.Millisecond)
		}
	}
	return nil
}

func (s *server) GetMacAddress(ctx context.Context, in *pb.Pci) (*pb.MacAddress, error) {
	pci := normalizePci(in.PciAddress)
	log.Printf("GetMacAddress: PCI %v\n", pci)
	mac, err := pTestpmd.getMacAddress(pci)
	if err != nil {
		return &pb.MacAddress{MacAddress: ""}, err
	}
	return &pb.MacAddress{MacAddress: mac}, nil
}

func (s *server) IcmpMode(ctx context.Context, in *empty.Empty) (*pb.Success, error) {
	log.Printf("IcmpMode:\n")
	if err := pTestpmd.icmpMode(); err != nil {
		return &pb.Success{Success: false}, err
	}
	return &pb.Success{Success: true}, nil
}

func (s *server) IoMode(ctx context.Context, in *empty.Empty) (*pb.Success, error) {
	log.Printf("IoMode:\n")
	if err := pTestpmd.ioMode(); err != nil {
		return &pb.Success{Success: false}, err
	}
	return &pb.Success{Success: true}, nil
}

func (s *server) MacMode(ctx context.Context, in *pb.PeerMacs) (*pb.Success, error) {
	log.Printf("MacMode:\n")
	for _, peerMac := range in.PeerMac {
		log.Printf("port %d, peer mac %s\n", peerMac.PortNum, peerMac.MacAddress)
		if err := pTestpmd.setPeerMac(peerMac.PortNum, peerMac.MacAddress); err != nil {
			return &pb.Success{Success: false}, err
		}
	}
	if err := pTestpmd.macMode(); err != nil {
		return &pb.Success{Success: false}, err
	}
	return &pb.Success{Success: true}, nil
}

func (s *server) GetPortInfo(ctx context.Context, in *pb.Pci) (*pb.PortInfo, error) {
	log.Printf("GetPortInfo: %s\n", in.PciAddress)
	output, err := pTestpmd.getPortInfo(in.PciAddress)
	if err != nil {
		return &pb.PortInfo{}, err
	}
	numRe := regexp.MustCompile(`Port id:\s*(\S+)`)
	portNum := numRe.FindStringSubmatch(output)[1]
	macRe := regexp.MustCompile(`MAC address:\s*(\S+)`)
	mac := macRe.FindStringSubmatch(output)[1]
	pciRe := regexp.MustCompile(`Device name:\s*(\S+)`)
	pci := pciRe.FindStringSubmatch(output)[1]
	if portNum == "" || mac == "" || pci == "" {
		return &pb.PortInfo{}, fmt.Errorf("failed to find port info")
	}
	num, err := strconv.Atoi(portNum)
	if err != nil {
		return &pb.PortInfo{}, err
	}
	num32 := int32(num)
	return &pb.PortInfo{PortNum: num32, MacAddress: mac, PciAddress: pci}, nil
}

func (s *server) ListPorts(ctx context.Context, in *empty.Empty) (*pb.PortList, error) {
	log.Printf("ListPorts:\n")
	output, err := pTestpmd.listPorts()
	if err != nil {
		return &pb.PortList{}, err
	}
	var portInfoArray []*pb.PortInfo
	r := regexp.MustCompile(`Port id:\s*(\S+)\s*MAC address:\s*(\S+)\s*Device name:\s*(\S+)`)
	matches := r.FindAllStringSubmatch(output, -1)
	log.Printf("matches: %v\n", matches)
	for _, v := range matches {
		portInfo := &pb.PortInfo{}
		log.Printf("%s, %s:%s:%s\n", v[0], v[1], v[2], v[3])
		i, err := strconv.Atoi(v[1])
		if err != nil {
			return &pb.PortList{}, err
		}
		portInfo.PortNum = int32(i)
		portInfo.MacAddress = v[2]
		portInfo.PciAddress = v[3]
		portInfoArray = append(portInfoArray, portInfo)
	}
	return &pb.PortList{PortInfo: portInfoArray}, nil
}

func main() {
	grpcPort := flag.Int("grpc-port", 9000, "grpc port")
	autoStart := flag.Bool("auto", false, "auto start in io mode")
	queues := flag.Int("queues", 1, "number of rxq/txq")
	ring := flag.Int("ring-size", 2048, "ring size")
	var pci pciArray
	flag.Var(&pci, "pci", "pci address, can specify multiple times")
	testpmdPath := flag.String("testpmd-path", "testpmd", "if not in PATH, specify the testpmd location")
	flag.Parse()
	pciRecord := make(map[string]*pciInfo)
	if err := setupDpdkPorts("vfio-pci", pci, pciRecord); err != nil {
		log.Fatal(err)
	}

	pTestpmd = &testpmd{}
	if err := pTestpmd.init(pci, *queues, *ring, *testpmdPath); err != nil {
		log.Fatalf("%v", err)
	}
	if *autoStart {
		log.Printf("auto start io mode\n")
		if err := pTestpmd.ioMode(); err != nil {
			log.Fatal(err)
		}
	}

	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", *grpcPort))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterTestpmdServer(s, &server{})

	done := make(chan int)
	go func() error {
		// this should block
		err := s.Serve(lis)
		// return means the service is stopped, notify the main thread
		done <- 1
		return err
	}()

	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, os.Interrupt, syscall.SIGTERM)
	<-sigs
	s.Stop()
	// make sure grpc thread is done
	<-done
	pTestpmd.stop()
	if err := restoreKernalPorts(pci, pciRecord); err != nil {
		log.Fatal(err)
	}
}
