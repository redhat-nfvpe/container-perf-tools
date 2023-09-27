#!/bin/bash

# env vars:
#   COMMAND (specify test to run: timerlat, osnoise, hwnoise)
#   DURATION (default "24h")
#   MAX_LATENCY (default 20 (us))
#   DELAY (default 0, specify how many seconds to delay before test start)
#   EXTRA_ARGS (default "", will be passed directly to "rtla timerlat" command)
#   MANUAL (default 'n', choice y/n, halts before running test)

source common-libs/functions.sh

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

if [[ -z "${MAX_LATENCY}" ]]; then
    MAX_LATENCY="20"
fi

for cmd in rtla; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed. Aborting"; exit 1; }
done

uname=`uname -nr`
echo "$uname"
rpm -q rtla

cpulist=`get_allowed_cpuset`
echo "allowed cpu list: ${cpulist}"

# change list seperators from comma to new line and sort it
cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort -n | uniq`

declare -a cpus
cpus=(${cpulist})

for cmd in rtla; do
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

if [ ${COMMAND} == "timerlat" ] || [ ${COMMAND} == "osnoise" ]; then
    hist="hist"
fi

command="rtla ${COMMAND} ${hist} --auto ${MAX_LATENCY} --duration ${DURATION} --cpus ${cyccore} -H ${cpus[0]} ${EXTRA_ARGS}"

echo "running cmd: ${command}"
if [ "${MANUAL:-n}" == "n" ]; then
    if [ "${DELAY:-0}" != "0" ]; then
        echo "sleep ${DELAY} before test"
        sleep ${DELAY}
    fi
    $command

    echo "DONE: If a trace was collected you can retrieve it with:"
    echo "oc cp ${COMMAND}:/root/${COMMAND}_trace.txt ${COMMAND}_trace.txt"
else
    sleep infinity
fi

sleep infinity
