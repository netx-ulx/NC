#!/usr/bin/env python
import argparse
import sys
import socket
import random
import struct

from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, StrFixedLenField, XByteField, IntField, ShortField, BitField, ByteField
from scapy.all import IP, UDP
from scapy.all import bind_layers
from myCoding_header import *



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
    symbol1 = raw_input('Enter the first number for the multiplication\n')
    symbol2 = raw_input('Enter the second number for the multiplication\n')

    symbol1 = int(symbol1)
    symbol2 = int(symbol2)


    iface = get_if()[0]
    iface1 = get_if()[1]

    print "sending on interface {}".format(iface)
    pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
    pkt = pkt / P4FFCALC(a=symbol1, b=symbol2)
    sendp(pkt, iface=iface, verbose=False)
    pkt.show2()









if __name__ == '__main__':
    main()
