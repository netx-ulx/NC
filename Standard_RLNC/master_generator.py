#!/usr/bin/env python
from argparse import ArgumentParser
from generator_scripts import egress_generator
from generator_scripts import ingress_generator
from generator_scripts import generate_commands

parser = ArgumentParser()
parser.add_argument('--gen_size', action="store", dest='gen_size', default=4)
parser.add_argument('--number_of_symbols', action="store", dest='number_of_symbols', default=2)
args = parser.parse_args()
number_of_symbols = int(args.number_of_symbols)
gen_size = int(args.gen_size)
ingress_generator.generateIngress(gen_size,number_of_symbols)
egress_generator.generateEgress(gen_size,number_of_symbols)
generate_commands.generateCommands(gen_size)
