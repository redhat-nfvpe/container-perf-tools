package main

import (
	"fmt"
	"log"
	"regexp"
	"strings"
	"time"
	"path/filepath"
	"os"

	expect "github.com/google/goexpect"
	"github.com/lithammer/shortuuid"
)

const (
	startTimeout = 60 * time.Second
	cmdTimeout   = 1 * time.Second
	// page size in Mbyte per port
	pageSizePerPort = 1024
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
	// setup socket-mem based on pci numa node
	memNode0, memNode1 := 0, 0
	for _, p := range pci {
		if numa, err := getNumaNode(p); err == nil {
			if numa == 0 {
				memNode0 += 1024
			} else if numa == 1 {
				memNode1 += 1024
			} else {
				return fmt.Errorf("Only numa 0,1 are expected but numa %d is detected on pci %s", numa, p)
			}
		} else {
			return err
		}
	}
	cmd := fmt.Sprintf("%s --socket-mem %d,%d -n 4 --proc-type auto", testpmdPath, memNode0, memNode1)
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
	if submatchList := macRe.FindStringSubmatch(output); submatchList != nil {
		mac := submatchList[1]
		if strings.Contains(mac, ":") {
			return mac, nil
		}
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

func (t *testpmd) releaseHugePages() error {
	files, err := filepath.Glob(fmt.Sprintf("/dev/hugepages/%s*", t.filePrefix))
	if err != nil {
    		return err
	}

	for _, f := range files {
	    	if err := os.Remove(f); err != nil {
        		return err
    		}
	}
	return nil
}
