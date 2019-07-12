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
from threading import Timer
from pyfinite import ffield
from pyfinite import genericmatrix
from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet
from myCoding_header import *
from argparse import ArgumentParser
from lib import parser

coefficient_matrix_s1 = genericmatrix.GenericMatrix((0,0))
payload_matrix = []
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

def column(matrix, i):
    return [row[i] for row in matrix]

def build_FF_matrix(gen_size):
    """ Build the matrix where the coefficients are going to be put """
    return genericmatrix.GenericMatrix((gen_size,gen_size),add=XOR,mul=AND,sub=XOR,div=DIV)

def set_finite_field(field_size):
    """ Sets the finite field deptimestamp_current_last_packeting of the field size """
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
    original_symbols_matrix = genericmatrix.GenericMatrix((gen_size,1),add=XOR,mul=AND,sub=XOR,div=DIV)
    for i in range(0, gen_size):
        original_symbols_matrix.SetRow(i, [solve1[i]])
    print original_symbols_matrix

def reset(gen_size):
    global coeff_rows
    global coefficient_matrix_s1
    global payload_matrix
    coeff_rows = 0
    coefficient_matrix_s1 = build_FF_matrix(gen_size)
    payload_matrix = []

def handle_pkt(pkt, gen_size, symbols):
    """ Called when a packet arrives, it builds the coefficient and encoded symbol matrices as they arrive When the coefficient matrix reaches full rank then its time to decode """
    if P4RLNC in pkt:
            global coeff_rows
            global coefficient_matrix_s1
            global payload_matrix
            print "got a packet"
            coded_symbol = (pkt.getlayer(P4RLNC).symbols_vector)
            coeff_vector = (pkt.getlayer(P4RLNC).coefficient_vector)
            pkt.show2()
            for i in range(0, symbols):
                tmp_coeff_vector = coeff_vector[:gen_size]
                del coeff_vector[:gen_size]
                coefficient_matrix_s1.SetRow(coeff_rows, tmp_coeff_vector)
                coeff_rows += 1
            for e in coded_symbol:
                payload_matrix.append([e])
            if coeff_rows == gen_size:
                decode(payload_matrix, coefficient_matrix_s1, gen_size)
                gen_id = (pkt.getlayer(P4RLNC).Gen_ID)
                reset(gen_size)

def main():
    global coefficient_matrix_s1
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = "veth3"
    _, gen_size, number_of_symbols, field_size, _, _ = parser.get_receiver_args()
    print iface
    set_finite_field(field_size)
    coefficient_matrix_s1 = build_FF_matrix(gen_size)
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x, gen_size, number_of_symbols))


if __name__ == '__main__':
    main()
