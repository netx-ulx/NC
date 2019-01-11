#!/usr/bin/env python
import argparse
import sys
import socket
import random
import struct

from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, StrFixedLenField, XByteField, IntField, ShortField
from scapy.all import bind_layers
from myCoding_header import P4code



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

def main():


    iface = get_if()[0]
    iface1 = get_if()[1]


    still_sending = True;
    generations_sizes_array = []

    number_of_packets_to_be_sent = 0
    number_generations = int(raw_input("Enter how many generations to send:\n"))
    generations_packets_sent = [0] * number_generations
    generations = []
    print generations_packets_sent
    i = 0;
    while i != number_generations:
        print "Enter the size of generation number " + str(i)
        size_of_the_generation = int(raw_input())
        number_of_packets_to_be_sent += size_of_the_generation
        generations_sizes_array.append(size_of_the_generation)
        generations.append(i)
        i += 1

    number_of_packets_sent = 0
    while number_of_packets_sent != number_of_packets_to_be_sent:

        print "Enter the generation of the packet to be sent on port 0:\n"
        print "Available generations:" + str(generations)
        gen_num1 = int(raw_input())
        if generations_packets_sent[gen_num1] == generations_sizes_array[gen_num1]:
            print "ERROR: That generation was fully forwarded already"
            return
        gen_size1 = generations_sizes_array[gen_num1]
        payload1 = raw_input('Enter the payload of the packet to be sent on port 0:\n')

        print "Enter the generation of the packet to be sent on port 1:"
        print "Available generations:" + str(generations)
        gen_num2 = int(raw_input())
        if generations_packets_sent[gen_num2] == generations_sizes_array[gen_num2]:
            print "ERROR: That generation was fully forwarded already"
            return
        gen_size2 = generations_sizes_array[gen_num1]
        payload2 = raw_input('Enter the payload of the packet to be sent on port 1:\n')

        print "sending on interface {}".format(iface)
        pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
        pkt = pkt / P4code(Generation=gen_num1, Generation_Size=gen_size1) / payload1
        sendp(pkt, iface=iface, verbose=False)
        pkt.show2();

        print "sending on interface {}".format(iface1)
        pkt1 =  Ether(src=get_if_hwaddr(iface1), dst='ff:ff:ff:ff:ff:ff')
        pkt1 = pkt1 / P4code(Generation=gen_num2, Generation_Size=gen_size2) / payload2
        sendp(pkt1, iface=iface1, verbose=False)
        pkt1.show2();

        generations_packets_sent[gen_num1] += 1
        generations_packets_sent[gen_num2] += 1
        number_of_packets_sent += 2
        if generations_packets_sent[gen_num1] == generations_sizes_array[gen_num1]:
            if gen_num1 in generations:
                generations.remove(gen_num1)
            print "Generation number " + str(gen_num1) + " was fully forwarded"
        if generations_packets_sent[gen_num2] == generations_sizes_array[gen_num2]:
            if gen_num2 in generations:
                generations.remove(gen_num2)
            print "Generation number " + str(gen_num2) + " was fully forwarded"
        print "Number of packets sent: " + str(number_of_packets_sent)
        print "Number of packets left to sent: " + str(number_of_packets_to_be_sent - number_of_packets_sent)

    print "All packets were sent. Terminating..."











if __name__ == '__main__':
    main()
