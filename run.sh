#!/bin/bash

# env vars: GIT_URL (default https://github.com/jianzzha/container-tools.git)
#           tool (choices: sysjitter/testpmd/cyclictest)

function sigfunc() {
	exit 0
}
trap sigfunc TERM INT SIGUSR1

echo "######################################"
env
echo "######################################"

[ -n "${GIT_URL}" ] || GIT_URL="https://github.com/redhat-nfvpe/container-perf-tools.git"

# Support for air-gapped use with built-in container-tools
if [[ ! "${GIT_URL}" == "false" ]]; then
        echo "git clone ${GIT_URL}"
        git clone ${GIT_URL} /root/container-tools
fi

cd /root/container-tools

if [ -d /root/container-tools/$tool ]; then
    echo "found tool directory $tool"
else
    echo "env 'tool' not specified or tool directory $tool not exists!"
    echo "availble tool directory:"
    echo "$(ls /root/container-tools)"
    sleep infinity 
fi

if [ -f /root/container-tools/$tool/cmd.sh ]; then
    echo "found $tool/cmd.sh, executing"
else
    echo "tool/cmd.sh not exists, can't continue"
    sleep infinity
fi

# https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/#configuration
# The CPU manager periodically writes resource updates through the CRI in order to 
# reconcile in-memory CPU assignments with cgroupfs. The reconcile frequency is set 
# through a new Kubelet configuration value --cpu-manager-reconcile-period.
# If not specified, it defaults to the same duration as --node-status-update-frequency. (10s)
echo "Pausing for 10s before executing $tool to allow CPU Manager to reconcile cgroups"
sleep 10

exec /root/dumb-init -- /root/container-tools/$tool/cmd.sh
