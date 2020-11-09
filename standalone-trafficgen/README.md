
# Stand-alone-trafficgen 

Trafficgen with binary search capability is commonly used in end-to-end NFV performance test.
It makes sense to have the trafficgen seperated from the common tool set container and have its own 
container image. This allows us to quickly add new capabilities to the trafficgen without 
worrying the update impact to other tools in the common tool set container.

So for the trafficgen, there are too choices,
- This stand-alone trafficgen container. This can be used for either automation or manual
test.
- The common tool set container image. This can only be used for manual test.

## Prerequisites
+ 2MB or 1GB huge pages
+ isolated CPU for better performance
+ in BIOS, enable VT (cpu virtualization technology)
+ intel_iommu in kernel argument
+ Example kargs: `default_hugepagesz=1G hugepagesz=1G hugepages=8 intel_iommu=on iommu=pt isolcpus=4-11`

## Openshift integration demo

[![Watch the video](https://img.youtube.com/vi/C5s9DZC3D6c/maxresdefault.jpg)](https://youtu.be/C5s9DZC3D6c)

## Podman run example for manual test

`podman run -it --rm --privileged -v /dev:/dev -v /sys:/sys -v /lib/modules:/lib/modules --cpuset-cpus 4-11 -e pci_list=0000:03:00.0,0000:03:00.1 docker.io/cscojianzhan/trafficgen`

## Podman run example for automation

```
# start pod with port mapping
podman pod create -p 50051:50051 -n trafficgen
# start trex server in this pod
podman run -d --rm --privileged -v /dev:/dev -v /sys:/sys -v /lib/modules:/lib/modules --cpuset-cpus 4-11 --pod trafficgen -e pci_list=0000:03:00.0,0000:03:00.1  docker.io/cscojianzhan/trafficgen /root/trafficgen_entry.sh server
```

In the automation script, start the trafficgen,
`python client.py start`

To check the trafficgen status,
`python client.py status`

To get the test result,
`python client.py get-result`

To get the mac address of trafficgen test ports,
`python client.py get-mac`

## trafficgen client in other languages

The trafficgen and client is programmed with Python. The trafficgen provides gRPC 
interface so other programming languages can be used to control the trafficgen 
over gRPC.

The protocol buffer is defined in rpc.proto. When there is an update to this file, to 
re-generate python code,
`python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. rpc.proto`

Other language have their own tool for code generation.

