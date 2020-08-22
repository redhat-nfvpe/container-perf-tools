#!/bin/bash

# env vars:
#	RUNTIME_SECONDS (default 10)
#	DISABLE_CPU_BALANCE (default "n", choices y/n)
#	USE_TASKSET     (default "n", choice y/n)	
#       manual (default 'n', choice yn)
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

echo "**** uid: $UID ****"
RUNTIME_SECONDS=${RUNTIME_SECONDS:-10}

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
if ! command -v oslat >/dev/null 2>&1; then
	cd oslat
	git clone https://github.com/xzpeter/oslat.git
	cd oslat
	make 
	install -t /bin/ oslat
fi

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

prefix_cmd=""
if [ "${USE_TASKSET:-n}" == "y" ]; then
	prefix_cmd="taskset --cpu-list ${cyccore}"
fi
 
echo "cmd to run: oslat --runtime ${RUNTIME_SECONDS} --rtprio ${RTPRIO} --cpu-list ${cyccore} --cpu-main-thread ${cpus[0]}"

if [ "${manual:-n}" == "y" ]; then
sleep infinity
fi

if [ "${delay}:-0}" != "0" ]; then
	echo "sleep ${delay} before test"
	sleep ${delay}
fi

oslat --runtime ${RUNTIME_SECONDS} --rtprio ${RTPRIO} --cpu-list ${cyccore} --cpu-main-thread ${cpus[0]}

if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
	enable_balance
fi
