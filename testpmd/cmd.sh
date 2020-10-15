#!/bin/bash

# env vars:
#	ring_size (default 2048)
#	manual    (default n, choices y/n)

source common-libs/functions.sh

function sigfunc() {
	tmux kill-session -t testpmd
	sleep 1
	bind_driver ${vf_driver}
        if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
                enable_balance
        fi
	exit 0
}

echo "############# dumping env ###########"
env
echo "#####################################"

function bind_driver() {
	local driver=$1
        # for mlnx card, don't do anything
        if [ "${driver}" == "mlx5_core" ]; then
            return 0
        fi
	dpdk-devbind -u ${pci_west} ${pci_east}
	dpdk-devbind -b ${driver} ${pci_west} ${pci_east}
}

# check env variables
pci_list=$(env | sed -n -r -e 's/PCIDEVICE.*=(.*)/\1/p' | tr ',\n' ' ')
if [ -n "${pci_list}" ]; then
    pci_count=$(echo "${pci_list}" | wc -w )
    if (( ${pci_count} != 2 )); then
        echo "this container only support two pci network devices!"
        exit 1
    else
        pci_west=$(echo "${pci_list}" | cut -f1 -d ' ')
        pci_east=$(echo "${pci_list}" | cut -f2 -d ' ')
    fi
fi
    
if [[ -z "${pci_west}" || -z "${pci_east}" ]]; then
	echo "Coudln't get assigned pci slot info from enviroment vars starting with PCIDEVICE"
        exit 1
fi

# make sure pci address starts with 0000:
prefix=$(echo $pci_west | cut -f 1 -d:)
if [[ "${prefix}" != "0000" ]]; then
	pci_west=0000:${pci_west}
fi
prefix=$(echo $pci_east | cut -f 1 -d:)
if [[ "${prefix}" != "0000" ]]; then
        pci_east=0000:${pci_east}
fi

vf_driver=$(ls /sys/bus/pci/devices/${pci_west}/driver/module/drivers/| sed -n -r 's/.*:(.+)/\1/p' | head -1)
if [[ -z "${vf_driver}" ]]; then
	echo "couldn't get driver info from /sys/bus/pci/devices/${pci_west}/driver/module/drivers/"
	echo "${pci_west} need to bind to kernel driver before running this app"
	exit 1
fi

# get pci slot mac address; these mac address can be used by trafficgen when used in l3 mode
mac_pci_west=$(cat /sys/bus/pci/devices/${pci_west}/net/*/address | head -1)
mac_pci_east=$(cat /sys/bus/pci/devices/${pci_east}/net/*/address | head -1)

if [[ -z "${ring_size}" ]]; then
        ring_size=2048
fi

if [[ -z "${peer_mac_west}" || -z "${peer_mac_east}" ]]; then
	l3=0
else
	l3=1
fi

echo "pci_west ${pci_west} pci_east ${pci_east} vf_driver ${vf_driver} ring_size ${ring_size} l3 ${l3}"

# if python not exist, try link it to python3
if ! command -v python >/dev/null 2>&1; then
	if command -v python3 >/dev/null 2>&1; then
		mkdir -p /usr/local/bin
		ln -s `which python3` /usr/local/bin/python
	elif command -v python2.7 >/dev/null 2>&1; then
                mkdir -p /usr/local/bin
		ln -s `which python2.7` /usr/local/bin/python
        else
		echo "failed to find python3 or python2.7"
		exit 1
	fi
fi

for cmd in testpmd dpdk-devbind; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed.  Aborting"; exit 1; }
done

# first parse the cpu list that can be used for testpmd
cpulist=`get_allowed_cpuset`
echo "allowed cpu list: ${cpulist}"

cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort -n | uniq`

declare -a cpus
cpus=(${cpulist})

if (( ${#cpus[@]} < 3 )); then
	echo "need at least 3 cpu to run this test!"
	exit 1
fi

mem="1024,1024"

# bind driver to vfio-pci unless it is mlnx nic
if [ "${vf_driver}" != "mlx5_core" ]; then
    bind_driver "vfio-pci"
    sleep 1
fi

if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
        disable_balance
fi

trap sigfunc TERM INT SIGUSR1

if ((l3 == 0)); then
	testpmd_cmd="testpmd -l ${cpus[0]},${cpus[1]},${cpus[2]} --socket-mem ${mem} -n 4 --proc-type auto \
                 --file-prefix pg -w ${pci_west} -w ${pci_east} \
                 -- --nb-cores=2 --nb-ports=2 --portmask=3  --auto-start \
                    --rxq=1 --txq=1 --rxd=${ring_size} --txd=${ring_size}"
else
	testpmd_cmd="testpmd -l ${cpus[0]},${cpus[1]},${cpus[2]} --socket-mem ${mem} -n 4 --proc-type auto \
		--file-prefix pg -w ${pci_west} -w ${pci_east} \
		-- --nb-cores=2 --nb-ports=2 --portmask=3  --auto-start --forward-mode=mac --eth-peer=0,${peer_mac_west} --eth-peer=1,${peer_mac_east} \
		--rxq=1 --txq=1 --rxd=${ring_size} --txd=${ring_size}"
	# print out pci_west and pci_east mac address
	echo "mac_pci_west=${mac_pci_west}, mac_pci_east=${mac_pci_east}"
fi

if [[ "${manual:-n}" == "y" ]]; then
	echo "${testpmd_cmd}"
else
	tmux new-session -s testpmd -d "${testpmd_cmd}"
fi

sleep infinity
tmux kill-session -t testpmd
sleep 1
bind_driver ${vf_driver}

if [ "${DISABLE_CPU_BALANCE:-n}" == "y" ]; then
        enable_balance
fi

