#!/usr/bin/env python

"""
This python script is used to generate and send packets
through the use of the scapy package. It sends 2 packets
as an example for this exercise. Furthermore it arranges
the symbols and the coefficients sent in matrices to facilitate
the visualization of the exercise for the user
"""

import argparse
import sys
import socket
import random
import struct
from pyfinite import ffield
from pyfinite import genericmatrix
from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import bind_layers
from myCoding_header import *


F = ffield.FField(8,gen=0x11b, useLUT=0)
XOR = lambda x,y: int(x)^int(y)
AND = lambda x,y: F.Multiply(int(x),int(y))
DIV = lambda x,y: F.Divide(int(x),int(y))
v = genericmatrix.GenericMatrix((4,1),add=XOR,mul=AND,sub=XOR,div=DIV)
bind_layers(Ether, P4RLNC_OUT, type=0x0809)
bind_layers(P4RLNC_OUT, P4RLNC_IN)
bind_layers(P4RLNC_IN, SymbolVector)


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

def utf8len(s):
    return len(s.encode('utf-8'))


number_of_packets = 2
def main():

    iface = get_if()[0]

    while True:
        j = 0;
        for i in range(0,number_of_packets):
            symbol1 = raw_input('Enter the first symbol of the ' + str(i) +' packet to be sent\n')
            symbol2 = raw_input('Enter the second symbol of the ' + str(i) +' packet to be sent\n')

            symbol1 = int(symbol1)
            symbol2 = int(symbol2)
            print "sending on interface {}".format(iface)
            print "=====================FIRST PACKET======================="
            pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
            pkt = pkt / P4RLNC_OUT()/ P4RLNC_IN(Type=1, Symbols=2, Encoder_Rank=0)
            pkt = pkt / SymbolVector(symbol1=symbol1, symbol2=symbol2)
            sendp(pkt, iface=iface, verbose=False)
            pkt.show2()
            v.SetRow(j,[symbol1])
            j = j + 1
            v.SetRow(j,[symbol2])
            j = j + 1

        print "ORIGINAL SYMBOLS"
        print v


if __name__ == '__main__':
    main()
