#!/bin/bash

function sigfunc() {
    pid=`pgrep binary-search`
    [ -z ${pid} ] || kill ${pid}
    tmux kill-session -t trex 2>/dev/null
    exit 0
}

trap sigfunc SIGTERM SIGINT SIGUSR1

validation_seconds=${validation_seconds:-30}
search_seconds=${search_seconds:-10}
sniff_seconds=${sniff_seconds:-10}
loss_ratio=${loss_ratio:-0.002}
flows=${flows:-1}
frame_size=${frame_size:-64}

if [ -z "$1" ]; then
    # do nothing
    cd /root/tgen
    sleep infinity

else
    if [ -z "${pci_list}" ]; then
        echo "need env var: pci_list"
        exit 1
    fi
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

    cd /root/tgen
    if [ "$1" == "start" ]; then
        ./launch-trex.sh --devices=${pci_list} --use-vlan=y
        count=60
        num_ports=0
        while [ ${count} -gt 0 -a ${num_ports} -lt 2 ]; do
            sleep 1
            num_ports=`netstat -tln | grep -E :4500\|:4501 | wc -l`
            ((count--))
        done
        if [ ${num_ports} -eq 2 ]; then
            echo "trex-server is ready"
            for size in $(echo ${frame_size} | sed -e 's/,/ /g'); do
                ./binary-search.py --traffic-generator=trex-txrx --rate-tolerance=10 --use-src-ip-flows=1 --use-dst-ip-flows=1 --use-src-mac-flows=1 --use-dst-mac-flows=1 \
                --use-src-port-flows=0 --use-dst-port-flows=0 --use-encap-src-ip-flows=0 --use-encap-dst-ip-flows=0 --use-encap-src-mac-flows=0 --use-encap-dst-mac-flows=0 \
                --use-protocol-flows=0 --device-pairs=${device_pairs} --active-device-pairs=${device_pairs} --sniff-runtime=${sniff_seconds} \
                --search-runtime=${search_seconds} --validation-runtime=${validation_seconds} --max-loss-pct=${loss_ratio} \
                --traffic-direction=bidirectional --frame-size=${size} --num-flows=${flows} --rate-tolerance-failure=fail \
                --rate-unit=% --rate=100
            done
        else
            echo "ERROR: trex-server could not start properly. Check \'tmux attach -t trex\' and/or \'cat /tmp/trex.server.out\'"
            sleep infinity 
        fi
    elif [ "$1" == "server" ]; then
        ./launch-trex.sh --devices=${pci_list} --use-vlan=y --no-tmux=y
    elif [ "$1" == "client" ]; then
        num_ports=0
        while [ ${num_ports} -lt 2 ]; do
            echo "Waiting for trex-server"
            sleep 1
            num_ports=`netstat -tln | grep -E :4500\|:4501 | wc -l`
        done
        echo "trex-server is ready"
        python server.py
    fi

fi

tmux kill-session -t trex 2>/dev/null
exit 0

