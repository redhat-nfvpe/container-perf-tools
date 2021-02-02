package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"regexp"
	"strings"
	"syscall"

	pb "github.com/redhat-nfvpe/container-perf-tools/standalone-testpmd/rpc"
	"google.golang.org/grpc"
)

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

func main() {
	grpcPort := flag.Int("grpc-port", 9000, "grpc port")
	autoStart := flag.Bool("auto", false, "auto start in io mode")
	queues := flag.Int("queues", 1, "number of rxq/txq")
	ring := flag.Int("ring-size", 2048, "ring size")
	var pci pciArray
	flag.Var(&pci, "pci", "pci address, can specify multiple times")
	testpmdPath := flag.String("testpmd-path", "testpmd", "if not in PATH, specify the testpmd location")
	dpdkDriver := flag.String("dpdk-driver", "vfio-pci", "dpdk driver")
	flag.Parse()
	// if pci not specified on CLI, try enviroment vars
	if len(pci) == 0 {
		for _, e := range os.Environ() {
			pair := strings.SplitN(e, "=", 2)
			if match, _ := regexp.MatchString("PCIDEVICE", pair[0]); match {
				pci = append(pci, normalizePci(pair[1]))
			}
		}
	}
	// if still have no pci info, then exit
	if len(pci) == 0 {
		log.Fatalf("pci address not provided\n")
	}

	pciRecord := make(map[string]*pciInfo)
	if err := setupDpdkPorts(*dpdkDriver, pci, pciRecord); err != nil {
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
	pTestpmd.releaseHugePages()
}
