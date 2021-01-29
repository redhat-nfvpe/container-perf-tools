# How to run trafficgen and testpmd in OCP enviroment

This folder contains instructions and examples on how to run the trafficgen and testpmd in the
OCP enviroment

## Setup performance and SRIOV setting via operators

The performance addon operator can provision the OCP cluster for performance tuning. The 
SRIOV operator will setup the virtual functrions on the worker nodes. The steps to 
run these operators are described in the setup.sh file in this folder. The required 
yaml files are in this folder as well, one can simply run,
```
./setup.sh
```

This will run the performance operator and SRIOV operator.

It will take a while for this script to complete.

## Start testpmd pod

```
oc create -f pod-testpmd.yaml
```

Once the pod is running, to watch the testpmd log,
```
oc logs testpmd
```

The testpmd-client can be used to control the testpmd,
```
cd ../standalone-testpmd/cmd/testpmd-wrapper
go build
# use -server to sepcify the worker node where the testpmd pod is running on
# the -grpc-port should be specified as in the service-testpmd.yaml
./client-example -server worker1 -grpc-port 32360 ports
```

This should return the mac address used by the testpmd.

## Start the trafficgen pod

```
oc create -f pod-trafficgen.yaml
``` 

Once the pod is running, to watch the trafficgen log,
```
oc logs trafficgen
```

To get the mac address used by the trafficgen,
```
python standalone-trafficgen/client.py --server-addr worker2 --server-port 32361 get-mac
```

## Run test

```
# trafficgen-mac1 and trafficgen-mac2 are acquired first before running this step
./client-example -server worker1 -grpc-port 32360 -peer-mac 0,<trafficgen-mac1> -peer-mac 1,<trafficgen-mac2> mac
# testpmd-mac1 and testpmd-mac2 are aquired before running this step
python standalone-trafficgen/client.py --server-addr worker2 --server-port 32361 --dst-macs <testpmd_mac1,testpmd_mac2> start
```

To check the trafficgen running status,
```
python standalone-trafficgen/client.py --server-addr worker2 --server-port 32361 status
```

Once the trafficgen has completed, to get the test result,
```
python standalone-trafficgen/client.py --server-addr worker2 --server-port 32361 get-result
```
