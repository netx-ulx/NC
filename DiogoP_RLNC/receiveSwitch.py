#!/usr/bin/env python
import sys
import struct
import os
import argparse

from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet, IPOption
from scapy.all import ShortField, IntField, LongField, BitField, FieldListField, FieldLenField
from scapy.all import IP, TCP, UDP, Raw
from scapy.layers.inet import _IPOption_HDR
from myCoding_header import *

def get_if(switch,port):
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if port in i and switch in i:
            iface=i
            break;
    if not iface:
        print "Cannot find interface"
        exit(1)
    return iface

def handle_pkt(pkt):
        if P4RLNC in pkt:
            print "got a packet"
            pkt.show2()
        #    hexdump(pkt)
            sys.stdout.flush()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('switch', type=str, help="The switch wanted")
    parser.add_argument('port', type=str, help="The port in which the program is listening")
    args = parser.parse_args()
    switch = args.switch
    port = args.port
    iface = get_if(switch,port)
    print "sniffing on %s" % iface
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
    main()
