#!/bin/bash

# env vars:
#	RUNTIME_SECONDS (default 10)
#	THRESHOLD_NS    (default 200)
#	DISABLE_CPU_BALANCE (default "n", choices y/n)
#	USE_TASKSET     (default "n", choice y/n)	
#       manual  (default 'n', choice yn)

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

echo "**** uid: $UID ****"
RUNTIME_SECONDS=${RUNTIME_SECONDS:-10}
THRESHOLD_NS=${THRESHOLD_NS:-200}

cpulist=`get_allowed_cpuset`
echo "allowed cpu list: ${cpulist}"

# change list seperators from comma to new line and sort it 
cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort -n | uniq`

declare -a cpus
cpus=(${cpulist})

if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
	disable_balance
fi

trap sigfunc TERM INT SIGUSR1
if ! command -v sysjitter >/dev/null 2>&1; then
	cd sysjitter
	git clone https://github.com/k-rister/sysjitter.git
	cd sysjitter
	git checkout luiz
	make 
	install -t /bin/ sysjitter
fi

for cmd in sysjitter; do
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

prefix_cmd=""
if [ "${USE_TASKSET:-n}" == "y" ]; then
	prefix_cmd="taskset --cpu-list ${cyccore}"
fi
 
echo "cmd to run: sysjitter --runtime ${RUNTIME_SECONDS} --rtprio 95 --accept-cpuset --cores ${cyccore} --master-core ${cpus[0]} ${THRESHOLD_NS}"

if [ "${manual:-n}" == "y" ]; then
sleep infinity
fi

# TODO: taskset -c ${cpus[0]} -p $$

# old way without Karl's patch: ${prefix_cmd} sysjitter --cores ${cyccore} --runtime ${RUNTIME_SECONDS} ${THRESHOLD_NS}

# TODO: lauch collection tool in background first

if [ -z "${ssh_address}" ]; then
	sysjitter --runtime ${RUNTIME_SECONDS} --rtprio 95 --accept-cpuset --cores ${cyccore} --master-core ${cpus[0]} ${THRESHOLD_NS}
else
	output_name="result-`date +%Y%m%dT%H%M%S`"
	sysjitter --runtime ${RUNTIME_SECONDS} --rtprio 95 --accept-cpuset --cores ${cyccore} --master-core ${cpus[0]} ${THRESHOLD_NS} | tee ${output_name}
	command -v sshpass >/dev/null 2>&1 || yum install -y sshpass
	ssh_option="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
	echo sshpass -p "${ssh_password}" ssh ${ssh_option} ${ssh_user:-root}@${ssh_address} 'mkdir -p sysjitter-results' 
	sshpass -p "${ssh_password}" ssh ${ssh_option} ${ssh_user:-root}@${ssh_address} 'mkdir -p sysjitter-results'
	echo sshpass -p "${ssh_password}" scp ${ssh_option} ${output_name} ${ssh_user:-root}@${ssh_address}:sysjitter-results/
	sshpass -p "${ssh_password}" scp ${ssh_option} ${output_name} ${ssh_user:-root}@${ssh_address}:sysjitter-results/ || sleep infinity
fi

# TODO: kill the collection tool before exit

if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
	enable_balance
fi
