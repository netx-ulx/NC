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

        }

        // This action depends on the number of coded symbols we want to generate based
        // on uncoded ones, we can have one coded symbol or more in one packet
        action action_remove_symbols() {
            hdr.rlnc_in.symbols = hdr.rlnc_in.symbols - 1;
            hdr.symbols[1].setInvalid();
        }

        // GF Addition Arithmetic Operation
        action action_GF_add(bit<GF_BYTES> x0, bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3) {
            lin_comb = (x0 ^ x1 ^ x2 ^ x3);
        }

        bit<GF_BYTES> tmp_x0;
        bit<GF_BYTES> tmp_x1;
        bit<GF_BYTES> tmp_x2;
        bit<GF_BYTES> tmp_x3;
        bit<GF_BYTES> tmp_y0;
        bit<GF_BYTES> tmp_y1;
        bit<GF_BYTES> tmp_y2;
        bit<GF_BYTES> tmp_y3;

        // Shift-and-Add method to perform multiplication
        // There are 3 pairs of values being multiplied at the same time, that's why
        // there are x1,...,x3 and y1,...,y3 which are the values that are going to be multiplied
        // Then we have result1,...,result3 where the product is going to be stored in
        // Since we perform this action multiple times we need to buffer the resulting values in
        // registers to pass it over to the next iteration. To do so we read the value that is present
        // in the register at the moment and when all operations are done we write the resulting values
        // to the registers.
        action action_ffmult_iteration() {
            bit<GF_BYTES> mask = 0;
            mult_result_0 = mult_result_0 ^( -(tmp_y0 & 1) & tmp_x0);
            mask = -((tmp_x0 >> 7) & 1);
            tmp_x0 = (tmp_x0 << 1) ^ (IRRED_POLY & mask);
            tmp_y0 = tmp_y0 >> 1;

            mult_result_1 = mult_result_1 ^( -(tmp_y1 & 1) & tmp_x1);
            mask = -((tmp_x1 >> 7) & 1);
            tmp_x1 = (tmp_x1 << 1) ^ (IRRED_POLY & mask);
            tmp_y1 = tmp_y1 >> 1;

            mult_result_2 = mult_result_2 ^( -(tmp_y2 & 1) & tmp_x2);
            mask = -((tmp_x2 >> 7) & 1);
            tmp_x2 = (tmp_x2 << 1) ^ (IRRED_POLY & mask);
            tmp_y2 = tmp_y2 >> 1;

            mult_result_3 = mult_result_3 ^( -(tmp_y3 & 1) & tmp_x3);
            mask = -((tmp_x3 >> 7) & 1);
            tmp_x3 = (tmp_x3 << 1) ^ (IRRED_POLY & mask);
            tmp_y3 = tmp_y3 >> 1;

        }

        // GF Multiplication Arithmetic Operation
        // First we initialise the values into the respective register
        // Then we perform the same action 8 times, for each bit, to perform multiplication.
        // Finally we load the results to metadata to perform addition later on
        action action_GF_arithmetic(bit<GF_BYTES> x0, bit<GF_BYTES> y0, bit<GF_BYTES> x1, bit<GF_BYTES> y1, bit<GF_BYTES> x2, bit<GF_BYTES> y2, bit<GF_BYTES> x3, bit<GF_BYTES> y3) {
            tmp_x0 = x0;
            tmp_x1 = x1;
            tmp_x2 = x2;
            tmp_x3 = x3;
            tmp_y0 = y0;
            tmp_y1 = y1;
            tmp_y2 = y2;
            tmp_y3 = y3;

            mult_result_0 = 0;
            mult_result_1 = 0;
            mult_result_2 = 0;
            mult_result_3 = 0;

            action_ffmult_iteration();
            action_ffmult_iteration();
            action_ffmult_iteration();
            action_ffmult_iteration();
            action_ffmult_iteration();
            action_ffmult_iteration();
            action_ffmult_iteration();
            action_ffmult_iteration();

            action_GF_add(mult_result_0, mult_result_1, mult_result_2, mult_result_3);
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

        // Perfoms a linear combination using all the symbols stored in the register
        // and generates a coded symbol as the result
        // CONFIGURABLE: can change depending if we want to have more than one coded symbol per packet
        action action_code_symbol() {
            // Loading symbols in metadata
            // The number of symbols that need to be loaded is
            // equal to GEN_SIZE. Meaning loading all the symbols from the following positions:
            action_load_symbols(meta.clone_metadata.starting_gen_symbol_index);
            // Coding and copying the symbols
            action_GF_arithmetic(s0, rand_num0, s1, rand_num1, s2, rand_num2, s3, rand_num3);
            hdr.symbols[0].symbol = lin_comb;

        }

        // Does linear combinations on the coefficients
        // Provides the ability to recode
        // CONFIGURABLE: depends on the generation size
        action action_code_coefficient() {
            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 0);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3);
            hdr.coefficients[0].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 1);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3);
            hdr.coefficients[1].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 2);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3);
            hdr.coefficients[2].coef = lin_comb;

            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + 3);
            action_GF_arithmetic(coef_0, rand_num0, coef_1, rand_num1, coef_2, rand_num2, coef_3, rand_num3);
            hdr.coefficients[3].coef = lin_comb;

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
