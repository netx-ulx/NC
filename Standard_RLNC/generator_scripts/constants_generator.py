#!/usr/bin/env python
import os.path
from code_replicator import replicate_constants

FIELD_SIZE_BLOCK_MARKER = "@"

def generateConstants(field_size):
    f = open("includes/constants.p4", "w+")
    t = open("p4_templates/constants_template.p4", "r")
    while True:
        line = t.readline()
        if FIELD_SIZE_BLOCK_MARKER in line:
            replicate_constants(f, t, field_size, FIELD_SIZE_BLOCK_MARKER)
        elif not line:
            break
        else:
            f.write(line)
