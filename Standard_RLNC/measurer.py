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
import csv
from operator import itemgetter
from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet
import numpy as np
import math
from myCoding_header import *
from argparse import ArgumentParser
from lib import parser

packets_received = 0
final_pkt_rate_list = []
final_cpu_usage_list = []
final_packets_received_list = []
measurements = 1
total_measurements = 10
start = 0
data = []

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

def std_dev(xs):
    mean = sum(xs) / len(xs)   # mean
    var  = sum(pow(x-mean,2) for x in xs) / len(xs)  # variance
    std  = math.sqrt(var)  # standard deviation

def save_data():
    global data
    with open("data.csv", "a") as csv_file:
        writer = csv.writer(csv_file, delimiter=',')
        writer.writerow(data)

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
    print "AVERAGE PPS: " + str(round(avg_pps))
    print "AVERAGE CPU USAGE: " + str(avg_cpu)
    print "STANDARD DEVIATION: " + str(np.std(np.array(measurement_pkt_rate_list)))
    # Sleep the time that the experiment should take plus 5 seconds to compensate for slower packet processing
    time.sleep((number_of_packets/pps) + 5)
    print "PACKETS LOST: " + str((number_of_packets*total_measurements)-packets_received)
    print ""
    measurements += 1
    final_packets_received_list.append((number_of_packets*total_measurements)-packets_received)
    final_pkt_rate_list.append(avg_pps)
    final_cpu_usage_list.append(avg_cpu)
    packets_received = 0
    sys.exit(1)

def avg_of_all_tests():
    global final_pkt_rate_list
    global final_cpu_usage_list
    global measurements
    global final_packets_received_list
    global data
    while(measurements <= total_measurements):
        pass
    avg_pps_all_tests = round(reduce(lambda x, y: x + y, final_pkt_rate_list) / len(final_pkt_rate_list))
    avg_cpu_all_tests = round(reduce(lambda x, y: x + y, final_cpu_usage_list) / len(final_cpu_usage_list))
    avg_packets_lost = round(reduce(lambda x, y: x + y, final_packets_received_list) / len(final_packets_received_list))
    std_dev = np.std(np.array(final_pkt_rate_list))
    print ""
    print "============== FINAL RESULTS OF ALL TESTS =============="
    print "AVERAGE PPS: " + str(avg_pps_all_tests)
    print "AVERAGE CPU USAGE: " + str(avg_cpu_all_tests)
    print "AVERAGE PACKETS LOST: " + str(avg_packets_lost)
    print "STANDARD DEVIATION: " + str(std_dev)
    print ""
    data.append(avg_pps_all_tests)
    data.append(avg_cpu_all_tests)
    data.append(round(std_dev,2))
    data.append(avg_packets_lost)
    save_data()

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
    global data
    ifaces = filter(lambda i: 'veth' in i, os.listdir('/sys/class/net/'))
    iface = "veth3"
    mul, gen_size, number_of_symbols, field_size, number_of_packets, pps = parser.get_receiver_args()
    data.append(mul)
    data.append(field_size)
    data.append(gen_size)
    data.append(number_of_symbols)
    sys.stdout.flush()
    t2 = threading.Thread(target=avg_of_all_tests)
    t2.daemon = True
    t2.start()
    sniff(iface = iface,
          prn = lambda x: handle_pkt_2(x, number_of_packets, pps))


if __name__ == '__main__':
    main()
