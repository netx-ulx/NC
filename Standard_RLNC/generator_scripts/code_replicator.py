def replicate_line_of_code(n, f, line, char):
    """ Replicates a single line of code """
    for i in range(0, n):
        tmpline = line.replace(char, "")
        newline = tmpline.replace("N", str(i), 2)
        f.write(newline)

def replicate_parameters(n, f, line, char):
    """ Replicates the parameters of a function. For example foo(xN) {}, here xN will be replicated N times """
    action_name = line.split(char)[0]
    param = line.split(char)[1].split(char)[0]
    string = []
    string.append(action_name)
    for i in range(0, n):
        newString = param.replace("N", str(i), 2)
        string.append(newString)
        if i < n - 1:
            string.append(", ")
        elif i == n - 1:
            string.append(") {")
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
        newString = param.replace("N", str(i))
        string.append(newString)
        if i < n - 1:
            if counter == 1:
                string.append(", ")
            else:
                string.append(" ^ ")
        elif i == n - 1:
            string.append(");")
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
            if "FIELD" in b and "N" in b:
                newB = b.replace("FIELD", str(field-1))
                newB2 = newB.replace("N", str(i))
                newblock.append(newB2)
            elif "FIELD" in b:
                newB = b.replace("FIELD", str(field-1))
                newblock.append(newB)
            elif "N" in b:
                newB = b.replace("N", str(i))
                newblock.append(newB)
            else:
                newblock.append(b)
        newblock.append("\n")
    f.write("".join(newblock))

def replicate_code_symbol(gen_size, number_of_symbols, f, t, char, char2):
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
                    newString = param.replace("N", str(j))
                    newString2 = newString.replace("M", str(m))
                    m+=1
                    string.append(newString2)
                    if j < gen_size - 1:
                        string.append(", ")
                    elif j == gen_size - 1:
                        string.append(");")
                string.append("\n")
                newblock.append("".join(string))
            elif "N" in b:
                newB = b.replace("N", str(i))
                newblock.append(newB)
            else:
                newblock.append(b)
        newblock.append("\n")
    f.write("".join(newblock))

def replicate_code_coeff(gen_size, number_of_symbols, f, t, char, char2):
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
                        newString = param.replace("N", str(j))
                        newString2 = newString.replace("M", str(m))
                        m +=1
                        string.append(newString2)
                        if j < gen_size - 1:
                            string.append(", ")
                        elif j == gen_size - 1:
                            string.append(");")
                    m = gen_size*w
                    string.append("\n")
                    newblock.append("".join(string))
                elif "P" in b:
                    newB = b.replace("P", str(i))
                    newblock.append(newB)
                elif "N" in b:
                    newB = b.replace("N", str(z))
                    newblock.append(newB)
                else:
                    newblock.append(b)
            newblock.append("\n")
            z +=1
    f.write("".join(newblock))
