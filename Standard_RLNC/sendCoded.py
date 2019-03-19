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
class CodedSymbol(Packet):
   fields_desc = [ByteField("coded_symbol", 1)]
bind_layers(Ether, P4RLNC_OUT, type=0x0809)
bind_layers(P4RLNC_OUT, P4RLNC_IN)
bind_layers(P4RLNC_IN, CoefficientVector)
bind_layers(CoefficientVector, CodedSymbol)


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


def main():

        iface = get_if()[0]

        symbol1 = 249
        print "sending on interface {}".format(iface)
        print "=====================FIRST PACKET======================="
        pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
        pkt = pkt / P4RLNC_OUT()/ P4RLNC_IN(Type=3, Symbols=1, Encoder_Rank=4)
        pkt = pkt / CoefficientVector(coef1=13, coef2=112, coef3=186, coef4=251)
        pkt = pkt / CodedSymbol(coded_symbol=symbol1)
        sendp(pkt, iface=iface, verbose=False)
        pkt.show2()
        v.SetRow(0,[symbol1])

        symbol1 = 190
        print "sending on interface {}".format(iface)
        "=====================SECOND PACKET======================="
        pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
        pkt = pkt / P4RLNC_OUT()/ P4RLNC_IN(Type=3, Symbols=1, Encoder_Rank=4)
        pkt = pkt / CoefficientVector(coef1=188, coef2=186, coef3=126, coef4=125)
        pkt = pkt / CodedSymbol(coded_symbol=symbol1)
        sendp(pkt, iface=iface, verbose=False)
        pkt.show2()
        v.SetRow(1,[symbol1])


        symbol1 = 74
        print "sending on interface {}".format(iface)
        print "=====================THIRD PACKET======================="
        pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
        pkt = pkt / P4RLNC_OUT()/ P4RLNC_IN(Type=3, Symbols=1, Encoder_Rank=4)
        pkt = pkt / CoefficientVector(coef1=52, coef2=84, coef3=211, coef4=46)
        pkt = pkt / CodedSymbol(coded_symbol=symbol1)
        sendp(pkt, iface=iface, verbose=False)
        pkt.show2()
        v.SetRow(2,[symbol1])

        symbol1 = 114
        print "sending on interface {}".format(iface)
        "=====================FOURTH PACKET======================="
        pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
        pkt = pkt / P4RLNC_OUT()/ P4RLNC_IN(Type=3, Symbols=1, Encoder_Rank=4)
        pkt = pkt / CoefficientVector(coef1=153, coef2=41, coef3=44, coef4=248)
        pkt = pkt / CodedSymbol(coded_symbol=symbol1)
        sendp(pkt, iface=iface, verbose=False)
        pkt.show2()
        v.SetRow(3,[symbol1])

        print "ORIGINAL SYMBOLS"
        print v


if __name__ == '__main__':
    main()
