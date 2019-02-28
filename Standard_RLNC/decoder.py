#!/usr/bin/env python

"""
This python script is used to collect and organise all the coded symbols
and coefficients used in the coding process in matrices with the purpose
of decoding and obtaining the original symbols that were sent with the
sender.py script
"""

import sys
import struct
import os
from operator import itemgetter
from pyfinite import ffield
from pyfinite import genericmatrix
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
original_symbols = []
F = ffield.FField(8,gen=0x11b, useLUT=0)
XOR = lambda x,y: int(x)^int(y)
AND = lambda x,y: F.Multiply(int(x),int(y))
DIV = lambda x,y: F.Divide(int(x),int(y))
coefficient_matrix = genericmatrix.GenericMatrix((2,2),add=XOR,mul=AND,sub=XOR,div=DIV)


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


def reset_values():
    global packets_received
    global payload_matrix
    global original_symbols
    global coefficient_matrix
    payload_matrix = []
    coefficient_matrix = []
    original_symbols = []
    packets_received = 0
    F = ffield.FField(8,gen=0x11b, useLUT=0)
    coefficient_matrix = genericmatrix.GenericMatrix((2,2),add=XOR,mul=AND,sub=XOR,div=DIV)

def column(matrix,i):
    f = itemgetter(i)
    return map(f,matrix)

def handle_pkt(pkt):
        if P4RLNC in pkt:
            print "got a packet"
            global packets_received
            pkt.show2()
            coeff = str(pkt.getlayer(CoefficientVector).coefficients)
            symbol1 = str(pkt.getlayer(SymbolVector).symbol1)
            symbol2 = str(pkt.getlayer(SymbolVector).symbol2)
            str1 = coeff
            results = map(int, re.findall('\d+', str1 ))
            coefficient_matrix.SetRow(packets_received, results)
            payload_matrix.append([symbol1, symbol2])
            payload_matrix_np = np.array(payload_matrix, dtype="float")
            print "=======GLOBAL_ENCODING======="
            print coefficient_matrix
            print "=======ENCODED_SYNBOLS======="
            print payload_matrix_np

            packets_received += 1
            if packets_received == 2:
                b = map(int,column(payload_matrix,0))
                b1 = map(int,column(payload_matrix,1))
                solve1 = coefficient_matrix.Solve(b)
                solve2 = coefficient_matrix.Solve(b1)
                print "=======ORIGINAL SYMBOLS======="
                original_symbols.append(solve1)
                original_symbols.append(solve2)
                original_symbols_matrix = genericmatrix.GenericMatrix((2,2),add=XOR,mul=AND,sub=XOR,div=DIV)
                original_symbols_matrix.SetRow(0, map(int,column(original_symbols,0)))
                original_symbols_matrix.SetRow(1, map(int,column(original_symbols,1)))
                print original_symbols_matrix
                reset_values()

def main():
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = ifaces[0]
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))


if __name__ == '__main__':
    main()
