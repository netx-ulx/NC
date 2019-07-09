PARAMETER_SEPARATOR = ", "
FUNCTION_END = ") {"
CALL_FUNCTION_END = ");"
XOR_CHAR = " ^ "
NUMBER_PLACEHOLDER = "N"
FIELD_PLACEHOLDER = "FIELD"


def replicate_line_of_code(n, f, line, char):
    """ Replicates a single line of code """
    for i in range(0, n):
        tmpline = line.replace(char, "")
        newline = tmpline.replace(NUMBER_PLACEHOLDER, str(i), 2)
        f.write(newline)

def replicate_parameters(n, f, line, char):
    """ Replicates the parameters of a function. For example foo(xN) {}, here xN will be replicated N times """
    action_name = line.split(char)[0]
    param = line.split(char)[1].split(char)[0]
    string = []
    string.append(action_name)
    for i in range(0, n):
        newString = param.replace(NUMBER_PLACEHOLDER, str(i), 2)
        string.append(newString)
        if i < n - 1:
            string.append(PARAMETER_SEPARATOR)
        elif i == n - 1:
            string.append(FUNCTION_END)
    f.write("".join(string))
    f.write("\n")

def replicate_operators(n, f, line, char):
    """ Replicates the parameters give to a function call.  For example foo(xN);, here xN will be replicated N times """
    counter = line.count("action")
    constant = line.split(char)[0]
    param = line.split(char)[1].split(char)[0]
    string = []
    string.append(constant)
    for i in range(0, n):
        newString = param.replace(NUMBER_PLACEHOLDER, str(i))
        string.append(newString)
        if i < n - 1:
            if counter == 1:
                string.append(PARAMETER_SEPARATOR)
            else:
                string.append(XOR_CHAR)
        elif i == n - 1:
            string.append(CALL_FUNCTION_END)
    f.write("".join(string))
    f.write("\n")


def replicate_block(n, f, t, char, field):
    """ Replicates a block of code. Has a special case for the FIELD marker """
    aline = t.readline()
    oldblock = []
    newblock = []
    while char not in aline:
        oldblock.append(aline)
        aline = t.readline()
    for i in range(0, n):
        for b in oldblock:
            if FIELD_PLACEHOLDER in b and NUMBER_PLACEHOLDER in b:
                newB = b.replace(FIELD_PLACEHOLDER, str(field-1))
                newB2 = newB.replace(NUMBER_PLACEHOLDER, str(i))
                newblock.append(newB2)
            elif FIELD_PLACEHOLDER in b:
                newB = b.replace(FIELD_PLACEHOLDER, str(field-1))
                newblock.append(newB)
            elif NUMBER_PLACEHOLDER in b:
                newB = b.replace(NUMBER_PLACEHOLDER, str(i))
                newblock.append(newB)
            else:
                newblock.append(b)
        newblock.append("\n")
    f.write("".join(newblock))

def replicate_code_symbol(gen_size, number_of_symbols, f, t, char, char2, field_size):
    """ Replicates the symbol coding block N times. Since its a bit more specific, the replicate_block function could not be used """
    aline = t.readline()
    oldblock = []
    newblock = []
    while char not in aline:
        oldblock.append(aline)
        aline = t.readline()
    coeff_counter = 0
    for s in range(0, number_of_symbols):
        for i in range(0, gen_size):
            for b in oldblock:
                if NUMBER_PLACEHOLDER in b:
                    newB = b.replace(NUMBER_PLACEHOLDER, str(i))
                    newB2 = newB.replace("M", str(coeff_counter))
                    newblock.append(newB2)
                elif "FIELD" in b:
                    newB = b.replace("FIELD", str((2**field_size)-1))
                    newblock.append(newB)
                else:
                    newblock.append(b)
            newblock.append("\n")
            coeff_counter += 1
        f.write("".join(newblock))
        newblock = []
        f.write("                    hdr.symbols["+str(s)+"].symbol = lin_comb;\n")
        f.write("                    lin_comb = 0;\n")

def replicate_code_coeff(gen_size, number_of_symbols, f, t, char, char2, field_size):
    """ Replicates the coefficient coding block N times. Since its a bit more specific, the replicate_block function could not be used """
    aline = t.readline()
    oldblock = []
    newblock = []
    while char not in aline:
        oldblock.append(aline)
        aline = t.readline()
    coeff_counter = 0
    rand_counter = 0;
    coeff_header = 0;
    for p in range(0, number_of_symbols):
        for s in range(0, gen_size):
            for i in range(0, gen_size):
                for b in oldblock:
                    if NUMBER_PLACEHOLDER in b:
                        newB = b.replace("M", str(coeff_counter+(i*gen_size)))
                        newB2 = newB.replace(NUMBER_PLACEHOLDER, str(i+(rand_counter*gen_size)))
                        newblock.append(newB2)
                    elif "FIELD" in b:
                        newB = b.replace("FIELD", str((2**field_size)-1))
                        newblock.append(newB)
                    else:
                        newblock.append(b)
            newblock.append("\n")
            f.write("".join(newblock))
            newblock = []
            f.write("                        hdr.coefficients["+str(coeff_header)+"].coef = lin_comb;\n")
            f.write("                        lin_comb = 0;\n")
            coeff_header+=1
            coeff_counter +=1
        rand_counter+=1
        coeff_counter = 0

def replicate_code_symbol_alg(gen_size, number_of_symbols, f, t, char, char2):
    """ Replicates the symbol coding block N times. Since its a bit more specific, the replicate_block function could not be used """
    aline = t.readline()
    oldblock = []
    newblock = []
    while char not in aline:
        oldblock.append(aline)
        aline = t.readline()
    m = 0
    for i in range(0, number_of_symbols):
        for b in oldblock:
            if char2 in b:
                constant = b.split(char2)[0]
                param = b.split(char2)[1].split(char2)[0]
                string = []
                string.append(constant)
                for j in range(0, gen_size):
                    newString = param.replace(NUMBER_PLACEHOLDER, str(j))
                    newString2 = newString.replace("M", str(m))
                    m+=1
                    string.append(newString2)
                    if j < gen_size - 1:
                        string.append(PARAMETER_SEPARATOR)
                    elif j == gen_size - 1:
                        string.append(");")
                string.append("\n")
                newblock.append("".join(string))
            elif NUMBER_PLACEHOLDER in b:
                newB = b.replace(NUMBER_PLACEHOLDER, str(i))
                newblock.append(newB)
            else:
                newblock.append(b)
        newblock.append("\n")
    f.write("".join(newblock))

def replicate_code_coeff_alg(gen_size, number_of_symbols, f, t, char, char2):
    """ Replicates the coefficient coding block N times. Since its a bit more specific, the replicate_block function could not be used """
    aline = t.readline()
    oldblock = []
    newblock = []
    while char not in aline:
        oldblock.append(aline)
        aline = t.readline()
    z = 0
    for w in range(0, number_of_symbols):
        m = gen_size*w
        for i in range(0, gen_size):
            for b in oldblock:
                if char2 in b:
                    constant = b.split(char2)[0]
                    param = b.split(char2)[1].split(char2)[0]
                    string = []
                    string.append(constant)
                    for j in range(0, gen_size):
                        newString = param.replace(NUMBER_PLACEHOLDER, str(j))
                        newString2 = newString.replace("M", str(m))
                        m +=1
                        string.append(newString2)
                        if j < gen_size - 1:
                            string.append(PARAMETER_SEPARATOR)
                        elif j == gen_size - 1:
                            string.append(");")
                    m = gen_size*w
                    string.append("\n")
                    newblock.append("".join(string))
                elif "P" in b:
                    newB = b.replace("P", str(i))
                    newblock.append(newB)
                elif NUMBER_PLACEHOLDER in b:
                    newB = b.replace(NUMBER_PLACEHOLDER, str(z))
                    newblock.append(newB)
                else:
                    newblock.append(b)
            newblock.append("\n")
            z +=1
    f.write("".join(newblock))

def replicate_constants(f, t, field_size, char):
    """ Changes the constants based on the chosen field size """
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
                newB = b.replace("IRRED_PLACEHOLDER", str(27))
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
