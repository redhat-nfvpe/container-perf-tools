
# container-perf-tools

This project contains a set of containerized performance test tool that can be used in Kubernetes enviroment to 
evaluate performance related to data plane, such as dpdk enabled network throughput, real time kernel latency, 
etc.

## Directory layout for all-in-one test container

The Dockerfile file under the root directory defines the all-in-one container.

The all-in-one container is constructed in such a way that the tester has the flexiblity to customize a tool execution without rebuilding the container image. 

For the all-in-one container, it's expectd each tool will be located in its own directory with name cmd.sh. For example under directory cyclictest, the cmd.sh is the entrance for cyclictest. For testpmd there will be a directory testpmd with cmd.sh under that directory. The tool script should expect its arguments/options via enviroment variables.

The run.sh under the repo root diretory is the entrance for the container image. Once it is started, it will git pull this repo to get the latest tools. It then executes the specified tool based on the yaml specification, with the enviroment variables in the yaml file. The yaml examples for k8s can be found under the sample-yamls/ directory

## Standalone test tool containers

Each test tool can also be built as a standalone test container (versus included in the all-in-one container). Some of the dockerfiles can be found under the root directory, suck as Dockerfile-cyclictest, Dockerfile-oslat. Other standalone test containers may have their dockerfiles located in the individual sub directories. Such as the standalone-testpmd and standalone-trafficgen containers. To build those containers one need to go to the individual directory and run docker build. 

## How to run the all-in-one test container 

There are two types of container tool use cases. The first type is to run the performance tool as container 
image in a Kubernetes cluster and the performance tool will collect and report performance metics of the 
underlying system; this type includes sysjitter, cyclictest, and uperf. The second type lives outside Kubernetes 
cluster and is used externally to evaluate the Kubernetest cluster; this type includes trex trafficgen. Sometimes 
we need to use this two types together to evaluate the system; for example, to evaluate the SRIOV throughput, we 
can run a DPDK testpmd container inside Kubernetes cluster, and outside the cluster use trex trafficgen
container to do binary search in order to evaluate the highest throughput supported by the SRIOV ports.

### common yaml variables for the all-in-one test container

All the test scripts use enviroment varibles as input. There are two types of variables, the first type is common 
to all tools. The second type is tool specific. Both are defined as name/value pair under the container env spec.

The common env variables include:
+ GIT_URL: this points to your github fork of this repository, or this respository if no fork
+ tool: which performance test to run, essentially it is one of the tool directory name

The tool specific variables will be mentioned under each tool sector.

### test result log

When the test is complete, to get the test result, use "oc logs" or "kubectl logs" command to examine the 
container log. Currently there is a work in progress to kick off the test and present the test result via 
rest API.

### uperf test 

uperf test involves two containers, a master and a worker. The master needs to know the ip address of the worker. This means the worker need to started first. The ip address of the slave will be entered as input value for env
varible "uperfSlave" in the master yaml file. In sample-yamls/pod-uperf-master.yaml, a variable is used as the 
"uperfSlave" value and this is to make the automation easier, for example the worker and master can be started liks this,
```
#!/usr/bin/bash
if ! oc get pod uperf-slave 1>&2 2>/dev/null; then
	oc create -f pod-uperf-slave.yaml
fi
oc delete pod uperf-master 2>/dev/null

while true; do
	status=$(oc get pods uperf-slave -o json | jq -r '.status.phase')
	if [[ "${status}" == "Running" ]]; then
		break
	fi
	sleep 5s
done
export slave=$(oc get pods uperf-slave -o json | jq -r '.status.podIP')
envsubst < pod-uperf-master.yaml | oc create -f -
```
uperf supports the following enviroment variables:
+ tool: uperf, run this uperf tool
+ uperfSlave: the ip address of the worker pod
+ size: the tcp write buffer size
+ threads: number of threads 


### cyclictest test

cyclictest is used to evaluate the real time kernel scheduler latency. 

cyclictest supports the following enviroment variables:
+ tool: cyclictest, run this cyclictest tool
+ DURATION: how long the cyclictest will be run, default: 24 hours
+ DISABLE_CPU_BALANCE: choice of y/n; if enabled, the cpu that runs cyclictest will have workload balance disable
+ stress_tool: choice of false/stress-ng/rteval
+ rt_priority: which rt priority is used to run the cyclictest; default 99


### sysjitter test

sysjitter is used to evaluate the system scheduler jitter. This test in certain way can predict the zero loss 
throughput for high speed network.

sysjitter supports the following enviroment variables:
+ tool: sysjitter, run this sysjitter tool
+ RUNTIME_SECONDS: how many seconds to run the sysjitter test, default 10 seconds
+ THRESHOLD_NS: default 200 ns
+ DISABLE_CPU_BALANCE: choice of y/n; if enabled, the cpu that runs sysjitter will have workload balance disabled
+ USE_TASKSET: choice of y/n; if enabled, use taskset to pin the task cpu
+ manual: choice of y/n; if enabled, don't kick off sysjitter, this is for debug purpose

### testpmd test

testpmd is used to evaluate the system networking performance. The container expects two data ports (other than 
the default interface) and wires the two ports together via dpdk handling. For higher performance, the testpmd 
runs in io mode and it doesn't examine the packets and simply forwards packets from one port to another port,
in each direction. In general, testpmd forwarding is assumed not to be a bottleneck for the end to end 
throughput test.

testpmd supports the following enviroment variables:
+ tool: testpmd, run this testpmd tool
+ ring_size: ring buffer size, default 2048
+ manual: choice of y/n; if enabled, don't kick off testpmd, this is for debug purpose 

### trafficgen test

trafficgen is used to perform a binary search and find the maximum sustainable throughput. This tool expects 
two data ports (other than the default interface) and sends the traffic out of one port and expects the traffic 
received on the other port and vice versa. It begins at line rate and automatically adjust the traffic rate 
for next iteration based on the packet loss ratio at last iteration until it finds a traffic rate this has 
packet loss ratio meets the expectation.

This tool supports the following enviroment variables:
+ tool: trafficgen, run this trafficgen tool
+ pci_list: A comma-seperated data port pci address list, for example 0000:03:00.0,0000:03:00.1
+ validation_seconds: The final validation test duration, default 30 seconds
+ search_seconds: The test duration for each search iteration, default 10 seconds
+ sniff_seconds: The initial test duration before binary search begins, default 10 seconds
+ loss_ratio: Expected packet loss ration percentile, default 0.002
+ flows: Number of flows, default 1
+ frame_size: The packet frame size (layer 2 frame), default 64 bytes

Prerequisites:
+ 2MB or 1GB huge pages
+ Isolated CPU for better performance
+ Example kargs: `default_hugepagesz=1G hugepagesz=1G hugepages=8 intel_iommu=on iommu=pt isolcpus=4-11`

Podman run example:
`podman run -it --rm --privileged  -v /sys:/sys -v /dev:/dev -v /lib/modules:/lib/modules --cpuset-cpus 4-11 -e tool=trafficgen -e pci_list=0000:03:00.0,0000:03:00.1  -e validation_seconds=10 quay.io/jianzzha/perf-tools`

## How to run the standalone oslat test

Build the oslat container image:
`podman build -t <your repo tag> -f Dockerfile-oslat .`

A pre-build oslat container image is located at: quay.io/jianzzha/oslat

oslat supports the following enviroment variables:
+ RUNTIME_SECONDS: test duration in seconds
+ PRIO: RT priority used for the test threads
+ DISABLE_CPU_BALANCE: set to 'y' to disable cpu balancing; default to 'n'

A sample pod_oslat.yaml can be found under the sample-yamls directory.

## How to run hwlatdetect using oslat image

The hwlatdetect can be tested using the pre-build oslat image located at: quay.io/jianzzha/oslat

The following enviroment variables are used for hwlatdetect:
+ run_hwlatdetect: enable the hwlatdetect test
+ RUNTIME_SECONDS: test duration in seconds

A sample pod_hwlatdetect.yaml can be found under the sample-yamls directory.

## How to run the standalone cyclictest

Build the cyclictest container image:
`podman build -t <your repo tag> -f pod_cyclictest.yaml .`

cyclictest supports the following enviroment variables:
+ DURATION: test duration, default 24h
+ DISABLE_CPU_BALANCE: set to 'y' to disable cpu balancing; default to 'n'
+ INTERVAL: set cyclictest -i parameter, default 1000
+ rt_priority: set cyclictest thread priority, default 1

A sample pod_cyclictest.yaml can be found under the sample-yamls directory.

## How to run the standalone testpmd

Refer to the [standalone-testpmd directory](https://github.com/redhat-nfvpe/container-perf-tools/tree/master/standalone-testpmd)

## How to run the standalone trafficgen

Refer to the [standalone-trafficgen directory](https://github.com/redhat-nfvpe/container-perf-tools/tree/master/standalone-trafficgen)
