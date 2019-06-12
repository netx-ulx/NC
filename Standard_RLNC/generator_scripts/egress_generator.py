#!/usr/bin/env python
import re
import sys
from code_replicator import *

REPLICATE_NUMBER_OF_SYMBOLS_CHAR = "##"
REPLICATE_GEN_SIZE_CHAR = "!"
REPLICATE_GEN_SIZE_TIMES_N_SYMBOLS_CHAR = "$"
REPLICATE_CODE_SYMBOL ="CODE_SYMBOL"
REPLICATE_CODE_COEFF = "CODE_COEFF"
MULTIPLE_PARAMETERS_CHAR = "%%"
MULTIPLE_OPERATORS_CHAR = "??"
REPEAT_BLOCK_CHAR = "@"
REPLICATE_FIELD_SIZE = "FIELD"
HEADER_STACK_PLACEHOLDER = "NNNN"
MULTIPLICATION_PLACEHOLDER = "MULTIPLICATION_PLACEHOLDER"


def write_code(f, t, line, gen_size, number_of_symbols, mult, field_size):
    if REPLICATE_NUMBER_OF_SYMBOLS_CHAR in line:
        replicate_line_of_code(number_of_symbols, f, line, REPLICATE_NUMBER_OF_SYMBOLS_CHAR)
    elif REPLICATE_FIELD_SIZE in line:
        replicate_line_of_code(field_size, f, line, REPLICATE_FIELD_SIZE)
    elif REPLICATE_GEN_SIZE_CHAR in line:
        replicate_line_of_code(gen_size, f, line, REPLICATE_GEN_SIZE_CHAR)
    elif REPLICATE_GEN_SIZE_TIMES_N_SYMBOLS_CHAR in line:
        replicate_line_of_code(number_of_symbols*gen_size, f, line, REPLICATE_GEN_SIZE_TIMES_N_SYMBOLS_CHAR)
    elif MULTIPLE_PARAMETERS_CHAR in line:
        replicate_parameters(gen_size, f, line, MULTIPLE_PARAMETERS_CHAR)
    elif MULTIPLE_OPERATORS_CHAR in line:
        replicate_operators(gen_size, f, line, MULTIPLE_OPERATORS_CHAR)
    elif REPEAT_BLOCK_CHAR in line:
        replicate_block(gen_size, f, t, REPEAT_BLOCK_CHAR, field_size)
    elif REPLICATE_CODE_SYMBOL in line:
        replicate_code_symbol(gen_size, number_of_symbols, f, t, REPLICATE_CODE_SYMBOL, MULTIPLE_OPERATORS_CHAR)
    elif REPLICATE_CODE_COEFF in line:
        replicate_code_coeff(gen_size, number_of_symbols, f, t, REPLICATE_CODE_COEFF, MULTIPLE_OPERATORS_CHAR)
    elif HEADER_STACK_PLACEHOLDER in line:
        newline = line.replace(HEADER_STACK_PLACEHOLDER, str(gen_size*number_of_symbols))
        f.write(newline)
    else:
        f.write(line)

def generateEgress(gen_size, number_of_symbols, mult, field_size):
        f = open("includes/egress.p4", "w+")
        t = open("p4_templates/egress_template.p4", "r")
        line = t.readline()
        while True:
            line = t.readline()
            if not line:
                f.close();
                break
            else:
                if MULTIPLICATION_PLACEHOLDER in line:
                    if mult == 1:
                        t1 = open("p4_templates/table_template.p4", "r")
                    elif mult == 2:
                        t1 = open("p4_templates/mult_template.p4", "r")
                    while True:
                        line = t1.readline()
                        if not line:
                            break
                        else:
                            write_code(f, t1, line, gen_size, number_of_symbols, mult, field_size)
                write_code(f, t, line, gen_size, number_of_symbols, mult, field_size)
