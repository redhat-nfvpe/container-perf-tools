#!/usr/bin/bash

oc label --overwrite node worker1 node-role.kubernetes.io/worker-cnf=""
oc label --overwrite node worker1 feature.node.kubernetes.io/network-sriov.capable=true
oc label --overwrite node worker2 node-role.kubernetes.io/worker-cnf=""
oc label --overwrite node worker2 feature.node.kubernetes.io/network-sriov.capable=true

oc create -f perf-sub.yaml

while ! oc get pods -n openshift-performance-addon | grep Running; do
    sleep 5
done

oc create -f machine_config_pool.yaml
oc create -f performance_profile.yaml

sleep 10
status=$(oc get mcp -o json | jq -r '.items[] | select(.metadata.name == "worker-cnf") | .status.conditions[] | select(.type == "Updating") | .status')
while [[ "$status" != "False" ]]; do 
    sleep 5
    status=$(oc get mcp -o json | jq -r '.items[] | select(.metadata.name == "worker-cnf") | .status.conditions[] | select(.type == "Updating") | .status')
done

oc create -f sriov-sub.yaml

while ! oc get pods -n openshift-sriov-network-operator | grep Running; do
    sleep 5
done

oc create -f sriov-nic-policy.yaml

sleep 10
status=$(oc get mcp -o json | jq -r '.items[] | select(.metadata.name == "worker-cnf") | .status.conditions[] | select(.type == "Updating") | .status')
while [[ "$status" != "False" ]]; do
    sleep 5
    status=$(oc get mcp -o json | jq -r '.items[] | select(.metadata.name == "worker-cnf") | .status.conditions[] | select(.type == "Updating") | .status')
done

oc create -f sriov-network.yaml

oc create -f service-testpmd.yaml
oc create -f service-trafficgen.yaml
