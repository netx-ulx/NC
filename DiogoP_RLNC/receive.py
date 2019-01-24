#!/usr/bin/env python
import sys
import struct
import os
from operator import itemgetter
import ffield
import genericmatrix
from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet, IPOption
from scapy.all import ShortField, IntField, LongField, BitField, FieldListField, FieldLenField
from scapy.all import IP, TCP, UDP, Raw, Ether
from scapy.layers.inet import _IPOption_HDR
import binascii
import numpy as np
from numpy.linalg import inv
from myCoding_header import *

payload_matrix = []
coefficient_matrix = []
packets_received = 0
F = ffield.FField(8,gen=0x11b, useLUT=0)
XOR = lambda x,y: int(x)^int(y)
AND = lambda x,y: F.Multiply(int(x),int(y))
DIV = lambda x,y: F.Divide(int(x),int(y))
v = genericmatrix.GenericMatrix((3,3),add=XOR,mul=AND,sub=XOR,div=DIV)
def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break;
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return iface

def get_packet_layers(packet):
    counter = 0
    while True:
        layer = packet.getlayer(counter)
        if layer is None:
            break

        yield layer
        counter += 1


def print_n_byte(target, n):
    return hex((target&(0xFF<<(8*n)))>>(8*n))

def expand(x):
    yield x
    while x.payload:
        x = x.payload
        yield x
def column(matrix,i):
    f = itemgetter(i)
    return map(f,matrix)

def handle_pkt(pkt):
        if P4RLNC in pkt:
            print "got a packet"
            global packets_received
            coeff = str(pkt.getlayer(CoefficientVector).coefficients)
            symbol1 = str(pkt.getlayer(SymbolVector).symbol1)
            symbol2 = str(pkt.getlayer(SymbolVector).symbol2)
            str1 = coeff
            results = map(int, re.findall('\d+', str1 ))
            v.SetRow(packets_received, results)
            coefficient_matrix.append(re.findall('\d+', str1 ))
            payload_matrix.append([symbol1, symbol2])
            coefficient_matrix_np = np.array(coefficient_matrix, dtype="float")
            payload_matrix_np = np.array(payload_matrix, dtype="float")
            print "=======GLOBAL_ENCODING======="
            print v
            print "=======ENCODED_SYNBOLS======="
            print payload_matrix_np

            packets_received += 1
            if packets_received == 3:
                b = map(int,column(payload_matrix,0))
                print b
                b1 = map(int,column(payload_matrix,1))
                solve1 = v.Solve(b)
                solve2 = v.Solve(b1)
                print "=======ORIGINAL SYMBOLS======="
                original_symbols = []
                original_symbols.append(solve1)
                original_symbols.append(solve2)
                v1 = genericmatrix.GenericMatrix((3,2),add=XOR,mul=AND,sub=XOR,div=DIV)
                v1.SetRow(0, map(int,column(original_symbols,0)))
                v1.SetRow(1, map(int,column(original_symbols,1)))
                v1.SetRow(2, map(int,column(original_symbols,2)))
                print v1
        #    pkt.show2()

        #    res = list(expand(pkt))
        #    print res
        #    for layer in get_packet_layers(pkt):
        #        print (layer.name)
        #    hexdump(pkt)

def main():
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = ifaces[0]
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))


if __name__ == '__main__':
    main()
