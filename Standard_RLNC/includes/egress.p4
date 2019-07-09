// of the multicast mechanism being used. All of these will be a different linear combination
// due to different random coefficients being generated.
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

        bit<GF_BYTES> lin_comb = 0;


        // Variables to hold the values of the symbols stored in the symbols registers
        // CONFIGURABLE: changes depending on the generation size
        bit<GF_BYTES> s0 = 0;
        bit<GF_BYTES> s1 = 0;
        bit<GF_BYTES> s2 = 0;
        bit<GF_BYTES> s3 = 0;

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
        bit<GF_BYTES> coef_8 = 0;
        bit<GF_BYTES> coef_9 = 0;
        bit<GF_BYTES> coef_10 = 0;
        bit<GF_BYTES> coef_11 = 0;
        bit<GF_BYTES> coef_12 = 0;
        bit<GF_BYTES> coef_13 = 0;
        bit<GF_BYTES> coef_14 = 0;
        bit<GF_BYTES> coef_15 = 0;

        // The random generated coefficients
        // CONFIGURABLE: changes depending on the generation size and the number of symbols
        bit<GF_BYTES> rand_num0 = 0;
        bit<GF_BYTES> rand_num1 = 0;
        bit<GF_BYTES> rand_num2 = 0;
        bit<GF_BYTES> rand_num3 = 0;


        bit<8> numb_of_symbols = (bit<8>) hdr.rlnc_in.symbols;
        bit<32> gen_size = (bit<32>) hdr.rlnc_out.gen_size;
        register<bit<8>>(1) packets_sent_buffer;
        bit<8> packets_sent = 0;
        counter(1, CounterType.packets_and_bytes) packet_counter_egress;
        register<bit<GF_BYTES>>(GF_BITS)          GF256_log;
        register<bit<GF_BYTES>>(GF_BITS*2)              GF256_invlog;
        bit<32> sum_log = 0;


        // Frees the space reserved by the current generation
        action action_free_buffer() {
            bit<32> tmp = meta.clone_metadata.symbols_gen_head;
            buf_symbols.write(tmp, 0);
            symbol_gen_offset_buffer.write((bit<32>)hdr.rlnc_out.gen_id, 0);
            coeff_gen_offset_buffer.write((bit<32>)hdr.rlnc_out.gen_id, 0);
            symbols_gen_head_buffer.write((bit<32>)hdr.rlnc_out.gen_id, 0);
            coeff_gen_head_buffer.write((bit<32>)hdr.rlnc_out.gen_id, 0);
        }

        // Loads gen_size symbols to metadata to use in linear combinations
        // CONFIGURABLE: changes depending on the generation size
        action action_load_symbols(bit<32> idx) {
            buf_symbols.read(s0, idx + 0);
            buf_symbols.read(s1, idx + 1);
            buf_symbols.read(s2, idx + 2);
            buf_symbols.read(s3, idx + 3);

        }
        //Loads gen_size coefficients to variables to use in the linear combinations
        // CONFIGURABLE: changes depending on the generation size
        action action_load_coeffs(bit<32> idx) {
            buf_coeffs.read(coef_0 , idx + 0);
            buf_coeffs.read(coef_1 , idx + 1);
            buf_coeffs.read(coef_2 , idx + 2);
            buf_coeffs.read(coef_3 , idx + 3);
            buf_coeffs.read(coef_4 , idx + 4);
            buf_coeffs.read(coef_5 , idx + 5);
            buf_coeffs.read(coef_6 , idx + 6);
            buf_coeffs.read(coef_7 , idx + 7);
            buf_coeffs.read(coef_8 , idx + 8);
            buf_coeffs.read(coef_9 , idx + 9);
            buf_coeffs.read(coef_10 , idx + 10);
            buf_coeffs.read(coef_11 , idx + 11);
            buf_coeffs.read(coef_12 , idx + 12);
            buf_coeffs.read(coef_13 , idx + 13);
            buf_coeffs.read(coef_14 , idx + 14);
            buf_coeffs.read(coef_15 , idx + 15);

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

        }

        // Adds a coefficient vector to the header of a previously systematic symbol
        // CONFIGURABLE: depends on the generation size and on the number of coded symbols we want to have per packet
        action action_add_coeff_header() {
            hdr.coefficients.push_front(4);
            hdr.coefficients[0].setValid();
            hdr.coefficients[1].setValid();
            hdr.coefficients[2].setValid();
            hdr.coefficients[3].setValid();
            hdr.coefficients[0].coef = rand_num0;
            hdr.coefficients[1].coef = rand_num1;
            hdr.coefficients[2].coef = rand_num2;
            hdr.coefficients[3].coef = rand_num3;
            hdr.rlnc_in.encoderRank = (bit<8>) gen_size;
        }
        // Changes the type of the packet to a value of 3, which indicates that
        // the packet is either coded or recoded
        action action_systematic_to_coded() {
        	hdr.rlnc_in.type = TYPE_CODED_OR_RECODED;
        }

        // Get the values from the log table and sum them together
        action action_get_sum_log(bit<GF_BYTES> x, bit<GF_BYTES> y) {
            bit<GF_BYTES> tmp_log_a = 0;
            bit<GF_BYTES> tmp_log_b = 0;
            bit<32> log_a = 0;
            bit<32> log_b = 0;

            GF256_log.read(tmp_log_a, (bit<32>) x);
            GF256_log.read(tmp_log_b, (bit<32>) y);

            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            sum_log = (log_a + log_b);
        }

        // Get the final multiplication result from the antilog table and add to linear combination
        action action_get_antilog_value_and_add(bit<32> log_sum) {
            bit<GF_BYTES> mult_result = 0;
            GF256_invlog.read(mult_result, log_sum);
            lin_comb = lin_comb ^ mult_result;
        }

        apply {
            if(hdr.rlnc_in.isValid() && meta.clone_metadata.coding_flag ==1 && meta.rlnc_enable == 1) {
                    packet_counter_egress.count(0);
                    // Generate the random coefficients
                    action_generate_random_coefficients();
                    // Code the symbol with the generated random coefficients
                    action_load_symbols(meta.clone_metadata.symbols_gen_head);
                    if(s0 != 0 && rand_num0 != 0) {
                        action_get_sum_log(s0, rand_num0);
                        if(sum_log >= 255) {
                            sum_log = sum_log - (255);
                        }
                        action_get_antilog_value_and_add(sum_log);
                    }

                    if(s1 != 0 && rand_num1 != 0) {
                        action_get_sum_log(s1, rand_num1);
                        if(sum_log >= 255) {
                            sum_log = sum_log - (255);
                        }
                        action_get_antilog_value_and_add(sum_log);
                    }

                    if(s2 != 0 && rand_num2 != 0) {
                        action_get_sum_log(s2, rand_num2);
                        if(sum_log >= 255) {
                            sum_log = sum_log - (255);
                        }
                        action_get_antilog_value_and_add(sum_log);
                    }

                    if(s3 != 0 && rand_num3 != 0) {
                        action_get_sum_log(s3, rand_num3);
                        if(sum_log >= 255) {
                            sum_log = sum_log - (255);
                        }
                        action_get_antilog_value_and_add(sum_log);
                    }

                    hdr.symbols[0].symbol = lin_comb;
                    lin_comb = 0;
                    if(hdr.rlnc_in.type == 1) {
                        // adding the coefficient vector to the header
                        action_add_coeff_header();
                        // Since we coded the packet we change its type to TYPE_CODED_OR_RECODED
                        action_systematic_to_coded();
                    }
                     // Recoding a packet
                    else if(hdr.rlnc_in.type == 3) {
                        action_load_coeffs(meta.clone_metadata.coeff_gen_head);
                        if(coef_0 != 0 && rand_num0 != 0) {
                            action_get_sum_log(coef_0, rand_num0);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_4 != 0 && rand_num1 != 0) {
                            action_get_sum_log(coef_4, rand_num1);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_8 != 0 && rand_num2 != 0) {
                            action_get_sum_log(coef_8, rand_num2);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_12 != 0 && rand_num3 != 0) {
                            action_get_sum_log(coef_12, rand_num3);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }

                        hdr.coefficients[0].coef = lin_comb;
                        lin_comb = 0;
                        if(coef_1 != 0 && rand_num0 != 0) {
                            action_get_sum_log(coef_1, rand_num0);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_5 != 0 && rand_num1 != 0) {
                            action_get_sum_log(coef_5, rand_num1);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_9 != 0 && rand_num2 != 0) {
                            action_get_sum_log(coef_9, rand_num2);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_13 != 0 && rand_num3 != 0) {
                            action_get_sum_log(coef_13, rand_num3);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }

                        hdr.coefficients[1].coef = lin_comb;
                        lin_comb = 0;
                        if(coef_2 != 0 && rand_num0 != 0) {
                            action_get_sum_log(coef_2, rand_num0);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_6 != 0 && rand_num1 != 0) {
                            action_get_sum_log(coef_6, rand_num1);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_10 != 0 && rand_num2 != 0) {
                            action_get_sum_log(coef_10, rand_num2);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_14 != 0 && rand_num3 != 0) {
                            action_get_sum_log(coef_14, rand_num3);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }

                        hdr.coefficients[2].coef = lin_comb;
                        lin_comb = 0;
                        if(coef_3 != 0 && rand_num0 != 0) {
                            action_get_sum_log(coef_3, rand_num0);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_7 != 0 && rand_num1 != 0) {
                            action_get_sum_log(coef_7, rand_num1);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_11 != 0 && rand_num2 != 0) {
                            action_get_sum_log(coef_11, rand_num2);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        if(coef_15 != 0 && rand_num3 != 0) {
                            action_get_sum_log(coef_15, rand_num3);
                            if(sum_log >= 255) {
                                sum_log = sum_log - (255);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }

                        hdr.coefficients[3].coef = lin_comb;
                        lin_comb = 0;
                    }
                    // mechanism to check if its time to free buffer space
                    packets_sent_buffer.read(packets_sent, 0);
                    packets_sent = packets_sent + 1;
                    if(packets_sent >= meta.clone_metadata.n_packets_out) {
                        //action_free_buffer();
                        packets_sent_buffer.write(0,0);
                    }else {
                        packets_sent_buffer.write(0, packets_sent);
                    }
           }

        }
}
