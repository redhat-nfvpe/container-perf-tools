#!/bin/bash

# env vars:
#	DURATION (default "24h")
#	DISABLE_CPU_BALANCE (default "n", choice y/n)
#	INTERVAL (default "1000")
#	stress (default "false", choices false/true)
#	rt_priority (default "1")

source common-libs/functions.sh

function sigfunc() {
        tmux kill-session -t stress 2>/dev/null
	if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
		enable_balance
	fi
	exit 0
}

echo "############# dumping env ###########"
env
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

release=$(cat /etc/os-release | sed -n -r 's/VERSION_ID="(.).*/\1/p')

for cmd in tmux cyclictest; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed. Aborting"; exit 1; }
done

cpulist=`get_allowed_cpuset`
echo "allowed cpu list: ${cpulist}"

cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort -n | uniq`

declare -a cpus
cpus=(${cpulist})

if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
	disable_balance
fi

trap sigfunc TERM INT SIGUSR1

# stress run in each tmux window per cpu
if [[ "$stress" == "true" ]]; then
    yum install -y stress-ng 2>&1 || { echo >&2 "stress-ng required but install failed. Aborting"; sleep infinity; }
    tmux new-session -s stress -d
    for w in $(seq 1 ${#cpus[@]}); do
        tmux new-window -t stress -n $w "taskset -c ${cpus[$(($w-1))]} stress-ng --cpu 1 --cpu-load 100 --cpu-method loop"
    done
fi

cyccore=${cpus[0]}
cindex=1
ccount=1
while (( $cindex < ${#cpus[@]} )); do
	cyccore="${cyccore},${cpus[$cindex]}"
	cindex=$(($cindex + 1))
        ccount=$(($ccount + 1))
done

extra_opt=""
if [[ "$release" = "7" ]]; then
    extra_opt="${extra_opt} -n"
fi

echo "running cmd: cyclictest -q -D ${DURATION} -p ${rt_priority} -t ${ccount} -a ${cyccore} -h 30 -i ${INTERVAL} -m ${extra_opt}"
if [ "${manual:-n}" == "n" ]; then
    cyclictest -q -D ${DURATION} -p ${rt_priority} -t ${ccount} -a ${cyccore} -h 30 -i ${INTERVAL} -m ${extra_opt}
else
    sleep infinity
fi

sleep infinity

# kill stress before exit 
tmux kill-session -t stress 2>/dev/null

if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
	enable_balance
fi

