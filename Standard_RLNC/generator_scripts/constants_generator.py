#!/usr/bin/env python
import os.path

FIELD_SIZE_BLOCK_MARKER = "@"

def replicate_block(f, t, field_size, char):
    aline = t.readline()
    oldblock = []
    newblock = []
    while char not in aline:
        oldblock.append(aline)
        aline = t.readline()
    for b in oldblock:
        if field_size == 8:
            if "BITS_PLACEHOLDER" in b:
                newB = b.replace("BITS_PLACEHOLDER", str(256))
                newblock.append(newB)
            elif "BYTES_PLACEHOLDER" in b:
                newB = b.replace("BYTES_PLACEHOLDER", str(8))
                newblock.append(newB)
            elif "MAX_VALUE_PLACEHOLDER" in b:
                newB = b.replace("MAX_VALUE_PLACEHOLDER", str(255))
                newblock.append(newB)
            elif "IRRED_PLACEHOLDER" in b:
                newB = b.replace("IRRED_PLACEHOLDER", str(0x11b))
                newblock.append(newB)
            else:
                newblock.append(b)
        elif field_size == 16:
            if "BITS_PLACEHOLDER" in b:
                newB = b.replace("BITS_PLACEHOLDER", str(65536))
                newblock.append(newB)
            elif "BYTES_PLACEHOLDER" in b:
                newB = b.replace("BYTES_PLACEHOLDER", str(16))
                newblock.append(newB)
            elif "MAX_VALUE_PLACEHOLDER" in b:
                newB = b.replace("MAX_VALUE_PLACEHOLDER", str(65535))
                newblock.append(newB)
            elif "IRRED_PLACEHOLDER" in b:
                newB = b.replace("IRRED_PLACEHOLDER", str(69643))
                newblock.append(newB)
            else:
                newblock.append(b)
    newblock.append("\n")
    f.write("".join(newblock))

def generateConstants(field_size):
    f = open("includes/constants.p4", "w+")
    t = open("p4_templates/constants_template.p4", "r")
    while True:
        line = t.readline()
        if FIELD_SIZE_BLOCK_MARKER in line:
            replicate_block(f, t, field_size, FIELD_SIZE_BLOCK_MARKER)
        elif not line:
            break
        else:
            f.write(line)
