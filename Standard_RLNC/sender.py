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
from random import randint
from myCoding_header import *
from lib import parser

MAX_SYMBOL_VALUE = 0
F = 0
XOR = 0
AND = 0
DIV = 0


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

def set_finite_field(field_size):
    """ Sets the finite field based on the field size """
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

def generate_symbols(n):
    """ Generates n symbols and puts them in a single column matrix"""
    symbols = genericmatrix.GenericMatrix((n,1), add=XOR,mul=AND,sub=XOR,div=DIV)
    for i in range(0,n):
        symbols.SetRow(i, [randint(0, MAX_SYMBOL_VALUE)])
    return symbols

def generate_coefficients(n):
    """ Generates n*n coefficients and puts them in an n*n matrix"""
    coeffs = genericmatrix.GenericMatrix((n,n), add=XOR,mul=AND,sub=XOR,div=DIV)
    for i in range(0, n):
        coeffs.SetRow(i, random.sample(range(MAX_SYMBOL_VALUE), n))
    return coeffs

def code_symbols(symbols, coeffs):
    """ Multiplies the symbol matrix with the coefficient matrix, generating the coded symbols matrix"""
    return coeffs.__mul__(symbols)

def flat_list(l):
    """ Flattens a list"""
    flat_list = []
    for sublist in l:
        for item in sublist:
            flat_list.append(item)
    return flat_list

def send_systematic_packets(number_of_packets, number_of_symbols, gen_size, field_size,iface):
    """ Sends systematic symbols to the receiver, packets with systematic symbols have a type equal to one"""
    original_symbols = generate_symbols(gen_size)
    symbols_vector = original_symbols.GetColumn(0)
    for i in range(0,number_of_packets):
        tmp_symbols_vector = symbols_vector[:number_of_symbols]
        del symbols_vector[:number_of_symbols]
        print "sending on interface {}".format(iface)
        print "=====================FIRST PACKET======================="
        pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
        pkt = pkt / P4RLNC(Gen_Size=gen_size, Type=1, Symbol_Size=field_size, Field_Size=field_size, Symbols=number_of_symbols, symbols_vector=tmp_symbols_vector)
        sendp(pkt, iface=iface, verbose=False)
        pkt.show2()

    print "ORIGINAL SYMBOLS"
    print original_symbols

def send_coded_packets(number_of_packets, number_of_symbols, gen_size, field_size,iface):
    """ Sends coded symbols to the receiver, packets with coded symbols have a type equal to 3 and each symbol is accompannied by its coefficient vector """
    original_symbols = generate_symbols(gen_size)
    coeffs = generate_coefficients(gen_size)
    tmp = []
    coded_symbols = code_symbols(original_symbols, coeffs)
    symbols_vector = coded_symbols.GetColumn(0)
    for i in range(0, gen_size):
        tmp.append(coeffs.GetRow(i))
    coeffs_vector = flat_list(tmp)
    print symbols_vector
    print coeffs_vector
    for i in range(0,number_of_packets):
        tmp_symbols_vector = symbols_vector[:number_of_symbols]
        del symbols_vector[:number_of_symbols]
        tmp_coeffs_vector = coeffs_vector[:number_of_symbols*gen_size]
        del coeffs_vector[:number_of_symbols*gen_size]
        print "sending on interface {}".format(iface)
        print "=====================FIRST PACKET======================="
        pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
        pkt = pkt / P4RLNC(Gen_Size=gen_size, Type=3, Symbol_Size=field_size, Field_Size=field_size, Symbols=number_of_symbols, Encoder_Rank=gen_size,coefficient_vector=tmp_coeffs_vector,symbols_vector=tmp_symbols_vector)
        sendp(pkt, iface=iface, verbose=False)
        pkt.show2()
    print "ORIGINAL SYMBOLS"
    print original_symbols


def main():
    global MAX_SYMBOL_VALUE
    iface = get_if()[0]
    type, gen_size, number_of_symbols, number_of_packets, field_size = parser.get_sender_args()
    set_finite_field(field_size)
    if field_size == 8:
        MAX_SYMBOL_VALUE = 255
    elif field_size == 16:
        MAX_SYMBOL_VALUE = 65535
    if type == 1:
        send_systematic_packets(number_of_packets, number_of_symbols, gen_size, field_size, iface)
    elif type == 3:
        send_coded_packets(number_of_packets, number_of_symbols, gen_size, field_size, iface)


if __name__ == '__main__':
    main()
