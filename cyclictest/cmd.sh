#!/bin/bash

# env vars:
#   DURATION (default "24h")
#   INTERVAL (default "1000")
#   stress (default "false", choices false/true)
#   rt_priority (default "1")
#   delay (default 0, specify how many seconds to delay before test start)
#   TRACE_THRESHOLD: stop cyclictest when threshold triggered (in usec); no default
#   EXTRA_ARGS (default "", will be passed directly to cyclictest command)
#   manual (default 'n', choice y/n, don't run test - for debug purposes)

source common-libs/functions.sh

function sigfunc() {
    tmux kill-session -t stress 2>/dev/null
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

if [[ -z "${INTERVAL}" ]]; then
    INTERVAL="1000"
fi

if [[ -z "${stress}" ]]; then
    stress="false"
elif [[ "${stress}" != "stress-ng" && "${stress}" != "true" ]]; then
    stress="false"
else
    stress="true"
fi

if [[ -z "${rt_priority}" ]]; then
        rt_priority=1
elif [[ "${rt_priority}" =~ ^[0-9]+$ ]]; then
    if (( rt_priority > 99 )); then
        rt_priority=99
    fi
else
    rt_priority=1
fi

for cmd in tmux cyclictest stress-ng; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed. Aborting"; exit 1; }
done

uname=`uname -nr`
echo "$uname"
rpm -q realtime-tests

cpulist=`get_allowed_cpuset`
echo "allowed cpu list: ${cpulist}"

cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort -n | uniq`

declare -a cpus
cpus=(${cpulist})

trap sigfunc TERM INT SIGUSR1

# stress run in each tmux window per cpu
if [[ "$stress" == "true" ]]; then
    tmux new-session -s stress -d
    for w in $(seq 1 ${#cpus[@]}); do
        tmux new-window -t stress -n $w "taskset -c ${cpus[$(($w-1))]} stress-ng --cpu 1 --cpu-load 100 --cpu-method loop"
    done
fi

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
    echo "removing cpu${sibling} from the cpu list because it is a sibling of cpu${cpus[0]} which will be the mainaffinity"
    cyccore=${cyccore//,$sibling/}
    ccount=$(($ccount - 1))
fi
echo "new cpu list: ${cyccore}"

if [[ -n "${TRACE_THRESHOLD}" ]]; then
    extra_opt="${extra_opt} -b ${TRACE_THRESHOLD} --tracemark"
fi

command="cyclictest -q -D ${DURATION} -p ${rt_priority} -t ${ccount} -a ${cyccore} -h 30 -i ${INTERVAL} --mainaffinity ${cpus[0]} -m ${extra_opt} ${EXTRA_ARGS}"

echo "running cmd: ${command}"
if [ "${manual:-n}" == "n" ]; then
    if [ "${delay:-0}" != "0" ]; then
        echo "sleep ${delay} before test"
        sleep ${delay}
    fi
    $command
else
    sleep infinity
fi

# kill stress before exit 
tmux kill-session -t stress 2>/dev/null

sleep infinity
