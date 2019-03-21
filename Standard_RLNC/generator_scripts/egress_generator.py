#!/usr/bin/env python
def generateEgress(gen_size, number_of_symbols):
    f = open("/home/p4/Desktop/tutorials/exercises/Standard_RLNC_V3/includes/egress.p4", "w+")
    f.write('''
    /*************************************************************************
    ****************  E G R E S S   P R O C E S S I N G   *******************
    *************************************************************************/

    // The Egress is where the coding happens. N cloned packets enter the egress as a result
    // of the multicast mechanism being used. All of these will be a different linear combination
    // due to different random coefficients being generated.
    control MyEgress(inout headers hdr,
                     inout metadata meta,
                     inout standard_metadata_t standard_metadata) {

    	// Variable for results of the arithmetic operations
        // CONFIGURABLE: changes depending on the generation size, may also depend on the number of symbols we are coding together if we are using something elese other than the STANDARD RLNC scheme
        // number of mult_results = hdr.rlnc_out.gen_size\n''')
    for i in range(0,gen_size):
        f.write("        bit<GF_BYTES> mult_result_"+str(i)+" = 0;\n")
    f.write('''
        bit<GF_BYTES> lin_comb = 0;\n

        // Variables to hold the values of the symbols stored in the symbols registers
        // CONFIGURABLE: changes depending on the number of symbols\n''')
    for i in range(0, gen_size):
        f.write("        bit<GF_BYTES> s"+str(i)+" = 0;\n")
    f.write('''
        // Variables to hold the values of the coefficients stored in the coeff register
        // CONFIGURABLE: changes depending on the generation size, number of coefs = hdr.rlnc_out.gen_size\n''')
    for i in range(0, gen_size):
        f.write("        bit<GF_BYTES> coef_"+str(i)+" = 0;\n")
    f.write('''
        // The random generated coefficients
        // CONFIGURABLE: changes depending on the generation size,number of rand_nums = hdr.rlnc_out.gen_size\n''')
    for i in range(0, gen_size):
        f.write("        bit<GF_BYTES> rand_num"+str(i)+" = 0;\n")
    f.write('''
        bit<8> numb_of_symbols = (bit<8>) hdr.rlnc_in.symbols;
        bit<32> gen_size = (bit<32>) hdr.rlnc_out.gen_size;

        // The LOG and ANTILOG tables
        register<bit<GF_BYTES>>(GF_BITS)          GF256_log;
        register<bit<GF_BYTES>>(509)              GF256_invlog;

        // Frees the space reserved by the current generation
        // TODO Currently unused
        action action_free_buffer() {
            buf_coeffs.write(0, 0);
            buf_symbols.write(0, 0);
            symbol_index_per_generation.write((bit<32>)hdr.rlnc_out.gen_id, 0);
        }
        // Loads gen_size symbols to metadata to use in linear combinations
        // CONFIGURABLE: changes depending on the generation size, number of reads = hdr.rlnc_out.gen_size
        action action_load_symbols(bit<8> idx) {\n''')
    for i in range(0, gen_size):
        f.write("       buf_symbols.read(s"+str(i)+", (bit<32>)idx + " + str(i) + ");\n")
    f.write('''
        }
        //Loads gen_size coefficients to variables to use in the linear combinations
        // CONFIGURABLE: changes depending on the generation size and the number of coded symbols we have in a packet so, number of reads = hdr.rlnc_out.gen_size*hdr.rlnc_in.symbols
        action action_load_coeffs(bit<8> idx) {\n''')
    for  i in range(0, gen_size):
        f.write("       buf_coeffs.read(coef_"+str(i) + " , (bit<32>) idx + (gen_size * "+str(i)+"));\n")
    f.write('''
        }

        // This action depends on the number of coded symbols we want to generate based
        // on uncoded ones, we can have one coded symbol or more in one packet
        action action_remove_symbols() {
            hdr.rlnc_in.symbols = hdr.rlnc_in.symbols - 1;
            hdr.symbols[1].setInvalid();
        }

        // GF Addition Arithmetic Operation
        action action_GF_add(''')
    for i in range(0, gen_size):
        if i < gen_size - 1:
            f.write("bit<GF_BYTES> x"+str(i)+", ")
        else:
            f.write("bit<GF_BYTES> x"+str(i))
    f.write(''') {
            lin_comb = (''')
    for i in range(0, gen_size):
        if i < gen_size - 1:
            f.write("x"+str(i)+" ^ ")
        else:
            f.write("x"+str(i))
    f.write(''');
        }

        // GF Multiplication Arithmetic Operation
        // multiplication_result = antilog[log[a] + log[b]]
        // r = x1*y1 + x2*y2 + x3*y3 + x4*y4
        // CONFIGURABLE: parameters and multiplications increase with the generation size
        action action_GF_mult(''')
    for i in range(0, gen_size):
        if i < gen_size - 1:
            f.write("bit<GF_BYTES> x"+str(i)+", bit<GF_BYTES> y"+str(i)+", ")
        else:
            f.write("bit<GF_BYTES> x"+str(i)+", bit<GF_BYTES> y"+str(i))
    f.write(''') {
            bit<8> tmp_log_a = 0;
            bit<8> tmp_log_b = 0;
            bit<32> result = 0;
            bit<32> log_a = 0;
            bit<32> log_b = 0;\n\n''')

    for i in range(0, gen_size):
        f.write("       GF256_log.read(tmp_log_a, (bit<32>) x"+str(i)+");\n")
        f.write("       GF256_log.read(tmp_log_b, (bit<32>) y"+str(i)+");\n")
        f.write("       log_a = (bit<32>) tmp_log_a;\n")
        f.write("       log_b = (bit<32>) tmp_log_b;\n")
        f.write("       result = (log_a + log_b);\n")
        f.write("       GF256_invlog.read(mult_result_"+str(i)+", result);\n")
        f.write("       if(x"+str(i)+" == 0 || y"+str(i)+" == 0) {\n")
        f.write("           mult_result_"+str(i)+" = 0;\n")
        f.write("       }\n")
    f.write('''
        }

        // The arithmetic operations needed for network coding are
        // multiplication and addition. First we multiply each value
        // by each random coefficient generated and then we add every
        // multiplication product, finally obtating the final result
        // CONFIGURABLE: parameters increase with the generation size
        action action_GF_arithmetic(''')
    for i in range(0, gen_size):
        if i < gen_size - 1:
            f.write("bit<GF_BYTES> x"+str(i)+", bit<GF_BYTES> y"+str(i)+", ")
        else:
            f.write("bit<GF_BYTES> x"+str(i)+", bit<GF_BYTES> y"+str(i))
    f.write(''') {
            action_GF_mult(''')
    for i in range(0, gen_size):
        if i < gen_size - 1:
            f.write("x"+str(i)+", y"+str(i)+", ")
        else:
            f.write("x"+str(i)+", y"+str(i))
    f.write(''');
            action_GF_add(''')
    for i in range(0, gen_size):
        if i < gen_size - 1:
            f.write("mult_result_"+str(i)+", ")
        else:
            f.write("mult_result_"+str(i))
    f.write(''');
        }

        // Generates a number of coefficients that is equal to the generation size
        // CONFIGURABLE: the number of random generated coefficients increases with the generation size
        action action_generate_random_coefficients() {
            // Initializing some variables to generate the random coefficients
            // with the minimum value being 0 and the maximum value being 2^n - 1
            bit<GF_BYTES> low = 0;
            bit<GF_BYTES> high = GF_MAX_VALUE;
            // generating a number of random coefficients equal to the generation size\n''')
    for i in range(0, gen_size):
        f.write("        random(rand_num"+str(i)+ ", low, high);\n")
    f.write('''
        }

        // Perfoms a linear combination using all the symbols stored in the register
        // and generates a coded symbol as the result
        // CONFIGURABLE: can change depending if we want to have more than one coded symbol per packet
        action action_code_symbol() {
            // Loading symbols in metadata
            // The number of symbols that need to be loaded is
            // equal to GEN_SIZE. Meaning loading all the symbols from the following positions:
            action_load_symbols(meta.clone_metadata.starting_gen_symbol_index);

            // Coding and copying the symbols
            action_GF_arithmetic(''')
    for i in range(0, gen_size):
        if i < gen_size - 1:
            f.write("s"+str(i)+", rand_num"+str(i)+", ")
        else:
            f.write("s"+str(i)+", rand_num"+str(i))
    f.write(''');
            hdr.symbols[0].symbol = lin_comb;
        }

        // Does linear combinations on the coefficients
        // Provides the ability to recode
        // CONFIGURABLE: depends on the generation size
        action action_code_coefficient() {\n''')
    for i in range(0, gen_size):
        f.write("       action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + " + str(i)+");\n")
        f.write("       action_GF_arithmetic(")
        for j in range(0, gen_size):
            if j < gen_size - 1:
                f.write("coef_"+str(j)+", rand_num"+str(j)+", ")
            else:
                f.write("coef_"+str(j)+", rand_num"+str(j)+");")
        f.write("\n")
        f.write("       hdr.coefficients["+str(i)+"].coef = lin_comb;\n\n")
    f.write('''
        }

        // Adds a coefficient vector to the header of a previously systematic symbol
        // CONFIGURABLE: depends on the generation size and on the number of coded symbols we want to have per packet
        action action_add_coeff_header() {\n''')
    f.write("        hdr.coefficients.push_front("+str(gen_size)+");\n")
    for i in range(0,gen_size):
        f.write("        hdr.coefficients["+str(i)+"].setValid();\n")
    for i in range(0,gen_size):
        f.write("        hdr.coefficients["+str(i)+"].coef = rand_num"+str(i)+";\n")
    f.write('''          hdr.rlnc_in.encoderRank = (bit<8>) gen_size;
        }
        // Changes the type of the packet to a value of 3, which indicates that
        // the packet is either coded or recoded
        action action_systematic_to_coded() {
        	hdr.rlnc_in.type = TYPE_CODED_OR_RECODED;
        }

        // Debug table, does nothing
        table table_debug {
            key = {
                meta.clone_metadata.starting_gen_symbol_index   : exact;
                s0                           : exact;
                s1                           : exact;
                s2                           : exact;
                s3                           : exact;
                coef_0                                          : exact;
                coef_1                                          : exact;
                coef_2                                          : exact;
                coef_3                                          : exact;
                hdr.symbols[0].symbol                           : exact;
                hdr.symbols[1].symbol                           : exact;
            }
            actions = {
                NoAction;
            }
        }

        apply {
            if(hdr.rlnc_in.isValid()) {
                if(meta.clone_metadata.gen_symbol_index - meta.clone_metadata.starting_gen_symbol_index >= (bit<8>) gen_size) {
                    // Generate the random coefficients
                    action_generate_random_coefficients();
                    // Code the symbol with the generated random coefficients
                    action_code_symbol();
                    // Coding a packet
                    if(hdr.rlnc_in.type == 1) {
                        // TODO: still undecided about this, depends on how many coded symbols we want on a coded packet
                        // we can also add more coded symbols instead of removing it
                        action_remove_symbols();
                        // adding the coefficient vector to the header
                        action_add_coeff_header();
                        // Since we coded the packet we change its type to TYPE_CODED_OR_RECODED
                        action_systematic_to_coded();
                    }
                    // Recoding a packet
                    else if(hdr.rlnc_in.type == 3) {
                        // Generate the random coefficients
                        action_generate_random_coefficients();
                        // Code the symbol with the generated random coefficients
                        action_code_symbol();
                        // Update the coding vector using the generated random coefficients
                        action_code_coefficient();
                    }
                }
                table_debug.apply();
            }
        }
    }
    ''')