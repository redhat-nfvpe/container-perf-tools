#!/bin/bash

# env vars:
#	RUNTIME_SECONDS (default 10)
#	DISABLE_CPU_BALANCE (default "n", choices y/n)
#	PRIO (RT priority, default 1)
#       manual (default 'n', choice y/n)
#       delay   (default 0, specify how many second to delay before test start)

source common-libs/functions.sh

function sigfunc() {
	if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
		enable_balance
	fi
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

RUNTIME_SECONDS=${RUNTIME_SECONDS:-10}
PRIO=${PRIO:-1}

cpulist=`get_allowed_cpuset`
echo "allowed cpu list: ${cpulist}"

uname=`uname -nr`
echo "$uname"

# change list seperators from comma to new line and sort it 
cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort -n | uniq`

declare -a cpus
cpus=(${cpulist})

if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
	disable_balance
fi

trap sigfunc TERM INT SIGUSR1

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

 
echo "cmd to run: oslat -D ${RUNTIME_SECONDS} --rtprio ${PRIO} --cpu-list ${cyccore} --cpu-main-thread ${cpus[0]}"

if [ "${manual:-n}" == "y" ]; then
	sleep infinity
fi

if [ "${delay:-0}" != "0" ]; then
	echo "sleep ${delay} before test"
	sleep ${delay}
fi

oslat -D ${RUNTIME_SECONDS} --rtprio ${PRIO} --cpu-list ${cyccore} --cpu-main-thread ${cpus[0]}

sleep infinity

if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
	enable_balance
fi
