package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"
)

const (
	pciDeviceDir = "/sys/bus/pci/devices/"
	pciDriverDir = "/sys/bus/pci/drivers/"
)

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

type kdDrivers struct {
	kernel string
	dpdk   string
}

type deviceDriverMap map[string]*kdDrivers

var (
	intelDefaultDrivers = &kdDrivers{kernel: "i40e", dpdk: "vfio-pci"}
	mlxDefaultDrivers   = &kdDrivers{kernel: "mlx5_core", dpdk: "mlx5_core"}
)

var vendorDriverMap = map[string]deviceDriverMap{
	"0x8086": {
		"default": mlxDefaultDrivers,
	},
	"0x15b3": {
		"default": mlxDefaultDrivers,
	},
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

func getDriverFromDeviceVendor(vendor string, device string) (string, error) {
	deviceMap, ok := vendorDriverMap[vendor]
	if !ok {
		return "", fmt.Errorf("device driver map not defined for vendor %s", vendor)
	}
	driver, ok := deviceMap[device]
	if ok {
		return driver.kernel, nil
	}
	// fall back to default driver for this vendor
	driver, ok = deviceMap["default"]
	if ok {
		return driver.kernel, nil
	}
	return "", fmt.Errorf("device driver map not defined for vendor %s", vendor)
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
		if record[p].driverCur == record[p].kmod {
			// mlnx case, kernel driver is used by dpdk
			continue
		}
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
