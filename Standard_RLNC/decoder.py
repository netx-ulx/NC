#!/usr/bin/env python

"""
This python script is used to collect and organise all the coded symbols
and coefficients used in the coding process in matrices with the purpose
of decoding and obtaining the original symbols that were sent
"""

import sys
import struct
import os
from operator import itemgetter
from pyfinite import ffield
from pyfinite import genericmatrix
from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet
import numpy as np
from random import randint
from myCoding_header import *

gen_size = 4
number_of_symbols = 2

payload_matrix = []
coefficient_matrix_s1 = []
packet_number = 0
coeff_rows = 0
packets_to_drop_list = []
original_symbols = []
F = ffield.FField(8,gen=0x11b, useLUT=0)
XOR = lambda x,y: int(x)^int(y)
AND = lambda x,y: F.Multiply(int(x),int(y))
DIV = lambda x,y: F.Divide(int(x),int(y))
coefficient_matrix_s1 = genericmatrix.GenericMatrix((gen_size,gen_size),add=XOR,mul=AND,sub=XOR,div=DIV)

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
    global packet_number
    global payload_matrix
    global original_symbols
    global coefficient_matrix_s1
    payload_matrix = []
    coefficient_matrix_s1 = []
    original_symbols = []
    packet_number = 0
    F = ffield.FField(8,gen=0x11b, useLUT=0)
    coefficient_matrix_s1 = genericmatrix.GenericMatrix((gen_size,gen_size),add=XOR,mul=AND,sub=XOR,div=DIV)

def column(matrix,i):
    f = itemgetter(i)
    return map(f,matrix)

def handle_pkt(pkt):
        if P4RLNC_OUT in pkt:
            print "got a packet"
            global packet_number
            global coeff_rows
            global packets_to_drop_list
            print packet_number
            print packets_to_drop_list
            if packet_number in packets_to_drop_list:
                packet_number += 1
                return
            pkt.show2()
            symbol1 = int(pkt.getlayer(CodedSymbol).coded_symbol)
            coef1 = int(pkt.getlayer(CoefficientVector).coef1)
            coef2 = int(pkt.getlayer(CoefficientVector).coef2)
            coef3 = int(pkt.getlayer(CoefficientVector).coef3)
            coef4 = int(pkt.getlayer(CoefficientVector).coef4)
            coefficient_matrix_s1.SetRow(coeff_rows, [coef1, coef2, coef3, coef4])
            payload_matrix.append([symbol1])
            print "=======RANDOM COEFFICIENT MATRIX======="
            print coefficient_matrix_s1
            print "=======ENCODED_SYNBOLS======="
            print payload_matrix

            packet_number += 1
            coeff_rows += 1
            if coeff_rows == 4:
                b = column(payload_matrix,0)
                solve1 = coefficient_matrix_s1.Solve(b)
                print "=======ORIGINAL SYMBOLS======="
                original_symbols.append(solve1)
                original_symbols_matrix = genericmatrix.GenericMatrix((gen_size,1),add=XOR,mul=AND,sub=XOR,div=DIV)
                for i in range(0, gen_size):
                    original_symbols_matrix.SetRow(i, map(int,column(original_symbols,i)))
                print original_symbols_matrix
                reset_values()

def select_random_packets_to_drop(n):
    global packets_to_drop_list
    packets_to_drop_list = random.sample(range(gen_size), n)

def main():
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = ifaces[0]
    select_random_packets_to_drop(0)
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))


if __name__ == '__main__':
    main()
