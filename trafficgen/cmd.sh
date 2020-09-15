#!/bin/bash

function sigfunc() {
    pid=`pgrep binary-search`
    [ -z ${pid} ] || kill ${pid}
    tmux kill-session -t trex
    exit 0
}

trap sigfunc SIGTERM SIGINT SIGUSR1

echo "############# dumping env ###########"
env
echo "#####################################"

TREX_VER=${TREX_VER:-"v2.82"}
validation_seconds=${validation_seconds:-30}
search_seconds=${search_seconds:-10}
sniff_seconds=${sniff_seconds:-10}
loss_ratio=${loss_ratio:-0.002}
flows=${flows:-1}
frame_size=${frame_size:-64}
manual=${manual:-n}
 
if [ "$manual" == "y" ]; then
    # do nothing
    sleep infinity
    exit 0 

else
    if [ -z "${pci_list}" ]; then
        echo "need env var: pci_list"
        exit 0
    fi
    # how many devices?
    number_of_devices=$(echo ${pci_list} | sed -e 's/,/ /g' | wc -w)
    if [ ${number_of_devices} -lt 2 ]; then
        echo "need at least 2 pci devices"
        exit 0
    fi

    mkdir -p /opt/trex
    curl -k -o $TREX_VER.tar.gz https://trex-tgn.cisco.com/trex/release/$TREX_VER.tar.gz
    tar xzf $TREX_VER.tar.gz -C /opt/trex && ln -sf /opt/trex/${TREX_VER} /opt/trex/current
    rm -f $TREX_VER.tar.gz

    mkdir -p /var/log/tgen
    mkdir -p /root/tgen
    cd /root/tgen
    curl -L -o binary-search.py https://raw.githubusercontent.com/atheurer/trafficgen/master/binary-search.py
    curl -L -o trex-txrx.py https://raw.githubusercontent.com/atheurer/trafficgen/master/trex-txrx.py 
    curl -L -o trex-query.py https://raw.githubusercontent.com/atheurer/trafficgen/master/trex-query.py
    curl -L -o trex_tg_lib.py https://raw.githubusercontent.com/atheurer/trafficgen/master/trex_tg_lib.py
    curl -L -o tg_lib.py https://raw.githubusercontent.com/atheurer/trafficgen/master/tg_lib.py
    cp $(dirname $(readlink -f $0))/launch-trex.sh launch-trex.sh 
    chmod 777 launch-trex.sh binary-search.py trex-query.py trex-txrx.py

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

    ./launch-trex.sh --devices=${pci_list} --use-vlan=y
    sleep 1
    for size in $(echo ${frame_size} | sed -e 's/,/ /g'); do
        ./binary-search.py --traffic-generator=trex-txrx --rate-tolerance=10 --use-src-ip-flows=1 --use-dst-ip-flows=1 --use-src-mac-flows=1 --use-dst-mac-flows=1 \
                --use-src-port-flows=0 --use-dst-port-flows=0 --use-encap-src-ip-flows=0 --use-encap-dst-ip-flows=0 --use-encap-src-mac-flows=0 --use-encap-dst-mac-flows=0 \
                --use-protocol-flows=0 --device-pairs=${device_pairs} --active-device-pairs=${device_pairs} --sniff-runtime=${sniff_seconds} \
                --search-runtime=${search_seconds} --validation-runtime=${validation_seconds} --max-loss-pct=${loss_ratio} \
                --traffic-direction=bidirectional --frame-size=${size} --num-flows=${flows} --rate-tolerance-failure=fail \
                --rate-unit=% --rate=100
    done
    
fi
