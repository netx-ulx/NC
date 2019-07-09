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
final_pkt_rate_list = []
final_cpu_usage_list = []
final_packets_received_list = []
measurements = 1
total_measurements = 10
start = 0

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

def select_random_packets_to_drop(gen_size, n):
    """ Selects random packets to drop """
    return random.sample(range(gen_size), n)

def std_dev(xs):
    mean = sum(xs) / len(xs)   # mean
    var  = sum(pow(x-mean,2) for x in xs) / len(xs)  # variance
    std  = math.sqrt(var)  # standard deviation

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
    print b
    solve1 = coefficient_matrix_s1.Solve(b)
    original_symbols_matrix = genericmatrix.GenericMatrix((gen_size,1),add=XOR,mul=AND,sub=XOR,div=DIV)
    for i in range(0, gen_size):
        original_symbols_matrix.SetRow(i, [solve1[i]])
    print original_symbols_matrix
    write_symbols_to_file(original_symbols_matrix)

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

def measure_packet_per_second(number_of_packets, pps):
    """ Calculates the average of the packets per second and cpu usage. Then presents the final results when all measurements have been completed """
    global packets_received
    global final_pkt_rate_list
    global final_cpu_usage_list
    global measurements
    global start
    measurement_pkt_rate_list = []
    measurement_cpu_usage_list = []
    i = 0
    print "INITIATING TEST " + str(measurements) + " of 10"
    while(i < total_measurements):
        time.sleep(1)
        end = time.time()
        packets_received_per_second = packets_received/(end-start)
        cpu_usage = psutil.cpu_percent()
        print "PPS: " + str(packets_received_per_second)
        print "CPU: " + str(cpu_usage)
        print ""
        measurement_pkt_rate_list.append(packets_received/(end-start))
        measurement_cpu_usage_list.append(cpu_usage)
        i += 1
    avg_pps = round(reduce(lambda x, y: x + y, measurement_pkt_rate_list) / len(measurement_pkt_rate_list))
    avg_cpu = round(reduce(lambda x, y: x + y, measurement_cpu_usage_list) / len(measurement_cpu_usage_list))
    print ""
    print "============== TEST " + str(measurements) + " OF 10 RESULTS =============="
    print "AVERAGE PPS: " + str(avg_pps)
    print "AVERAGE CPU USAGE: " + str(avg_cpu)
    # Sleep the time that the experiment should take plus 5 seconds to compensate for slower packet processing
    time.sleep((number_of_packets/pps) + 5)
    print "PACKETS RECEIVED: " + str(packets_received)
    print ""
    measurements += 1
    final_packets_received_list.append(packets_received)
    final_pkt_rate_list.append(avg_pps)
    final_cpu_usage_list.append(avg_cpu)
    packets_received = 0
    sys.exit(1)

def avg_of_all_tests():
    global final_pkt_rate_list
    global final_cpu_usage_list
    global measurements
    global final_packets_received_list
    while(measurements <= total_measurements):
        pass
    avg_pps_all_tests = round(reduce(lambda x, y: x + y, final_pkt_rate_list) / len(final_pkt_rate_list))
    avg_cpu_all_tests = round(reduce(lambda x, y: x + y, final_cpu_usage_list) / len(final_cpu_usage_list))
    avg_packets_received = round(reduce(lambda x, y: x + y, final_packets_received_list) / len(final_packets_received_list))
    print ""
    print "============== FINAL RESULTS OF ALL TESTS =============="
    print "AVERAGE PPS: " + str(avg_pps_all_tests)
    print "AVERAGE CPU USAGE: " + str(avg_cpu_all_tests)
    print "AVERAGE PACKETS RECEIVED: " + str(avg_packets_received)
    print "STANDARD DEVIATION: " + str(std_dev(final_pkt_rate_list))
    print ""

def handle_pkt_2(pkt, number_of_packets, pps):
    """ Handles packets and launches threads to measure the rate of packets received and how many it has received"""
    global packets_received
    global start
    if P4RLNC in pkt:
            # Starts the timer as soons as it receives the first packet
            if packets_received == 0:
                start = time.time()
                pkt.show2()
                # Launches a thread that will show the results when all of packets arrive
                t = threading.Thread(target=measure_packet_per_second, args=(number_of_packets, pps,))
                #t1 = threading.Thread(target=measure_packets_received, args=(number_of_packets, pps,))
                t.daemon = True
                #t1.daemon = True
                t.start()
                #t1.start()
            packets_received += 1

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
    t2 = threading.Thread(target=avg_of_all_tests)
    t2.daemon = True
    t2.start()
    sniff(iface = iface,
          prn = lambda x: handle_pkt_2(x, number_of_packets, pps))


if __name__ == '__main__':
    main()
