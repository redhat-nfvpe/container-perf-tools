package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"regexp"
	"strconv"
	"strings"
	"time"

	expect "github.com/google/goexpect"
	"github.com/lithammer/shortuuid"
	"k8s.io/kubernetes/pkg/kubelet/cm/cpuset"
)

const (
	startTimeout = 60 * time.Second
	cmdTimeout   = 1 * time.Second
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

func (t *testpmd) init(pci pciArray, queues int, ring int) error {
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
	cmd := "testpmd --socket-mem 1024,1024 -n 4 --proc-type auto"
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
	t.e.Expect(promptRE, cmdTimeout)

	return nil
}

func (t *testpmd) stop() error {
	t.e.Close()
	return nil
}

func (t *testpmd) runCmd(cmd string) error {
	t.e.Send(cmd + "\n")
	t.e.Expect(promptRE, cmdTimeout)
	return nil
}

func (t *testpmd) icmpMode() error {
	if t.running {
		t.runCmd("stop")
	}
	t.runCmd("set fwd icmpecho")
	t.runCmd("start")
	return nil
}

func (t *testpmd) ioMode() error {
	if t.running {
		t.runCmd("stop")
	}
	t.runCmd("set fwd io")
	t.runCmd("start")
	return nil
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
	var a uint8 = 0
	for i := 0; i < ports; i++ {
		a = a | (1 << i)
	}
	return fmt.Sprintf("%#x", a)
}

type pciArray []string

func (p *pciArray) String() string {
	return strings.Join(*p, " ")
}

func (p *pciArray) Set(value string) error {
	// todo: validate pci address exists
	*p = append(*p, value)
	return nil
}

func getProcCpuset() cpuset.CPUSet {
	content, err := ioutil.ReadFile("/proc/self/status")
	if err != nil {
		panic(err)
	}
	r := regexp.MustCompile(`Cpus_allowed_list:\s*(.*)\r?\n`)
	cpus := r.FindStringSubmatch(string(content))[1]
	return cpuset.MustParse(cpus)
}

func main() {
	cset := getProcCpuset()
	fmt.Printf("int to string: %s\n", intToString(cset.ToSlice()[:3], ","))
	queues := flag.Int("queues", 1, "number of rxq/txq")
	ring := flag.Int("ring-size", 2048, "ring size")
	var pci pciArray
	flag.Var(&pci, "pci", "pci address, can specify multiple times")
	flag.Parse()
	fmt.Printf("pci: %+q\n", pci)
	fmt.Printf("queues: %d\n", *queues)
	fmt.Printf("ring: %d\n", *ring)
	fmt.Printf("github.com/lithammer/shortuuid: %s\n", shortuuid.New())
	for i := 0; i <= 4; i++ {
		fmt.Printf("port mask %s\n", portMask(i))
	}
}
