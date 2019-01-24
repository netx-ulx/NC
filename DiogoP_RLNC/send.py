#!/usr/bin/env python
import argparse
import sys
import socket
import random
import struct
import ffield
import genericmatrix
from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, StrFixedLenField, XByteField, IntField, ShortField, BitField, ByteField
from scapy.all import IP, UDP
from scapy.all import bind_layers
from myCoding_header import *


F = ffield.FField(8,gen=0x11b, useLUT=0)
XOR = lambda x,y: int(x)^int(y)
AND = lambda x,y: F.Multiply(int(x),int(y))
DIV = lambda x,y: F.Divide(int(x),int(y))
v = genericmatrix.GenericMatrix((3,2),add=XOR,mul=AND,sub=XOR,div=DIV)
v1 = genericmatrix.GenericMatrix((3,3),add=XOR,mul=AND,sub=XOR,div=DIV)

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
    iface1 = get_if()[1]

    
    symbol1 = raw_input('Enter the first symbol of the first packet to be sent\n')
    symbol2 = raw_input('Enter the second symbol of the first packet to be sent\n')

    symbol1 = int(symbol1)
    symbol2 = int(symbol2)
    print "sending on interface {}".format(iface)
    pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
    pkt = pkt / P4RLNC()/ CoefficientVector(count=3, coefficients=[Coefficient(coefficient=1), Coefficient(coefficient=0), Coefficient(coefficient=0)])
    pkt = pkt / SymbolVector(symbol1=symbol1, symbol2=symbol2)
    pkt = pkt / "Payload"
    sendp(pkt, iface=iface, verbose=False)
    v.SetRow(0,[symbol1,symbol2])

    symbol1 = raw_input('Enter the first symbol of the second packet to be sent\n')
    symbol2 = raw_input('Enter the second symbol of the second packet to be sent\n')
    symbol1 = int(symbol1)
    symbol2 = int(symbol2)
    print "sending on interface {}".format(iface)
    pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
    pkt = pkt / P4RLNC()/ CoefficientVector(count=3, coefficients=[Coefficient(coefficient=0), Coefficient(coefficient=1), Coefficient(coefficient=0)])
    pkt = pkt / SymbolVector(symbol1=symbol1, symbol2=symbol2)
    pkt = pkt / "Payload"
    sendp(pkt, iface=iface, verbose=False)
    v.SetRow(1,[symbol1,symbol2])

    symbol1 = raw_input('Enter the first symbol of the third packet to be sent\n')
    symbol2 = raw_input('Enter the second symbol of the third packet to be sent\n')
    symbol1 = int(symbol1)
    symbol2 = int(symbol2)
    print "sending on interface {}".format(iface)
    pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
    pkt = pkt / P4RLNC()/ CoefficientVector(count=3, coefficients=[Coefficient(coefficient=0), Coefficient(coefficient=0), Coefficient(coefficient=1)])
    pkt = pkt / SymbolVector(symbol1=symbol1, symbol2=symbol2)
    pkt = pkt / "Payload"
    sendp(pkt, iface=iface, verbose=False)
    v.SetRow(2,[symbol1,symbol2])

    v1.SetRow(0,[1,0,0])
    v1.SetRow(1,[0,1,0])
    v1.SetRow(2,[0,0,1])

    print "ORIGINAL SYMBOLS"
    print v
    print "ORIGINAL COEFFICIENTS"
    print v1


if __name__ == '__main__':
    main()
