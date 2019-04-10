#!/usr/bin/env python
import os.path
from code_replicator import *

REPLICATE_NUMBER_OF_SYMBOLS_CHAR = "##"
REPLICATE_GEN_SIZE_CHAR = "$"


def generateIngress(gen_size, number_of_symbols):
    f = open("includes/ingress.p4", "w+")
    t = open("p4_templates/ingress_template.p4", "r")
    for line in t:
        if REPLICATE_NUMBER_OF_SYMBOLS_CHAR in line:
            replicate_line_of_code(number_of_symbols,f, line, REPLICATE_NUMBER_OF_SYMBOLS_CHAR)
        elif REPLICATE_GEN_SIZE_CHAR in line:
            replicate_line_of_code(number_of_symbols*gen_size,f, line, REPLICATE_GEN_SIZE_CHAR)
        else:
            f.write(line)
