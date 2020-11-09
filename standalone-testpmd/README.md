
# Stand-alone-testpmd

Testpmd is commonly used in DPDK performance test.
It makes sense to have the testpmd seperated from the common tool set container and have its own 
container image. This allows us to quickly add new capabilities to the testpmd without 
worrying the update impact to other tools in the common tool set container.

## Prerequisites:
+ 2MB or 1GB huge pages
+ isolated CPU for better performance
+ in BIOS, enable VT (cpu virtualization technology)
+ intel_iommu in kernel argument
+ Example kargs: `default_hugepagesz=1G hugepagesz=1G hugepages=8 intel_iommu=on iommu=pt isolcpus=4-11`

## Openshift integration demo

[![Watch the video](https://img.youtube.com/vi/C5s9DZC3D6c/hqdefault.jpg)](https://youtu.be/C5s9DZC3D6c)

## Podman run example

### start testpmd server 

`podman run -it --rm --privileged -p 9000:9000 -v /sys:/sys -v /dev:/dev -v /lib/modules:/lib/modules --cpuset-cpus 5,7,9,11 docker.io/cscojianzhan/testpmd /root/testpmd-wrapper -pci 86:00:0 -pci 86:00:1`

### control testpmd from a client

The sample client can be used to control the testpmd. The client can be on the same machine as the testpmd server or remotely. 
If running the client remotely, option -server is used to specify the testpmd server address, -grpc-port is used to specify
the server grpc port (by default 9000 is used).

To start the testpmd IO forwarding (so the testpmd simulate a L2 switch),
`client-example io`

To start the testpmd MAC forwarding (so the testpmd simulate a L3 gateway),
`client-example -peer-mac 0,<port0-peer-mac> -peer-mac 1,<port1-peer-mac> mac`

To start the testpmd icmp mode (so it response to ping),
`client-example icmp`

To list the testpmd ports ,
`client-example ports`

## testpmd client in other languages

The testpmd server and client is programmed with golang. The testpmd server provides gRPC 
interface so other programming languages can be used to control the testpmd 
over gRPC.

The protocol buffer is defined in rpc.proto. When there is an update to this file, to 
re-generate golang code,
`cd rpc; protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative rpc.proto`

Other language have their own tool for code generation.

