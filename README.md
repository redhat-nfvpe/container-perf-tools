
# container-perf-tools

This project contains a set of containerized performance test tool that can be used in Kubernetes enviroment to 
evaluate performance related to data plane, such as dpdk enabled network throughput, real time kernel latency, 
etc.

## Directory layout

The tool set is constructed in such a way that the tester has the flexiblity to customize a tool execution without rebuilding the container image. 

It's expectd each tool will be located in its own directory with name cmd.sh. For example under directory cyclictest, the cmd.sh is the entrance for cyclictest. For testpmd there will be a directory testpmd with cmd.sh under that directory. The tool script should expect its arguments/options via enviroment variables.

The run.sh under the repo root diretory is the entrance for the container image. Once it is started, it will git pull this repo to get the latest tools. It then executes the specified tool based on the yaml specification, with the enviroment variables in the yaml file. The yaml examples for k8s can be found under the sample-yamls/ directory


## Getting Started

There are two types of container tool use cases. The first type is to run the performance tool as container 
image in a Kubernetes cluster and the performance tool will collect and report performance metics of the 
underlying system; this type includes sysjitter, cyclictest, and uperf. The second type lives outside Kubernetes 
cluster and is used externally to evaluate the Kubernetest cluster; this type includes trex trafficgen. Sometimes 
we need to use this two types together to evaluate the system; for example, to evaluate the SRIOV throughput, we 
can run a DPDK testpmd container inside Kubernetes cluster, and outside the cluster use trex trafficgen
container to do binary search in order to evaluate the highest throughput supported by the SRIOV ports.

### common yaml variables

All the test scripts use enviroment varibles as input. There are two types of variables, the first type is common 
to all tools. The second type is tool specific. Both are defined as name/value pair under the container env spec.

The common env variables include:
GIT_URL: this points to your github fork of this repository, or this respository if no fork
tool: which performance test to run, essentially it is one of the tool directory name

The tool specific variables will be mentioned under each tool sector.

### uperf 

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




