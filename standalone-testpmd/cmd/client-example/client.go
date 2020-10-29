package main

import (
	"context"
	"flag"
	"fmt"
	"log"
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
	pci := flag.String("pci", "0000:86:00.0", "pci address")
	var peerMacs macArray
	flag.Var(&peerMacs, "peer-mac", "peer mac address, can specify multiple times")
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
		r, err := c.MacMode(ctx, &pb.PeerMacs{MacAddress: peerMacs})
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
	}
}
