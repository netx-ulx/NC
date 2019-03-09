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
coefficient_matrix_s1 = []
coefficient_matrix_s2 = []
packets_received = 0
original_symbols = []
original_symbols_2 = []
F = ffield.FField(8,gen=0x11b, useLUT=0)
XOR = lambda x,y: int(x)^int(y)
AND = lambda x,y: F.Multiply(int(x),int(y))
DIV = lambda x,y: F.Divide(int(x),int(y))
coefficient_matrix_s1 = genericmatrix.GenericMatrix((4,4),add=XOR,mul=AND,sub=XOR,div=DIV)
# The symbols to be coded
class CodedSymbol(Packet):
   fields_desc = [ByteField("coded_symbol", 1)]
bind_layers(Ether, P4RLNC_OUT, type=0x0809)
bind_layers(P4RLNC_OUT, P4RLNC_IN)
bind_layers(P4RLNC_IN, CoefficientVector)
bind_layers(CoefficientVector, CodedSymbol)

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
    global coefficient_matrix_s1
    payload_matrix = []
    coefficient_matrix_s1 = []
    original_symbols = []
    packets_received = 0
    F = ffield.FField(8,gen=0x11b, useLUT=0)
    coefficient_matrix_s1 = genericmatrix.GenericMatrix((4,4),add=XOR,mul=AND,sub=XOR,div=DIV)

def column(matrix,i):
    f = itemgetter(i)
    return map(f,matrix)

def handle_pkt(pkt):
        if P4RLNC_OUT in pkt:
            print "got a packet"
            global packets_received
            pkt.show2()
            symbol1 = str(pkt.getlayer(CodedSymbol).coded_symbol)
            coef1 = str(pkt.getlayer(CoefficientVector).coef1)
            coef2 = str(pkt.getlayer(CoefficientVector).coef2)
            coef3 = str(pkt.getlayer(CoefficientVector).coef3)
            coef4 = str(pkt.getlayer(CoefficientVector).coef4)
            coefficient_matrix_s1.SetRow(packets_received, [coef1, coef2, coef3, coef4])
            payload_matrix.append([symbol1])
            payload_matrix_np = np.array(payload_matrix, dtype="float")
            print "=======RANDOM COEFFICIENT MATRIX======="
            print coefficient_matrix_s1
            print "=======ENCODED_SYNBOLS======="
            print payload_matrix_np

            packets_received += 1
            if packets_received == 4:
                b = map(int,column(payload_matrix,0))
                solve1 = coefficient_matrix_s1.Solve(b)
                print "=======ORIGINAL SYMBOLS======="
                original_symbols.append(solve1)
                original_symbols_matrix = genericmatrix.GenericMatrix((4,1),add=XOR,mul=AND,sub=XOR,div=DIV)
                original_symbols_matrix.SetRow(0, map(int,column(original_symbols,0)))
                original_symbols_matrix.SetRow(1, map(int,column(original_symbols,2)))
                original_symbols_matrix.SetRow(2, map(int,column(original_symbols,1)))
                original_symbols_matrix.SetRow(3, map(int,column(original_symbols,3)))
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
