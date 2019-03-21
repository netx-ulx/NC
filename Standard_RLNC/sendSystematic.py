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
from argparse import ArgumentParser
from myCoding_header import *


F = ffield.FField(8,gen=0x11b, useLUT=0)
XOR = lambda x,y: int(x)^int(y)
AND = lambda x,y: F.Multiply(int(x),int(y))
DIV = lambda x,y: F.Divide(int(x),int(y))

bind_layers(Ether, P4RLNC_OUT, type=0x0809)
bind_layers(P4RLNC_OUT, P4RLNC_IN)
bind_layers(P4RLNC_IN, CoefficientVector)
bind_layers(CoefficientVector, SymbolVector)


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
    iface = get_if()[0]
    parser = ArgumentParser()
    parser.add_argument('--gen_size', action="store", dest='gen_size', default=4)
    parser.add_argument('--number_of_symbols', action="store", dest='number_of_symbols', default=2)
    parser.add_argument('--number_of_packets', action="store", dest='number_of_packets', default=2)
    args = parser.parse_args()
    number_of_packets = int(args.number_of_packets)
    number_of_symbols = int(args.number_of_symbols)
    gen_size = int(args.gen_size)
    original_symbols = genericmatrix.GenericMatrix((gen_size,1),add=XOR,mul=AND,sub=XOR,div=DIV)
    while True:
        inc = 0
        symbols_vector = []
        for i in range(0,number_of_packets):
            for j in range(0, number_of_symbols):
                symbol = raw_input('Enter the ' + str(j) +' symbol of the ' + str(i) +' packet to be sent\n')
                symbols_vector.append(int(symbol))
                original_symbols.SetRow(inc, [int(symbol)])
                inc +=1

            print "sending on interface {}".format(iface)
            print "=====================FIRST PACKET======================="
            pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
            pkt = pkt / P4RLNC_OUT(Gen_Size=gen_size)/ P4RLNC_IN(Type=1, Symbols=number_of_symbols) / CoefficientVector()
            pkt = pkt / SymbolVector(symbols_vector=symbols_vector)
            sendp(pkt, iface=iface, verbose=False)
            pkt.show2()
            symbols_vector = []

        print "ORIGINAL SYMBOLS"
        print original_symbols


if __name__ == '__main__':
    main()
