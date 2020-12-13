package main

import (
	"fmt"
	"log"
	"regexp"
	"strings"
	"time"

	expect "github.com/google/goexpect"
	"github.com/lithammer/shortuuid"
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
	if _, _, err := t.e.Expect(promptRE, startTimeout); err != nil {
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
	log.Println(output)
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
	if t.running {
		if _, err := t.runCmd("stop"); err != nil {
			return err
		}
		t.running = false
	}
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

func (t *testpmd) getFwdInfo() (string, error) {
	return t.runCmd("show fwd stats all")
}

func (t *testpmd) clearFwdInfo() (string, error) {
	return t.runCmd("clear fwd stats all")
}
