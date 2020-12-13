package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/golang/protobuf/ptypes/empty"
	pb "github.com/redhat-nfvpe/container-perf-tools/standalone-testpmd/rpc"
	"google.golang.org/grpc"
)

type macArray []string

func (p *macArray) String() string {
	return strings.Join(*p, " ")
}

func (p *macArray) Set(value string) error {
	*p = append(*p, value)
	return nil
}

func main() {
	grpcPort := flag.Int("grpc-port", 9000, "grpc port")
	serverIP := flag.String("server", "127.0.0.1", "testpmd server")
	pci := flag.String("pci", "0000:86:00.0", "pci address to get mac or port info from")
	var peerMacs macArray
	flag.Var(&peerMacs, "peer-mac", "format: <port number>,<mac>, can specify multiple times")
	flag.Parse()

	cmdArgs := flag.Args()
	cmd := ""
	if len(cmdArgs) > 0 {
		cmd = cmdArgs[0]
	}

	grpcAddress := fmt.Sprintf("%s:%d", *serverIP, *grpcPort)

	// Set up a connection to the server.
	conn, err := grpc.Dial(grpcAddress, grpc.WithInsecure(), grpc.WithBlock())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewTestpmdClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	switch cmd {
	case "get-mac":
		r, err := c.GetMacAddress(ctx, &pb.Pci{PciAddress: *pci})
		if err != nil {
			log.Fatalf("could not get response: %v", err)
		}
		log.Printf("%s mac address: %s", *pci, r.MacAddress)
	case "io":
		r, err := c.IoMode(ctx, &empty.Empty{})
		if err != nil {
			log.Fatalf("could not get response: %v", err)
		}
		if r.Success {
			log.Printf("io mode started\n")
		} else {
			log.Fatalf("Failed to start io fwd")
		}
	case "mac":
		var mPeer []*pb.PeerMac
		for _, v := range peerMacs {
			s := strings.Split(v, ",")
			if len(s) != 2 {
				log.Fatalf("illegal peer-mac format: %s", v)
			}
			p := &pb.PeerMac{}
			i, err := strconv.Atoi(s[0])
			if err != nil {
				log.Fatalf("illegal port number in peer-mac: %s", v)
			}
			p.PortNum = int32(i)
			p.MacAddress = s[1]
			mPeer = append(mPeer, p)
		}
		r, err := c.MacMode(ctx, &pb.PeerMacs{PeerMac: mPeer})
		if err != nil {
			log.Fatalf("could not get response: %v", err)
		}
		if r.Success {
			log.Printf("mac mode started\n")
		} else {
			log.Fatalf("Failed to start mac fwd")
		}
	case "icmp":
		r, err := c.IcmpMode(ctx, &empty.Empty{})
		if err != nil {
			log.Fatalf("could not get response: %v", err)
		}
		if r.Success {
			log.Printf("icmp mode started\n")
		} else {
			log.Fatalf("Failed to start icmp fwd")
		}
	case "ports":
		r, err := c.ListPorts(ctx, &empty.Empty{})
		if err != nil {
			log.Fatalf("could not get response: %v", err)
		}
		for _, port := range r.PortInfo {
			fmt.Printf("port number: %d, mac: %s, pci: %s\n", port.PortNum, port.MacAddress, port.PciAddress)
		}
	case "port":
		r, err := c.GetPortInfo(ctx, &pb.Pci{PciAddress: *pci})
		if err != nil {
			log.Fatalf("could not get response: %v", err)
		}
		fmt.Printf("portNum: %d, mac: %s, pci: %s\n", r.PortNum, r.MacAddress, r.PciAddress)
	case "fwd-info":
		r, err := c.GetFwdInfo(ctx, &empty.Empty{})
		if err != nil {
			log.Fatalf("could not get response: %v", err)
		}
		fmt.Printf("%s\n", r.FwdInfoStr)
	case "clear-fwd-info":
		_, err := c.ClearFwdInfo(ctx, &empty.Empty{})
		if err != nil {
			log.Fatalf("could not get response: %v", err)
		}
		fmt.Printf("port forwarding info cleared\n")
	default:
		fmt.Println("supported commands: get-mac ports port io mac icmp fwd-info clear-fwd-info")
	}
}
