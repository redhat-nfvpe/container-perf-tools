package main

import (
	"context"
	"fmt"
	"log"
	"regexp"
	"strconv"

	empty "github.com/golang/protobuf/ptypes/empty"
	pb "github.com/redhat-nfvpe/container-perf-tools/standalone-testpmd/rpc"
)

type server struct {
	pb.UnimplementedTestpmdServer
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
	pciAddr := normalizePci(in.PciAddress)
	log.Printf("GetPortInfo: %s\n", pciAddr)
	output, err := pTestpmd.getPortInfo(pciAddr)
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

func (s *server) GetFwdInfo(ctx context.Context, in *empty.Empty) (*pb.FwdInfo, error) {
	log.Printf("GetFwdInfo:\n")
	output, err := pTestpmd.getFwdInfo()
	if err != nil {
		return &pb.FwdInfo{}, err
	}
	return &pb.FwdInfo{FwdInfoStr: output}, nil
}

func (s *server) ClearFwdInfo(ctx context.Context, in *empty.Empty) (*pb.Success, error) {
	log.Printf("ClearFwdInfo:\n")
	_, err := pTestpmd.clearFwdInfo()
	if err != nil {
		return &pb.Success{Success: false}, err
	}
	return &pb.Success{Success: true}, nil
}
