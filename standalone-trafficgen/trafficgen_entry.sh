#!/bin/bash
# env: peer_mac_west peer_mac_east validation_seconds search_seconds sniff_seconds loss_ratio flows frame_size

validation_seconds=${validation_seconds:-30}
search_seconds=${search_seconds:-10}
sniff_seconds=${sniff_seconds:-10}
loss_ratio=${loss_ratio:-0.002}
flows=${flows:-1}
frame_size=${frame_size:-64}
page_prefix=trafficgen_trex_
pciDeviceDir="/sys/bus/pci/devices"
pciDriverDir="/sys/bus/pci/drivers"

pciArray=()
#track if each pci already bound to dpdk for recover purpose
declare -A dpdkBound
vendor="0x8086"
device=""
kmod="i40e"
vf_extra_opt=""

function convert_number_range() {
    # converts a range of cpus, like "1-3,5" to a list, like "1,2,3,5"
    local cpu_range=$1
    local cpus_list=""
    local cpus=""
    for cpus in `echo "${cpu_range}" | sed -e 's/,/ /g'`; do
        if echo "${cpus}" | grep -q -- "-"; then
            cpus=`echo ${cpus} | sed -e 's/-/ /'`
            cpus=`seq ${cpus} | sed -e 's/ /,/g'`
        fi
        for cpu in ${cpus}; do
            cpus_list="${cpus_list},${cpu}"
        done
    done
    cpus_list=`echo ${cpus_list} | sed -e 's/^,//'`
    echo "${cpus_list}"
}

function bindKmod() {
    local pci=$1
    vendor=$(cat ${pciDeviceDir}/${pci}/vendor)
    device=$(cat ${pciDeviceDir}/${pci}/device)
    if [[ ${vendor} == "0x8086" ]]; then
        kmod="i40e"
	if [[ "${device}" == "0x154c" ]]; then
	    kmod="iavf"
	fi
    else
        echo "no kernel module defined for ${pci}"
        exit 1
    fi
    if [[ ! -d ${pciDeviceDir}/${pci}/net ]]; then
        dpdk-devbind -u ${pci}
        dpdk-devbind -b ${kmod} ${pci}
        echo "${pci} bound to kernel"
    fi
}

function bindDpdk() {
    local pci=$1
    vendor=$(cat ${pciDeviceDir}/${pci}/vendor)
    device=$(cat ${pciDeviceDir}/${pci}/device)
    if [[ -e ${pciDeviceDir}/${pci}/net ]]; then
        if [[ ${vendor} == "0x8086" ]]; then
            kmod="i40e"
	    if [[ "${device}" == "0x154c" ]]; then
                kmod="iavf"
	    fi
	else
            echo "no kernel module defined for ${pci}"
            exit 1
	fi
	echo ${pci} > ${pciDriverDir}/${kmod}/unbind
    fi
    echo "${vendor} ${device}" > ${pciDriverDir}/vfio-pci/new_id
    echo "${vendor} ${device}" > ${pciDriverDir}/vfio-pci/remove_id
}

function sigfunc() {
    pid=`pgrep binary-search`
    [ -z ${pid} ] || kill ${pid}
    tmux kill-session -t trex 2>/dev/null
    for pci in "${pciArray[@]}"; do
        if (( ${dpdkBound[$pci]} == 0 )); then
            bindKmod ${pci}
        fi
    done
    rm -rf /dev/hugepages/${page_prefix}*
    exit 0
}

modprobe vfio-pci

trap sigfunc SIGTERM SIGINT SIGUSR1


if [ -z "$1" ]; then
    # do nothing
    cd /root/tgen
    sleep infinity
else
    if [ "$1" == "server" ] || [ "$1" == "start" ]; then
        if [ -z "${pci_list}" ]; then
        # is this a openshift sriov pod?
            pci_list=$(env | sed -n -r -e 's/PCIDEVICE.*=(.*)/\1/p' | tr '\n' ',')
            if [ -z "${pci_list}" ]; then
                echo "need env var: pci_list"
                exit 1
            fi
        fi

        for pci in $(echo ${pci_list} | sed -e 's/,/ /g'); do
            if [[ ${pci} != 0000:* ]]; then
                pci=0000:${pci}
            fi
            pciArray+=(${pci})
            vendor=$(cat ${pciDeviceDir}/${pci}/vendor)
            device=$(cat ${pciDeviceDir}/${pci}/device)
            if [[ ! -e ${pciDeviceDir}/${pci}/net ]]; then
                dpdkBound["$pci"]=1
            else
                dpdkBound["$pci"]=0
            fi
        done

        # how many devices?
        number_of_devices=$(echo ${pci_list} | sed -e 's/,/ /g' | wc -w)
        if [ ${number_of_devices} -lt 2 ]; then
            echo "need at least 2 pci devices"
            exit 1
        fi
        # device_pairs in form of "0:1,2:3"
        index=0
        while [ ${index} -lt ${number_of_devices} ]; do
            if [ -z ${device_pairs} ]; then
                device_pairs="$((index)):$((index+1))"
            else
                device_pairs="${device_pairs},$((index)):$((index+1))"
            fi
            ((index+=2))
        done
        # only twp peer mac address can be specified as gateway, if >2 pci slot is supplied, then fall back to io mode even and ignore the peer mac address 
        if ((index > 2)); then
            l3=0
        elif [[ -z "${peer_mac_west}" || -z "${peer_mac_east}" ]]; then
            l3=0
        else
            l3=1
        fi
    fi

    cd /root/tgen
    #pciArray is set above, or we can alway use the following line in stead
    #read -a pciArray <<< $(echo ${pci_list} | sed -e 's/,/ /g')
    export NIC1=${pciArray[0]}
    export NIC2=${pciArray[1]}
    isolated_cpus=$(cat /proc/self/status | grep Cpus_allowed_list: | cut -f 2)
    read -a cpuArray <<< $(convert_number_range ${isolated_cpus} | sed -e 's/,/ /g')
    export master_cpu=${cpuArray[0]}
    export latency_cpu=${cpuArray[1]}
    cpuArray=("${cpuArray[@]:2}")
    workerCPUs=${#cpuArray[@]}
    export worker_cpu=$(echo ${cpuArray[@]} | sed -e 's/ /,/g')
    export numa_node=$(cat ${pciDeviceDir}/${NIC1}/numa_node)
   
    yaml_file=/tmp/trex_cfg.yaml
    envsubst < trex_cfg.yaml.tmpl > ${yaml_file}

    pushd /opt/trex/current
    if [[ "${vendor}" == "0x8086" ]]; then
	if [[ "${device}" == "0x154c" ]]; then
	    #vf_extra_opt="--no-promisc --use-device-stats"
	    vf_extra_opt="--no-promisc"
	fi
        trex_extra_opt=""
    elif [[ "${vendor}" == "0x15b3" ]]; then
        if [[ "${device}" == "0x1018" ]]; then
            vf_extra_opt="--no-promisc"
        fi
        trex_extra_opt="--mlx5-so"
    fi

    rm -rf /dev/hugepages/${page_prefix}*
    trex_server_cmd="./t-rex-64 -i -c ${workerCPUs} --checksum-offload --cfg ${yaml_file} --iom 0 -v 4 --prefix ${page_prefix} ${trex_extra_opt}"
    echo "run trex server cmd: ${trex_server_cmd}"
    echo "trex yaml:"
    echo "-------------------------------------------------------------------"
    cat ${yaml_file}
    echo "-------------------------------------------------------------------"
    rm -fv /tmp/trex.server.out
    tmux new-session -d -n server -s trex "bash -c '${trex_server_cmd} | tee /tmp/trex.server.out'"
    popd

    count=60
    num_ports=0
    while [ ${count} -gt 0 -a ${num_ports} -lt 2 ]; do
        sleep 1
        num_ports=`netstat -tln | grep -E :4500\|:4501 | wc -l`
        ((count--))
    done
    if [ ${num_ports} -eq 2 ]; then
        echo "trex-server is ready"
    else
        echo "ERROR: trex-server could not start properly"
        cat /tmp/trex.server.out
        exit 1
    fi

    if [ "$1" == "start" ]; then
        for size in $(echo ${frame_size} | sed -e 's/,/ /g'); do
            if (( l3 == 0)); then
                ./binary-search.py --traffic-generator=trex-txrx --rate-tolerance=50 --use-src-ip-flows=1 --use-dst-ip-flows=1 --use-src-mac-flows=1 --use-dst-mac-flows=1 \
                --use-src-port-flows=0 --use-dst-port-flows=0 --use-encap-src-ip-flows=0 --use-encap-dst-ip-flows=0 --use-encap-src-mac-flows=0 --use-encap-dst-mac-flows=0 \
                --use-protocol-flows=0 --device-pairs=${device_pairs} --active-device-pairs=${device_pairs} --sniff-runtime=${sniff_seconds} \
                --search-runtime=${search_seconds} --validation-runtime=${validation_seconds} --max-loss-pct=${loss_ratio} \
                --traffic-direction=bidirectional --frame-size=${size} --num-flows=${flows} --rate-tolerance-failure=fail \
                --rate-unit=% --rate=100 --search-granularity=5.0 --runtime-tolerance=50 --negative-packet-loss=fail ${vf_extra_opt}
            else
                ./binary-search.py --traffic-generator=trex-txrx --rate-tolerance=50 --use-src-ip-flows=1 --use-dst-ip-flows=1 --use-src-mac-flows=1 --use-dst-mac-flows=1 \
                --use-src-port-flows=0 --use-dst-port-flows=0 --use-encap-src-ip-flows=0 --use-encap-dst-ip-flows=0 --use-encap-src-mac-flows=0 --use-encap-dst-mac-flows=0 \
                --use-protocol-flows=0 --device-pairs=${device_pairs} --active-device-pairs=${device_pairs} --sniff-runtime=${sniff_seconds} \
                --search-runtime=${search_seconds} --validation-runtime=${validation_seconds} --max-loss-pct=${loss_ratio} \
                --traffic-direction=bidirectional --frame-size=${size} --num-flows=${flows} --dst-macs=${peer_mac_west},${peer_mac_east} --rate-tolerance-failure=fail \
                --rate-unit=% --rate=100 --search-granularity=5.0 --runtime-tolerance=50 --negative-packet-loss=fail ${vf_extra_opt}
            fi
        done
    elif [ "$1" == "server" ]; then
        python server.py --extra-opts \"${vf_extra_opt}\"
    fi
fi

tmux kill-session -t trex 2>/dev/null
for pci in "${pciArray[@]}"; do
    if (( ${dpdkBound[$pci]} == 0 )); then
        bindKmod ${pci}
    fi
    rm -rf /dev/hugepages/${page_prefix}*
done
 
exit 0

