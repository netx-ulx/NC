// The Egress is where the coding happens. N cloned packets enter the egress as a result
// of the multicast mechanism being used. All of these will be a different linear combination
// due to different random coefficients being generated.
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

        // Variable for results of the arithmetic operations
        // CONFIGURABLE: changes depending on the generation size
        !bit<GF_BYTES> mult_result_N = 0;

        bit<GF_BYTES> lin_comb = 0;


        // Variables to hold the values of the symbols stored in the symbols registers
        // CONFIGURABLE: changes depending on the generation size
        !bit<GF_BYTES> sN = 0;

        // Variables to hold the values of the coefficients stored in the coeff register
        // CONFIGURABLE: changes depending on the generation size
        !bit<GF_BYTES> coef_N = 0;

        // The random generated coefficients
        // CONFIGURABLE: changes depending on the generation size and the number of symbols
        $bit<GF_BYTES> rand_numN = 0;


        bit<8> numb_of_symbols = (bit<8>) hdr.rlnc_in.symbols;
        bit<32> gen_size = (bit<32>) hdr.rlnc_out.gen_size;
        register<bit<8>>(1) packets_sent_buffer;
        bit<8> packets_sent = 0;

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
            !buf_symbols.read(sN, (bit<32>)idx + N);

        }
        //Loads gen_size coefficients to variables to use in the linear combinations
        // CONFIGURABLE: changes depending on the generation size
        action action_load_coeffs(bit<32> idx) {
            !buf_coeffs.read(coef_N , idx + (gen_size * N));

        }

        // This action depends on the number of coded symbols we want to generate based
        // on uncoded ones, we can have one coded symbol or more in one packet
        action action_remove_symbols() {
            hdr.rlnc_in.symbols = hdr.rlnc_in.symbols - 1;
            hdr.symbols[1].setInvalid();
        }

        // GF Addition Arithmetic Operation
        action action_GF_add(%%bit<GF_BYTES> xN%%) {
            lin_comb = (??xN??);
        }

        MULTIPLICATION_PLACEHOLDER

        // Generates a number of coefficients
        // CONFIGURABLE: the number of random generated coefficients increases with the generation size and the number of symbols
        action action_generate_random_coefficients() {
            // Initializing some variables to generate the random coefficients
            // with the minimum value being 0 and the maximum value being 2^n - 1
            bit<GF_BYTES> low = 0;
            bit<GF_BYTES> high = GF_MAX_VALUE;
            $random(rand_numN, low, high);

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
            CODE_SYMBOL
            action_GF_arithmetic(??sN, rand_numM??);
            hdr.symbols[N].symbol = lin_comb;
            CODE_SYMBOL
        }

        // Does linear combinations on the coefficients
        // Provides the ability to recode
        // CONFIGURABLE: depends on the generation size
        action action_code_coefficient() {
            CODE_COEFF
            action_load_coeffs(meta.clone_metadata.starting_gen_coeff_index + P);
            action_GF_arithmetic(??coef_N, rand_numM??);
            hdr.coefficients[N].coef = lin_comb;
            CODE_COEFF
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

        apply {
            if(hdr.rlnc_in.isValid()) {
                if((meta.clone_metadata.gen_symbol_index - meta.clone_metadata.starting_gen_symbol_index >= gen_size) && meta.rlnc_enable == 1) {
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
