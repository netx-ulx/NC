#!/usr/bin/env python

# Two outputs:
# - P4 code
# - config.txt file

from argparse import ArgumentParser
from generator_scripts import egress_generator
from generator_scripts import ingress_generator
from generator_scripts import generate_commands
from generator_scripts import constants_generator
from lib import parser

def generate_p4_code(gen_size, number_of_symbols, lin_comb, mul, field_size, c_flag):
    """ Generates the P4 code, specifically the ingress and egress pipeline. Also generates the commands.txt file """
    ingress_generator.generateIngress(gen_size,number_of_symbols)
    egress_generator.generateEgress(gen_size,number_of_symbols, mul, field_size)
    generate_commands.generateCommands(lin_comb, 2, field_size, mul, c_flag)
    constants_generator.generateConstants(field_size)

def generate_config_file(mul, type, gen_size, number_of_symbols, number_of_packets, field_size, pps):
    """ Generates a config file to be used by the sender and the decoder applications """
    f = open("config.txt", "w+")
    f.write("-m\n")
    f.write(str(mul)+"\n")
    f.write("-t\n")
    f.write(str(type)+"\n")
    f.write("-g\n")
    f.write(str(gen_size)+"\n")
    f.write("-s\n")
    f.write(str(number_of_symbols)+"\n")
    f.write("-p\n")
    f.write(str(number_of_packets)+"\n")
    f.write("-f\n")
    f.write(str(field_size)+"\n")
    f.write("-pps\n")
    f.write(str(pps)+"\n")

def main():
    type, gen_size, number_of_symbols, number_of_packets, lin_comb, mul, field_size, c_flag, pps = parser.parse_args()
    generate_p4_code(gen_size, number_of_symbols, lin_comb, mul, field_size, c_flag)
    generate_config_file(mul, type, gen_size, number_of_symbols, number_of_packets, field_size, pps)


main()
