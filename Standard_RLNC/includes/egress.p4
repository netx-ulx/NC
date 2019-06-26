// of the multicast mechanism being used. All of these will be a different linear combination
// due to different random coefficients being generated.
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

        // Variable for results of the arithmetic operations
        // CONFIGURABLE: changes depending on the generation size
        bit<GF_BYTES> mult_result_0 = 0;
        bit<GF_BYTES> mult_result_1 = 0;
        bit<GF_BYTES> mult_result_2 = 0;
        bit<GF_BYTES> mult_result_3 = 0;
        bit<GF_BYTES> mult_result_4 = 0;
        bit<GF_BYTES> mult_result_5 = 0;
        bit<GF_BYTES> mult_result_6 = 0;
        bit<GF_BYTES> mult_result_7 = 0;

        bit<GF_BYTES> lin_comb = 0;


        // Variables to hold the values of the symbols stored in the symbols registers
        // CONFIGURABLE: changes depending on the generation size
        bit<GF_BYTES> s0 = 0;
        bit<GF_BYTES> s1 = 0;
        bit<GF_BYTES> s2 = 0;
        bit<GF_BYTES> s3 = 0;
        bit<GF_BYTES> s4 = 0;
        bit<GF_BYTES> s5 = 0;
        bit<GF_BYTES> s6 = 0;
        bit<GF_BYTES> s7 = 0;

        // Variables to hold the values of the coefficients stored in the coeff register
        // CONFIGURABLE: changes depending on the generation size
        bit<GF_BYTES> coef_0 = 0;
        bit<GF_BYTES> coef_1 = 0;
        bit<GF_BYTES> coef_2 = 0;
        bit<GF_BYTES> coef_3 = 0;
        bit<GF_BYTES> coef_4 = 0;
        bit<GF_BYTES> coef_5 = 0;
        bit<GF_BYTES> coef_6 = 0;
        bit<GF_BYTES> coef_7 = 0;

        // The random generated coefficients
        // CONFIGURABLE: changes depending on the generation size and the number of symbols
        bit<GF_BYTES> rand_num0 = 0;
        bit<GF_BYTES> rand_num1 = 0;
        bit<GF_BYTES> rand_num2 = 0;
        bit<GF_BYTES> rand_num3 = 0;
        bit<GF_BYTES> rand_num4 = 0;
        bit<GF_BYTES> rand_num5 = 0;
        bit<GF_BYTES> rand_num6 = 0;
        bit<GF_BYTES> rand_num7 = 0;


        bit<8> numb_of_symbols = (bit<8>) hdr.rlnc_in.symbols;
        bit<32> gen_size = (bit<32>) hdr.rlnc_out.gen_size;
        register<bit<8>>(1) packets_sent_buffer;
        bit<8> packets_sent = 0;
        counter(1, CounterType.packets_and_bytes) packet_counter_egress;

        // Frees the space reserved by the current generation
        action action_free_buffer() {
            bit<32> tmp = meta.clone_metadata.starting_gen_symbol_index;
            buf_symbols.write(tmp, 0);
            symbol_index_per_generation.write((bit<32>)hdr.rlnc_out.gen_id, 0);
            coeff_index_per_generation.write((bit<32>)hdr.rlnc_out.gen_id, 0);
            starting_symbol_index_of_generation_buffer.write((bit<32>)hdr.rlnc_out.gen_id, 0);
            starting_coeff_index_of_generation_buffer.write((bit<32>)hdr.rlnc_out.gen_id, 0);
        }
        // Loads gen_size symbols to metadata to use in linear combinations
        // CONFIGURABLE: changes depending on the generation size
        action action_load_symbols(bit<32> idx) {
            buf_symbols.read(s0, (bit<32>)idx + 0);
            buf_symbols.read(s1, (bit<32>)idx + 1);
            buf_symbols.read(s2, (bit<32>)idx + 2);
            buf_symbols.read(s3, (bit<32>)idx + 3);
        }
        //Loads gen_size coefficients to variables to use in the linear combinations
        // CONFIGURABLE: changes depending on the generation size
        action action_load_coeffs(bit<32> idx) {
            buf_coeffs.read(coef_0 , idx + (gen_size * 0));
            buf_coeffs.read(coef_1 , idx + (gen_size * 1));
            buf_coeffs.read(coef_2 , idx + (gen_size * 2));
            buf_coeffs.read(coef_3 , idx + (gen_size * 3));
            buf_coeffs.read(coef_4 , idx + (gen_size * 4));
            buf_coeffs.read(coef_5 , idx + (gen_size * 5));
            buf_coeffs.read(coef_6 , idx + (gen_size * 6));
            buf_coeffs.read(coef_7 , idx + (gen_size * 7));

        }

        // This action depends on the number of coded symbols we want to generate based
        // on uncoded ones, we can have one coded symbol or more in one packet
        action action_remove_symbols() {
            hdr.rlnc_in.symbols = hdr.rlnc_in.symbols - 1;
            hdr.symbols[1].setInvalid();
        }

        // GF Addition Arithmetic Operation
        action action_GF_add(bit<GF_BYTES> x0, bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3, bit<GF_BYTES> x4, bit<GF_BYTES> x5, bit<GF_BYTES> x6, bit<GF_BYTES> x7) {
            lin_comb = (x0 ^ x1 ^ x2 ^ x3 ^ x4 ^ x5 ^ x6 ^ x7);
        }

        // The LOG and ANTILOG tables
        register<bit<GF_BYTES>>(GF_BITS)          GF256_log;
        register<bit<GF_BYTES>>(GF_BITS*2)        GF256_invlog;

        // GF Multiplication Arithmetic Operation
        // multiplication_result = antilog[log[a] + log[b]]
        // r = x1*y1 + x2*y2 + x3*y3 + x4*y4
        // CONFIGURABLE
        action action_GF_mult(bit<GF_BYTES> x0, bit<GF_BYTES> y0, bit<GF_BYTES> x1, bit<GF_BYTES> y1, bit<GF_BYTES> x2, bit<GF_BYTES> y2, bit<GF_BYTES> x3, bit<GF_BYTES> y3, bit<GF_BYTES> x4, bit<GF_BYTES> y4, bit<GF_BYTES> x5, bit<GF_BYTES> y5, bit<GF_BYTES> x6, bit<GF_BYTES> y6, bit<GF_BYTES> x7, bit<GF_BYTES> y7) {
            bit<GF_BYTES> tmp_log_a = 0;
            bit<GF_BYTES> tmp_log_b = 0;
            bit<32> result = 0;
            bit<32> log_a = 0;
            bit<32> log_b = 0;

            GF256_log.read(tmp_log_a, (bit<32>) x0);
            GF256_log.read(tmp_log_b, (bit<32>) y0);
            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            result = (log_a + log_b);
            GF256_invlog.read(mult_result_0, result);
            if(x0 == 0 || y0 == 0) {
                mult_result_0 = 0;
            }

            GF256_log.read(tmp_log_a, (bit<32>) x1);
            GF256_log.read(tmp_log_b, (bit<32>) y1);
            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            result = (log_a + log_b);
            GF256_invlog.read(mult_result_1, result);
            if(x1 == 0 || y1 == 0) {
                mult_result_1 = 0;
            }

            GF256_log.read(tmp_log_a, (bit<32>) x2);
            GF256_log.read(tmp_log_b, (bit<32>) y2);
            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            result = (log_a + log_b);
            GF256_invlog.read(mult_result_2, result);
            if(x2 == 0 || y2 == 0) {
                mult_result_2 = 0;
            }

            GF256_log.read(tmp_log_a, (bit<32>) x3);
            GF256_log.read(tmp_log_b, (bit<32>) y3);
            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            result = (log_a + log_b);
            GF256_invlog.read(mult_result_3, result);
            if(x3 == 0 || y3 == 0) {
                mult_result_3 = 0;
            }

            GF256_log.read(tmp_log_a, (bit<32>) x4);
            GF256_log.read(tmp_log_b, (bit<32>) y4);
            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            result = (log_a + log_b);
            GF256_invlog.read(mult_result_4, result);
            if(x4 == 0 || y4 == 0) {
                mult_result_4 = 0;
            }

            GF256_log.read(tmp_log_a, (bit<32>) x5);
            GF256_log.read(tmp_log_b, (bit<32>) y5);
            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            result = (log_a + log_b);
            GF256_invlog.read(mult_result_5, result);
            if(x5 == 0 || y5 == 0) {
                mult_result_5 = 0;
            }

            GF256_log.read(tmp_log_a, (bit<32>) x6);
            GF256_log.read(tmp_log_b, (bit<32>) y6);
            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            result = (log_a + log_b);
            GF256_invlog.read(mult_result_6, result);
            if(x6 == 0 || y6 == 0) {
                mult_result_6 = 0;
            }

            GF256_log.read(tmp_log_a, (bit<32>) x7);
            GF256_log.read(tmp_log_b, (bit<32>) y7);
            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            result = (log_a + log_b);
            GF256_invlog.read(mult_result_7, result);
            if(x7 == 0 || y7 == 0) {
                mult_result_7 = 0;
            }


        }

        // The arithmetic operations needed for network coding are
        // multiplication and addition. First we multiply each value
        // by each random coefficient generated and then we add every
        // multiplication product, finally obtating the final result
        // CONFIGURABLE: parameters increase with the generation size
        action action_GF_arithmetic(bit<GF_BYTES> x0, bit<GF_BYTES> y0, bit<GF_BYTES> x1, bit<GF_BYTES> y1, bit<GF_BYTES> x2, bit<GF_BYTES> y2, bit<GF_BYTES> x3, bit<GF_BYTES> y3, bit<GF_BYTES> x4, bit<GF_BYTES> y4, bit<GF_BYTES> x5, bit<GF_BYTES> y5, bit<GF_BYTES> x6, bit<GF_BYTES> y6, bit<GF_BYTES> x7, bit<GF_BYTES> y7) {
            action_GF_mult(x0, y0, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6, x7, y7);
            action_GF_add(mult_result_0, mult_result_1, mult_result_2, mult_result_3, mult_result_4, mult_result_5, mult_result_6, mult_result_7);
        }

        // Generates a number of coefficients
        // CONFIGURABLE: the number of random generated coefficients increases with the generation size and the number of symbols
        action action_generate_random_coefficients() {
            // Initializing some variables to generate the random coefficients
            // with the minimum value being 0 and the maximum value being 2^n - 1
            bit<GF_BYTES> low = 0;
            bit<GF_BYTES> high = GF_MAX_VALUE;
            random(rand_num0, low, high);
            random(rand_num1, low, high);
            random(rand_num2, low, high);
            random(rand_num3, low, high);
            random(rand_num4, low, high);
            random(rand_num5, low, high);
            random(rand_num6, low, high);
            random(rand_num7, low, high);

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
            action_GF_arithmetic(s0, rand_num0, s1, rand_num1, s2, rand_num2, s3, rand_num3, s4, rand_num4, s5, rand_num5, s6, rand_num6, s7, rand_num7);
            hdr.symbols[0].symbol = lin_comb;

        }

        // Does linear combinations on the coefficients
        // Provides the ability to recode
        // CONFIGURABLE: depends on the generation size
        action action_code_coefficient() {
            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 0);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3, coef_4, rand_num4, coef_5, rand_num5, coef_6, rand_num6, coef_7, rand_num7);
            hdr.coefficients[0].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 1);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3, coef_4, rand_num4, coef_5, rand_num5, coef_6, rand_num6, coef_7, rand_num7);
            hdr.coefficients[1].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 2);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3, coef_4, rand_num4, coef_5, rand_num5, coef_6, rand_num6, coef_7, rand_num7);
            hdr.coefficients[2].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 3);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3, coef_4, rand_num4, coef_5, rand_num5, coef_6, rand_num6, coef_7, rand_num7);
            hdr.coefficients[3].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 4);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3, coef_4, rand_num4, coef_5, rand_num5, coef_6, rand_num6, coef_7, rand_num7);
            hdr.coefficients[4].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 5);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3, coef_4, rand_num4, coef_5, rand_num5, coef_6, rand_num6, coef_7, rand_num7);
            hdr.coefficients[5].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 6);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3, coef_4, rand_num4, coef_5, rand_num5, coef_6, rand_num6, coef_7, rand_num7);
            hdr.coefficients[6].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 7);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3, coef_4, rand_num4, coef_5, rand_num5, coef_6, rand_num6, coef_7, rand_num7);
            hdr.coefficients[7].coef = lin_comb;

        }

        // Adds a coefficient vector to the header of a previously systematic symbol
        // CONFIGURABLE: depends on the generation size and on the number of coded symbols we want to have per packet
        action action_add_coeff_header() {
            hdr.coefficients.push_front(8);
            hdr.coefficients[0].setValid();
            hdr.coefficients[1].setValid();
            hdr.coefficients[2].setValid();
            hdr.coefficients[3].setValid();
            hdr.coefficients[4].setValid();
            hdr.coefficients[5].setValid();
            hdr.coefficients[6].setValid();
            hdr.coefficients[7].setValid();
            hdr.coefficients[0].coef = rand_num0;
            hdr.coefficients[1].coef = rand_num1;
            hdr.coefficients[2].coef = rand_num2;
            hdr.coefficients[3].coef = rand_num3;
            hdr.coefficients[4].coef = rand_num4;
            hdr.coefficients[5].coef = rand_num5;
            hdr.coefficients[6].coef = rand_num6;
            hdr.coefficients[7].coef = rand_num7;
            hdr.rlnc_in.encoderRank = (bit<8>) gen_size;
        }
        // Changes the type of the packet to a value of 3, which indicates that
        // the packet is either coded or recoded
        action action_systematic_to_coded() {
        	hdr.rlnc_in.type = TYPE_CODED_OR_RECODED;
        }

        apply {
            if(hdr.rlnc_in.isValid()) {
                if((meta.clone_metadata.gen_symbol_index - meta.clone_metadata.starting_gen_symbol_index >= gen_size) && meta.rlnc_enable == 1) {
                    packet_counter_egress.count(0);
                    // Generate the random coefficients
                    action_generate_random_coefficients();
                    // Code the symbol with the generated random coefficients
                    action_code_symbol();
                    // Coding a packet
                    if(hdr.rlnc_in.type == 1) {
                        // adding the coefficient vector to the header
                        action_add_coeff_header();
                        // Since we coded the packet we change its type to TYPE_CODED_OR_RECODED
                        action_systematic_to_coded();
                    }
                     // Recoding a packet
                    else if(hdr.rlnc_in.type == 3) {
                        action_code_coefficient();
                    }
                    // mechanism to check if its time to free buffer space
                    packets_sent_buffer.read(packets_sent, 0);
                    packets_sent = packets_sent + 1;
                    if(packets_sent >= meta.clone_metadata.n_packets_out) {
                        action_free_buffer();
                        packets_sent_buffer.write(0,0);
                    }else {
                        packets_sent_buffer.write(0, packets_sent);
                    }
                }
            }
        }
}
