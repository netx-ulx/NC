// The Egress is where the coding happens. N cloned packets enter the egress as a result
// of the multicast mechanism being used. All of these will be a different linear combination
// due to different random coefficients being generated.
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

        bit<GF_BYTES> lin_comb = 0;


        // Variables to hold the values of the symbols stored in the symbols registers
        // CONFIGURABLE: changes depending on the generation size
        !bit<GF_BYTES> sN = 0;

        // Variables to hold the values of the coefficients stored in the coeff register
        // CONFIGURABLE: changes depending on the generation size
        GEN_TIMES_2bit<GF_BYTES> coef_N = 0;

        // The random generated coefficients
        // CONFIGURABLE: changes depending on the generation size and the number of symbols
        $bit<GF_BYTES> rand_numN = 0;


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
            !buf_symbols.read(sN, idx + N);

        }
        //Loads gen_size coefficients to variables to use in the linear combinations
        // CONFIGURABLE: changes depending on the generation size
        action action_load_coeffs(bit<32> idx) {
            GEN_TIMES_2buf_coeffs.read(coef_N , idx + N);

        }

        // Generates a number of coefficients
        // CONFIGURABLE: the number of random generated coefficients increases with the generation size and the number of symbols
        action action_generate_random_coefficients() {
            // Initializing some variables to generate the random coefficients
            // with the minimum value being 0 and the maximum value being 2^n - 1
            bit<GF_BYTES> low = 0;
            bit<GF_BYTES> high = GF_MAX_VALUE;
            $random(rand_numN, low, high);

        }

        // Adds a coefficient vector to the header of a previously systematic symbol
        // CONFIGURABLE: depends on the generation size and on the number of coded symbols we want to have per packet
        action action_add_coeff_header() {
            hdr.coefficients.push_front(NNNN);
            $hdr.coefficients[N].setValid();
            $hdr.coefficients[N].coef = rand_numN;
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
                    CODE_SYMBOL
                    if(sN != 0 && rand_numM != 0) {
                        action_get_sum_log(sN, rand_numM);
                        if(sum_log >= FIELD) {
                            sum_log = sum_log - (FIELD);
                        }
                        action_get_antilog_value_and_add(sum_log);
                    }
                    CODE_SYMBOL
                    if(hdr.rlnc_in.type == 1) {
                        // adding the coefficient vector to the header
                        action_add_coeff_header();
                        // Since we coded the packet we change its type to TYPE_CODED_OR_RECODED
                        action_systematic_to_coded();
                    }
                     // Recoding a packet
                    else if(hdr.rlnc_in.type == 3) {
                        action_load_coeffs(meta.clone_metadata.coeff_gen_head);
                        CODE_COEFF
                        if(coef_M != 0 && rand_numN != 0) {
                            action_get_sum_log(coef_M, rand_numN);
                            if(sum_log >= FIELD) {
                                sum_log = sum_log - (FIELD);
                            }
                            action_get_antilog_value_and_add(sum_log);
                        }
                        CODE_COEFF
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
