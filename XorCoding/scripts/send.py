#!/usr/bin/env python
import argparse
import sys
import socket
import random
import struct

from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, StrFixedLenField, XByteField, IntField, ShortField
from scapy.all import bind_layers
from myCoding_header import P4code



def get_if():
    ifs=get_if_list()
    iface=None # "h1-eth0"
    iface1=None # "h1-eth1"
    for i in get_if_list():
        if "eth0" in i:
            iface=i
        if "eth1" in i:
            iface1=i
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return (iface,iface1)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('message', type=str, help="The first message to include in packet 1")
    parser.add_argument('message1', type=str, help="The second message to include in packet 2")
    args = parser.parse_args()

    message = args.message
    message1 = args.message1


    iface = get_if()[0]
    iface1 = get_if()[1]

    print "sending on interface {}".format(iface)
    pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
    pkt = pkt / P4code(Generation=0, Generation_Size=2) / message
    sendp(pkt, iface=iface, verbose=False)
    pkt.show2();

    print "sending on interface {}".format(iface1)
    pkt1 =  Ether(src=get_if_hwaddr(iface1), dst='ff:ff:ff:ff:ff:ff')
    pkt1 = pkt1 / P4code(Generation=0, Generation_Size=2) / message1
    sendp(pkt1, iface=iface1, verbose=False)
    pkt.show2();












if __name__ == '__main__':
    main()
