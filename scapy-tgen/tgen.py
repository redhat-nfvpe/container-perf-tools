#!/usr/bin/env python3
from scapy.all import *
from typing import List, Tuple
import argparse
import signal
import sys


def signal_handler(sig, frame):
    sys.exit(0)

    
def gen_ip_addr(ip_base: str):
    ip_4_bytes = [int(w) for w in ip_base.split(".")]
    curr_int32 = ip_4_bytes[3] + (ip_4_bytes[2] << 8) + \
        (ip_4_bytes[1] << 16) + (ip_4_bytes[0] << 24)
    while(True):
        ip_4_words = [str((curr_int32 & (0xff << i)) >> i)
                      for i in [24, 16, 8, 0]]
        yield ".".join(ip_4_words)
        curr_int32 += 1
        curr_int32 &= 0xffffffff


def get_ip_list(ip_and_num: str) -> List[str]:
    if "," not in ip_and_num:
        # single ip address, not a range
        return [ip_and_num]
    ip_start, num_str = ip_and_num.split(",")
    num = int(num_str)
    ip_gen = gen_ip_addr(ip_start)
    return [next(ip_gen) for i in range(num)]


def gen_mac_addr(mac_base: str):
    mac_6_bytes = [int(w, 16) for w in mac_base.split(":")]
    curr_int48 = 0
    for i in range(6):
        curr_int48 += (mac_6_bytes[i] << (5-i) * 8)

    while(True):
        mac_6_words = ["{:02x}".format((curr_int48 & (0xff << i)) >> i)
                       for i in [40, 32, 24, 16, 8, 0]]
        yield ":".join(mac_6_words)
        curr_int48 += 1
        curr_int48 &= 0xffffffffffff


def get_mac_list(mac_and_num: str) -> List[str]:
    if "," not in mac_and_num:
        # single mac address
        return [mac_and_num]
    mac_start, num_str = mac_and_num.split(",")
    num = int(num_str)
    mac_gen = gen_mac_addr(mac_start)
    return [next(mac_gen) for i in range(num)]


def get_port_list(port_and_num: str) -> List[int]:
    if "," not in port_and_num:
        # single port
        return [int(port_and_num)]
    port_start, num_str = port_and_num.split(",")
    num = int(num_str)
    base_port = int(port_start)
    return [base_port + i for i in range(num)]


def get_dot1q_tag_prio(tag_and_prio: str) -> Tuple[int, int]:
    if "," not in tag_and_prio:
        return int(tag_and_prio), 0
    vlan_str, prio_str = tag_and_prio.split(",")
    return int(vlan_str), int(prio_str)


def get_qinq_tag_prio(tag_and_prio: str) -> Tuple[int, int, int]:
    qinq_list = tag_and_prio.split(",")
    if len(qinq_list) == 1:
        return int(qinq_list[0]), int(qinq_list[0]), 0
    elif len(qinq_list) == 2:
        return int(qinq_list[0]), int(qinq_list[1]), 0
    else:
        return int(qinq_list[0]), int(qinq_list[1]), int(qinq_list[2])

    
def start_stream(src_mac: List[str], dst_mac: List[str],
                 src_ip: List[str], dst_ip: List[str],
                 src_port: List[int], dst_port: List[int], size: int,
                 interface: str, dot1q: str, qinq: str):
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    print(f"src_ip={src_ip}")
    print(f"dst_ip={dst_ip}")
    print(f"src_mac={src_mac}")
    print(f"dst_mac={dst_mac}")
    print(f"src_port={src_port}")
    print(f"dst_port={dst_port}")
    print(f"interface={interface}")
    
    # beginning of the l2 build
    l2_str = "Ether(src=src_mac, dst=dst_mac)"
    
    # UDP + IP header = 28; ethernet header/FCS = 18, payload size = size - 28 - 18
    # dot1q take extra 4 bytes
    # QinQ take exatra 8 bytes
    dot1q_tag, dot1q_prio = get_dot1q_tag_prio(dot1q)
    qinq_outer_tag, qinq_inner_tag, qinq_prio = get_qinq_tag_prio(qinq)
    if dot1q_tag != 0 or dot1q_prio != 0:
        print(f"dot1q_tag={dot1q_tag}")
        print(f"dot1q_prio={dot1q_prio}")
        l2_str += "/Dot1Q(vlan=dot1q_tag, prio=dot1q_prio, id=0)"
        payload = "x" * (size - 28 - 18 - 4)
    elif qinq_outer_tag != 0:
        print(f"qinq_outer_tag={qinq_outer_tag}")
        print(f"qinq_inner_tag={qinq_inner_tag}")
        print(f"qinq_prio={qinq_prio}")
        l2_str += "/Dot1AD(vlan=qinq_outer_tag, prio=qinq_prio)"
        l2_str += "/Dot1Q(vlan=qinq_inner_tag, prio=qinq_prio)"
        payload = "x" * (size - 28 - 18 - 8)
    else:
        payload = "x" * (size - 28 - 18)
    
    l3_str = "IP(src=src_ip, dst=dst_ip)"
    
    l4_str = "UDP(sport=src_port, dport=dst_port)"
    
    print(f"payload=\"{payload}\"")

    send_cmd = f"sendp({l2_str}/{l3_str}/{l4_str}/Raw(load=payload), iface=interface, loop=1, verbose=0)"
    print(f"{send_cmd}")

    exec(send_cmd)
    

def parse_args():
    parser = argparse.ArgumentParser(description="Sending traffic.")
    parser.add_argument("--src-ip", default="1.1.1.1",
                        help="<base_ip>,<number> for a range of src ip address")
    parser.add_argument("--dst-ip", default="1.1.1.2",
                        help="<base_ip>,<number> for a range of dst ip address")
    parser.add_argument("--src-mac", default="c6:0f:aa:aa:00:00",
                        help="<base_mac>,<number> for a range of src mac address")
    parser.add_argument("--dst-mac", default="c6:0f:bb:bb:00:00",
                        help="<base_mac>,<number> for a range of dst mac address")
    parser.add_argument("--src-port", default="10000",
                        help="<base_port>,<number> for a range of src port")
    parser.add_argument("--dst-port", default="20000",
                        help="<base_port>,<number> for a range of dst port")
    # dot1q and qinq are mutually exlusive options
    dot1q_group = parser.add_mutually_exclusive_group()
    dot1q_group.add_argument("--dot1q", default="0,0",
                        help="<vlan_tag>,<prio> 802.1Q vlan tag and priority")
    dot1q_group.add_argument("--qinq", default="0,0,0",
                        help="<outer_tag>,<inner_tag>,<prio> for QinQ tags and priority")
    parser.add_argument("--size", default=64, type=int,
                        help="packet size")
    parser.add_argument("--interface", required=True,
                        help="interface to send out the packets")
    args = parser.parse_args()
    return args


def main():
    args = parse_args()
    src_ip = get_ip_list(args.src_ip)
    dst_ip = get_ip_list(args.dst_ip)
    src_mac = get_mac_list(args.src_mac)
    dst_mac = get_mac_list(args.dst_mac)
    src_port = get_port_list(args.src_port)
    dst_port = get_port_list(args.dst_port)
    size = args.size
    interface = args.interface
    start_stream(src_mac, dst_mac, src_ip, dst_ip, src_port, dst_port, size, interface,
                 args.dot1q, args.qinq)


if __name__ == '__main__':
    main()
