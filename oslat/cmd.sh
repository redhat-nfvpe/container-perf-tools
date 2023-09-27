#!/bin/bash

# env vars:
#   RUNTIME_SECONDS (default 10)
#   PRIO (RT priority, default 1)
#   manual (default 'n', choice y/n, don't run test - for debug purposes)
#   delay   (default 0, specify how many second to delay before test start)
#   TRACE_THRESHOLD (no default, stop the oslat test when threshold triggered (in usec))
#   EXTRA_ARGS (default "", will be passed directly to oslat command)

source common-libs/functions.sh

RUNTIME_SECONDS=${RUNTIME_SECONDS:-10}

echo "############# dumping env ###########"
env
echo "#####################################"

echo " "
echo "########## container info ###########"
echo "/proc/cmdline:"
cat /proc/cmdline
echo "#####################################"


PRIO=${PRIO:-1}

uname=`uname -nr`
echo "$uname"
rpm -q rt-tests

cpulist=`get_allowed_cpuset`
echo "allowed cpu list: ${cpulist}"

# change list seperators from comma to new line and sort it 
cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort -n | uniq`

declare -a cpus
cpus=(${cpulist})

for cmd in oslat; do
     command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed.  Aborting"; exit 1; }
done

cyccore=${cpus[1]}
cindex=2
ccount=1
while (( $cindex < ${#cpus[@]} )); do
	cyccore="${cyccore},${cpus[$cindex]}"
	cindex=$(($cindex + 1))
        ccount=$(($ccount + 1))
done

sibling=`cat /sys/devices/system/cpu/cpu${cpus[0]}/topology/thread_siblings_list | awk -F '[-,]' '{print $2}'`
if [[ "${sibling}" =~ ^[0-9]+$ ]]; then
        echo "removing cpu${sibling} from the cpu list because it is a sibling of cpu${cpus[0]} which will be the cpu-main-thread"
        cyccore=${cyccore//,$sibling/}
fi
echo "new cpu list: ${cyccore}"

extra_args=""
if [ -n "$TRACE_THRESHOLD" ]; then
        extra_args="--trace-threshold=$TRACE_THRESHOLD"
fi

command="oslat -D ${RUNTIME_SECONDS} --rtprio ${PRIO} --cpu-list ${cyccore} --cpu-main-thread ${cpus[0]} ${extra_args} ${EXTRA_ARGS}"

echo "cmd to run: ${command}"

if [ "${manual:-n}" == "y" ]; then
	sleep infinity
fi

if [ "${delay:-0}" != "0" ]; then
	echo "sleep ${delay} before test"
	sleep ${delay}
fi

$command

sleep infinity
