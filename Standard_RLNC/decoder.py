#!/usr/bin/env python

"""
This python script is used to collect and organise all the coded symbols
and coefficients used in the coding process in matrices with the purpose
of decoding and obtaining the original symbols that were sent
"""

import sys
import struct
import os
import psutil
from operator import itemgetter
from threading import Timer
from pyfinite import ffield
from pyfinite import genericmatrix
from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet
import numpy as np
import math
from random import randint
from myCoding_header import *
from argparse import ArgumentParser
from lib import parser

coefficient_matrix_s1 = genericmatrix.GenericMatrix((0,0))
payload_matrix = []
packets_received = 0
coeff_rows = 0
F = 0
XOR = 0
AND = 0
DIV = 0
measurement_pkt_rate_list = []
final_pkt_rate_list = []
measurement_cpu_usage_list = []
final_cpu_usage_list = []
timestamp_first_packet = 0

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

def write_symbols_to_file(original_symbols_matrix):
    f = open("symbols_decoder.txt", "a")
    f.write(str(original_symbols_matrix))
    f.write("\n")

def decode(payload_matrix, coefficient_matrix_s1, gen_size):
    """ Decodes the encoded symbols using the coefficient matrix """
    set_finite_field
    b = column(payload_matrix,0)
    solve1 = coefficient_matrix_s1.Solve(b)
    original_symbols = []
    original_symbols.append(solve1)
    original_symbols_matrix = genericmatrix.GenericMatrix((gen_size,1),add=XOR,mul=AND,sub=XOR,div=DIV)
    for i in range(0, gen_size):
        original_symbols_matrix.SetRow(i, map(int,column(original_symbols,i)))
    write_symbols_to_file(original_symbols_matrix)

def reset(gen_size):
    global coeff_rows
    global coefficient_matrix_s1
    global payload_matrix
    coeff_rows = 0
    coefficient_matrix_s1 = build_FF_matrix(gen_size)
    payload_matrix = []

def handle_pkt(pkt, packets_to_drop_list, gen_size, symbols):
    """ Called when a packet arrives, it builds the coefficient and encoded symbol matrices as they arrive When the coefficient matrix reaches full rank then its time to decode """
    if P4RLNC in pkt:
            global packet_number
            global coeff_rows
            global coefficient_matrix_s1
            global payload_matrix
            print "got a packet"
            if packet_number in packets_to_drop_list:
                packet_number += 1
                return
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
            if coeff_rows == gen_size:
                decode(payload_matrix, coefficient_matrix_s1, gen_size)
                gen_id = (pkt.getlayer(P4RLNC).Gen_ID)
                reset(gen_size)

def show_results(number_of_packets, pps):
    """ Calculates the average of the packets per second and cpu usage for each experiment/measurement. Then presents the final results when all measurements have been completed """
    global measurement_pkt_rate_list
    global measurement_cpu_usage_list
    global packets_received
    global final_pkt_rate_list
    global final_cpu_usage_list
    # Sleep the time that the experiment should take plus 5 seconds to compensate for slower packet processing
    time.sleep((number_of_packets/pps) + 5)
    print "Packets received: " + str(packets_received)
    # Reset the packets received so that a new experiment can start over
    packets_received = 0
    print "Running measurement " + str(len(final_pkt_rate_list) + 1) + " of " + str(10)
    # Gets the average of the pps and the cpu usage of a single experiment
    measurement_pps = round(reduce(lambda x, y: x + y, measurement_pkt_rate_list) / len(measurement_pkt_rate_list))
    measurement_cpu = round(reduce(lambda x, y: x + y, measurement_cpu_usage_list) / len(measurement_cpu_usage_list))
    print "PPS: " + str(measurement_pps)
    print "CPU: " + str(measurement_cpu)
    print ""
    # Appends the averages of a single experiment to lists
    final_pkt_rate_list.append(measurement_pps)
    final_cpu_usage_list.append(measurement_cpu)
    # Calculate the average of all the experiments
    if len(final_pkt_rate_list) == 10:
        print ""
        print "============== FINAL RESULTS =============="
        print "AVERAGE PPS: " + str(round(reduce(lambda x, y: x + y, final_pkt_rate_list) / len(final_pkt_rate_list)))
        print "AVERAGE CPU USAGE: " + str(round(reduce(lambda x, y: x + y, final_cpu_usage_list) / len(final_cpu_usage_list)))
    return

def measure_pkt_per_second(pkt, number_of_packets, pps):
    """ Calculates how many packets per second arrive at the host and the cpu usage, finally it appends those values to a list"""
    if P4RLNC in pkt:
            global packets_received
            global measurement_cpu_usage_list
            global measurement_pkt_rate_list
            global timestamp_first_packet
            timestamp_current_last_packet = 0
            # Starts the timer as soons as it receives the first packet
            if packets_received == 0:
                timestamp_first_packet = time.time()
                # Launches a thread that will show the results when all of packets arrive
                t = threading.Thread(target=show_results, args=(number_of_packets, pps,))
                t.daemon = True
                t.start()
            packets_received += 1
            # Notes down the time that each packet arrives
            timestamp_current_last_packet = time.time()
            measurement_cpu_usage_list.append(psutil.cpu_percent())
            # Calculates the rate of packets per second everytime a packet arrives and appends that value to a list to later calculate the average
            measurement_pkt_rate_list.append(packets_received/float((timestamp_current_last_packet-timestamp_first_packet)))

def main():
    global coefficient_matrix_s1
    global pps
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = ifaces[0]
    gen_size, number_of_symbols, field_size, number_of_packets, pps_parser = parser.get_decoder_args()
    pps = pps_parser
    set_finite_field(field_size)
    coefficient_matrix_s1 = build_FF_matrix(gen_size)
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: measure_pkt_per_second(x, number_of_packets, pps))


if __name__ == '__main__':
    main()
