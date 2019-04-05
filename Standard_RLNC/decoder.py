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
from argparse import ArgumentParser
from lib import parser


packet_number = 0
coeff_rows = 0
F = 0
XOR = 0
AND = 0
DIV = 0

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

def column(matrix,i):
    """ Return the specified column of a matrix """
    f = itemgetter(i)
    return map(f,matrix)

def build_FF_matrix(gen_size):
    """ Build the matrix where the coefficients are going to be put """
    return genericmatrix.GenericMatrix((gen_size,gen_size),add=XOR,mul=AND,sub=XOR,div=DIV)

def select_random_packets_to_drop(gen_size, n):
    """ Selects random packets to drop """
    return random.sample(range(gen_size), n)

def set_finite_field(field_size):
    """ Sets the finite field depending of the field size """
    global F
    global XOR
    global AND
    global DIV
    if field_size == 8:
        F = ffield.FField(field_size,gen=0x11b, useLUT=0)
        XOR = lambda x,y: int(x)^int(y)
        AND = lambda x,y: F.Multiply(int(x),int(y))
        DIV = lambda x,y: F.Divide(int(x),int(y))
    elif field_size == 16:
        F = ffield.FField(field_size)
        XOR = lambda x,y: int(x)^int(y)
        AND = lambda x,y: F.Multiply(int(x),int(y))
        DIV = lambda x,y: F.Divide(int(x),int(y))

def print_matrices(coefficient_matrix_s1, payload_matrix):
    """ Prints the coefficient matrix and the encoded symbols matrix """
    print "=======RANDOM COEFFICIENT MATRIX======="
    print coefficient_matrix_s1
    print "=======ENCODED_SYMBOLS======="
    print payload_matrix

def decode(payload_matrix, coefficient_matrix_s1, gen_size):
    """ Decodes the encoded symbols using the coefficient matrix """
    set_finite_field
    b = column(payload_matrix,0)
    print b
    solve1 = coefficient_matrix_s1.Solve(b)
    original_symbols = []
    original_symbols.append(solve1)
    original_symbols_matrix = genericmatrix.GenericMatrix((gen_size,1),add=XOR,mul=AND,sub=XOR,div=DIV)
    for i in range(0, gen_size):
        original_symbols_matrix.SetRow(i, map(int,column(original_symbols,i)))
    print "=======ORIGINAL SYMBOLS======="
    print original_symbols_matrix

def handle_pkt(pkt, payload_matrix, coefficient_matrix_s1, packets_to_drop_list, gen_size, symbols):
    """ Called when a packet arrives, it builds the coefficient and encoded symbol matrices as they arrive When the coefficient matrix reaches full rank then its time to decode """
    if P4RLNC in pkt:
            global packet_number
            global coeff_rows
            print "got a packet"
            if packet_number in packets_to_drop_list:
                packet_number += 1
                return
            pkt.show2()
            coded_symbol = (pkt.getlayer(P4RLNC).symbols_vector)
            coeff_vector = (pkt.getlayer(P4RLNC).coefficient_vector)
            for i in range(0, symbols):
                tmp_coeff_vector = coeff_vector[:gen_size]
                del coeff_vector[:gen_size]
                coefficient_matrix_s1.SetRow(coeff_rows, tmp_coeff_vector)
                coeff_rows += 1
            for e in coded_symbol:
                payload_matrix.append([e])
            packet_number += 1
            print_matrices(coefficient_matrix_s1, payload_matrix)
            if coeff_rows == gen_size:
                decode(payload_matrix, coefficient_matrix_s1, gen_size)
                sys.exit()

def main():
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = ifaces[0]
    gen_size, number_of_symbols, packet_loss, field_size = parser.get_decoder_args()
    set_finite_field(field_size)
    packets_to_drop_list = []
    coefficient_matrix_s1 = build_FF_matrix(gen_size)
    payload_matrix = []
    packets_to_drop_list = select_random_packets_to_drop(gen_size, packet_loss)
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x, payload_matrix, coefficient_matrix_s1, packets_to_drop_list, gen_size, number_of_symbols))


if __name__ == '__main__':
    main()
