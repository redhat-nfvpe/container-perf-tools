
# container-perf-tools

This project contains a set of containerized performance test tools that can be used in Kubernetes environment to
evaluate performance related to data plane, such as dpdk enabled network throughput, real time kernel latency,
etc.

Each tool has a Dockerfile in its own subdirectory (e.g. cyclictest/Dockerfile, oslat/Dockerfile).

There is a Makefile available to build the containers. Run `make help` for instructions.

## CI/CD Pipeline

This repository includes a GitHub Actions workflow (`container-build-validation.yml`) that automatically validates container image builds on pull requests. The workflow:

- **Intelligent Change Detection**: Only builds containers that have been modified
- **Makefile Integration**: Uses the project's Makefile to build containers consistently
- **Targeted Containers**: Builds specific tool containers (cyclictest, hwlatdetect, oslat, rtla, stress-ng, dpdk-testpmd)
- **Basic Functionality Tests**: Validates that built containers can run basic commands
- **Parallel Builds**: Uses matrix builds for efficient parallel container building

The workflow triggers on:
- Pull requests that modify tool directories or the Makefile
- Manual workflow dispatch for full validation

## Running the tests

### General notes

The performance tools run as container images in a Kubernetes cluster and
collect and report performance metrics of the underlying system.

### Running as pods

The tests can all be run in pods on an OpenShift kubernetes cluster (this is the recommended method). Sample yaml
files for each test can be found under the sample-yamls directory. Some examples:
* oslat: [pod_oslat.yaml](sample-yamls/pod_oslat.yaml)
* cyclictest: [pod_cyclictest.yaml](sample-yamls/pod_cyclictest.yaml)
* hwlatdetect: [pod_hwlatdetect.yaml](sample-yamls/pod_hwlatdetect.yaml)

By default, these yaml files point to the pre-built stand-alone container images under the [container-perf-tools](https://quay.io/organization/container-perf-tools) organization on quay.io.

When the test is complete, to get the test result, use "oc logs" or "kubectl logs" command to examine the
container log. Currently there is a work in progress to kick off the test and present the test result via
rest API.

### Running from podman

Alternatively, some of the tests can be run from podman directly. Here is an example of running oslat with podman:

```
# podman run -it --rm --privileged -v /dev/cpu_dma_latency:/dev/cpu_dma_latency --cpuset-cpus 4-11 -e PRIO=1 -e RUNTIME_SECONDS=10 quay.io/container-perf-tools/oslat

############# dumping env ###########
HOSTNAME=25d916f6b7ab
container=podman
PWD=/root
HOME=/root
PRIO=1
TERM=xterm
RUNTIME_SECONDS=10
SHLVL=1
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
_=/usr/bin/env
#####################################

########## container info ###########
/proc/cmdline:
BOOT_IMAGE=(hd0,msdos1)/vmlinuz-4.18.0-240.22.1.rt7.77.el8_3.x86_64 root=/dev/mapper/rhel_dhcp16--231--152-root ro crashkernel=auto resume=/dev/mapper/rhel_dhcp16--231--152-swap rd.lvm.lv=rhel_dhcp16-231-152/root rd.lvm.lv=rhel_dhcp16-231-152/swap default_hugepagesz=1G hugepagesz=1G hugepages=16
#####################################
allowed cpu list: 4-11
25d916f6b7ab 4.18.0-240.22.1.rt7.77.el8_3.x86_64
removing cpu44 from the cpu list because it is a sibling of cpu4 which will be the cpu-main-thread
new cpu list: 5,6,7,8,9,10,11
cmd to run: oslat -D 10 --rtprio 1 --cpu-list 5,6,7,8,9,10,11 --cpu-main-thread 4
oslat V 1.10
Total runtime: 		10 seconds
Thread priority: 	SCHED_FIFO:1
CPU list: 		5,6,7,8,9,10,11
CPU for main thread: 	4
Workload: 		no
Workload mem: 		0 (KiB)
Preheat cores: 		7

Pre-heat for 1 seconds...
Test starts...
Test completed.

        Core:	 5 6 7 8 9 10 11
    CPU Freq:	 2493 2493 2493 2493 2493 2493 2493 (Mhz)
    001 (us):	 426829052 426240622 425949824 426254352 424981992 427600232 426964209
    002 (us):	 122 2697 991 2901 983 2551 1051
    003 (us):	 4928 6678 7976 6587 7786 6827 7803
    004 (us):	 4638 482 924 357 1040 499 950
    005 (us):	 221 33 6 28 4 22 9
    006 (us):	 19 28 27 6 13 5 35
    007 (us):	 55 45 45 35 24 34 40
    008 (us):	 14 11 10 30 21 30 8
    009 (us):	 1 0 4 10 23 12 0
    010 (us):	 1 1 0 3 4 3 0
    011 (us):	 0 143 0 143 0 143 0
    012 (us):	 0 0 0 0 1 1 0
    013 (us):	 0 0 0 0 0 0 0
    014 (us):	 1 0 0 0 0 0 0
    015 (us):	 0 0 0 1 0 0 0
    016 (us):	 0 4 0 39 0 0 0
    017 (us):	 0 140 0 105 0 144 0
    018 (us):	 0 0 0 0 0 0 0
    019 (us):	 0 0 0 0 0 0 0
    020 (us):	 0 0 0 0 0 0 0
    021 (us):	 0 0 0 0 0 0 0
    022 (us):	 0 0 0 0 0 0 0
    023 (us):	 0 0 0 0 0 0 0
    024 (us):	 0 0 0 0 0 0 0
    025 (us):	 0 0 0 0 0 0 0
    026 (us):	 0 0 0 0 0 0 0
    027 (us):	 0 0 0 0 0 0 0
    028 (us):	 0 0 0 0 0 0 0
    029 (us):	 0 0 0 0 0 0 0
    030 (us):	 0 0 0 0 0 0 0
    031 (us):	 0 0 0 0 0 0 0
    032 (us):	 0 0 0 0 0 0 0 (including overflows)
     Minimum:	 1 1 1 1 1 1 1 (us)
     Average:	 1.000 1.000 1.000 1.000 1.000 1.000 1.000 (us)
     Maximum:	 14 17 9 17 12 17 8 (us)
     Max-Min:	 13 16 8 16 11 16 7 (us)
    Duration:	 10.003 10.003 10.003 10.003 10.003 10.003 10.003 (sec)

```

## Test Configuration

### oslat test

oslat is a userspace polling mode stress program to detect OS level latency.

oslat supports the following environment variables:
+ RUNTIME_SECONDS: test duration in seconds; default 10
+ PRIO: RT priority used for the test threads; default 1; only valid when USE_DEFAULT_SCHED is not set
+ USE_DEFAULT_SCHED: choice of y/n; if set to y, use the default scheduling class instead of SCHED_FIFO; default n
+ manual: choice of y/n; if enabled, don't kick off oslat, this is for debug purpose
+ delay: specify how many second to delay before test start; default 0
+ TRACE_THRESHOLD: stop the oslat test when threshold triggered (in usec); no default
+ EXTRA_ARGS (default "", will be passed directly to oslat command)

### cyclictest test

cyclictest is used to evaluate the real time kernel scheduler latency.

cyclictest supports the following environment variables:
+ DURATION: how long the cyclictest will be run, default: 24 hours
+ INTERVAL: set cyclictest -i parameter, default 1000
+ stress: choice of false/stress-ng
+ rt_priority: which rt priority is used to run the cyclictest; default 1
+ delay: specify how many seconds to delay before test start; default 0
+ TRACE_THRESHOLD: stop the cyclictest when threshold triggered (in usec); no default
+ EXTRA_ARGS (default "", will be passed directly to cyclictest command)

### stress-ng test

stress-ng is used to load and stress cpus

stress-ng supports the following environment variables:
+ DURATION: how long the stress-ng will be run, default: 24 hours
+ CPU_METHOD: specify a cpu stress method, default: matrixprod
+ CPU_LOAD: load each CPU with P percent loading, default: 100
+ EXTRA_ARGS (default "", will be passed directly to stress-ng command)
+ CMDLINE (default "", the full set of options passed to stress-ng command, overrides all other options)


### testpmd test

testpmd is used to evaluate the system networking performance. The container expects two data ports (other than
the default interface) and wires the two ports together via dpdk handling. For higher performance, the testpmd
runs in io mode and it doesn't examine the packets and simply forwards packets from one port to another port,
in each direction. In general, testpmd forwarding is assumed not to be a bottleneck for the end to end
throughput test.

testpmd supports the following environment variables:
+ ring_size: ring buffer size, default 2048
+ manual: choice of y/n; if enabled, don't kick off testpmd, this is for debug purpose

For more information, refer to the [standalone-testpmd directory](https://github.com/redhat-nfvpe/container-perf-tools/tree/master/standalone-testpmd)

### trafficgen test

trafficgen is used to perform a binary search and find the maximum sustainable throughput. This tool expects
two data ports (other than the default interface) and sends the traffic out of one port and expects the traffic
received on the other port and vice versa. It begins at line rate and automatically adjust the traffic rate
for next iteration based on the packet loss ratio at last iteration until it finds a traffic rate this has
packet loss ratio meets the expectation.

This tool supports the following environment variables:
+ pci_list: A comma-separated data port pci address list, for example 0000:03:00.0,0000:03:00.1
+ validation_seconds: The final validation test duration, default 30 seconds
+ search_seconds: The test duration for each search iteration, default 10 seconds
+ sniff_seconds: The initial test duration before binary search begins, default 10 seconds
+ loss_ratio: Expected packet loss ratio percentile, default 0.002
+ flows: Number of flows, default 1
+ frame_size: The packet frame size (layer 2 frame), default 64 bytes

Prerequisites:
+ 2MB or 1GB huge pages
+ Isolated CPU for better performance
+ Example kargs: `default_hugepagesz=1G hugepagesz=1G hugepages=8 intel_iommu=on iommu=pt isolcpus=4-11`

For more information, refer to the [standalone-trafficgen directory](https://github.com/redhat-nfvpe/container-perf-tools/tree/master/standalone-trafficgen)

### hwlatdetect test

hwlatdetect is used to detect large system latencies induced by the hardware or firmware.

hwlatdetect supports the following environment variables:
+ RUNTIME_SECONDS: how long the test will be run, default: 10 seconds
+ delay: specify how many seconds to delay before test start; default 0
+ THRESHOLD: only record hardware latencies above THRESHOLD (in usec); no default
+ EXTRA_ARGS (default "", will be passed directly to hwlatdetect command)

### timerlat test

timerlat is used to find sources of wakeup latencies of real-time threads. It is run with the rtla tool that analyzes the
cause of any unexpected latencies.

timerlat supports the following environment variables:
+ COMMAND: timerlat
+ DURATION: how long the test will be run, default: 24 hours
+ DELAY: specify how many seconds to delay before test start; default 0
+ MAX_LATENCY: stop detection if the thread latency is higher than MAX_LATENCY (in usec); default 0
+ AA_THRESHOLD: sets automatic trace mode stopping the session if latency in us is hit and generates a trace. A value of 0 disables this feature; default 20
+ EVENTS: Allows specifying multiple trace events. Default is blank. This should be provided as a comma separated list.
+ EVENTS_TRIGGER: Optional. Specifies the condition for the event trigger. Note: Currently only works on the last event in the list
+ CHECK_US: Allows RTLA to also check for userspace induced latency. Options are 'y' or 'n'. Default is 'n'. Note: Host kernel must support this.
+ CGROUPS: If set to 'y', it places the rtla kthreads in the same cgroup as the userspace threads. Default is 'n'. Choices are 'y' or 'n'. Note: Host kernel must support this.
+ PAUSE: pauses after run. choices y/n; default: y. With PAUSE=n, the pod exits with the tool's return code
+ EXTRA_ARGS (default "", will be passed directly to timerlat command)

### osnoise test

osnoise is used to find sources of operating system noise. It is run with the rtla tool that analyzes the
cause of any unexpected latencies.

osnoise supports the following environment variables:
+ COMMAND: osnoise
+ DURATION: how long the test will be run, default: 24 hours
+ DELAY: specify how many seconds to delay before test start; default 0
+ MAX_LATENCY: stop detection if the thread latency is higher than MAX_LATENCY (in usec); default 0
+ AA_THRESHOLD: sets automatic trace mode stopping the session if latency in us is hit and generates a trace. A value of 0 disables this feature; default 20
+ EVENTS: Allows specifying multiple trace events. Default is blank. This should be provided as a comma separated list.
+ EVENTS_TRIGGER: Optional. Specifies the condition for the event trigger. Note: Currently only works on the last event in the list
+ CHECK_US: Allows RTLA to also check for userspace induced latency. Options are 'y' or 'n'. Default is 'n'. Note: Host kernel must support this.
+ CGROUPS: If set to 'y', it places the rtla kthreads in the same cgroup as the userspace threads. Default is 'n'. Choices are 'y' or 'n'. Note: Host kernel must support this.
+ PAUSE: pauses after run. choices y/n; default: y. With PAUSE=n, the pod exits with the tool's return code
+ EXTRA_ARGS (default "", will be passed directly to osnoise command)

### hwnoise test

hwnoise is used to find sources of operating system noise with interrupts disabled. It is run with the rtla
tool that analyzes the cause of any unexpected latencies.

hwnoise supports the following environment variables:
+ COMMAND: hwnoise
+ DURATION: how long the test will be run, default: 24 hours
+ DELAY: specify how many seconds to delay before test start; default 0
+ MAX_LATENCY: stop detection if the thread latency is higher than MAX_LATENCY (in usec); default 0
+ AA_THRESHOLD: sets automatic trace mode stopping the session if latency in us is hit and generates a trace. A value of 0 disables this feature; default 20
+ EVENTS: Allows specifying multiple trace events. Default is blank. This should be provided as a comma separated list.
+ EVENTS_TRIGGER: Optional. Specifies the condition for the event trigger. Note: Currently only works on the last event in the list
+ CHECK_US: Allows RTLA to also check for userspace induced latency. Options are 'y' or 'n'. Default is 'n'. Note: Host kernel must support this.
+ CGROUPS: If set to 'y', it places the rtla kthreads in the same cgroup as the userspace threads. Default is 'n'. Choices are 'y' or 'n'. Note: Host kernel must support this.
+ PAUSE: pauses after run. choices y/n; default: y. With PAUSE=n, the pod exits with the tool's return code
+ EXTRA_ARGS (default "", will be passed directly to hwnoise command)
