#!/bin/bash

# env vars:
#   DURATION (default "24h")
#   CPU_METHOD (default "matrixprod")
#   CPU_LOAD (default "100")
#   EXTRA_ARGS (will be passed directly to stress-ng command)

source common-libs/functions.sh

function sigfunc() {
    exit 0
}

echo "############# dumping env ###########"
env
echo "#####################################"

echo " "
echo "########## container info ###########"
echo "/proc/cmdline:"
cat /proc/cmdline
echo "#####################################"

echo "**** uid: $UID ****"
if [[ -z "${DURATION}" ]]; then
    DURATION="24h"
fi

if [[ -z "${CPU_METHOD}" ]]; then
    CPU_METHOD="matrixprod"
fi

if [[ -z "${CPU_LOAD}" ]]; then
    CPU_LOAD="100"
fi

for cmd in stress-ng; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed. Aborting"; exit 1; }
done

cpulist=`get_allowed_cpuset`
echo "allowed cpu list: ${cpulist}"

uname=`uname -nr`
echo "$uname"

cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort -n | uniq`

declare -a cpus
cpus=(${cpulist})

trap sigfunc TERM INT SIGUSR1

newcpulist=${cpus[0]}
cindex=1
ccount=1
while (( $cindex < ${#cpus[@]} )); do
    newcpulist="${newcpulist},${cpus[$cindex]}"
    cindex=$(($cindex + 1))
    ccount=$(($ccount + 1))
done

echo "cpu list: ${newcpulist}"

command="stress-ng -t ${DURATION} --cpu ${ccount} --taskset ${newcpulist} --cpu-method ${CPU_METHOD} --cpu-load ${CPU_LOAD} --metrics-brief ${EXTRA_ARGS}"

echo "running cmd: ${command}"
if [ "${manual:-n}" == "n" ]; then
    $command
else
    sleep infinity
fi

sleep infinity
