
#include "registers.p4"
/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

// In the ingress the packets' symbols and coefficients are simply written to registers
// for future coding opportunities. We make use of the multicast mechanism
// to generate coded packets in the egress pipeline.
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

        // variables for the buffering mechanism
        bit<32> gen_symbol_index = 0;
        bit<32> gen_coeff_index = 0;

        // positions in the buffers where the first symbol/coefficient of the generation is buffered
        bit<32> starting_symbol_index_of_generation = 0;
        bit<32> starting_coeff_index_of_generation = 0;

        // total number of slots already allocated in the buffers
        bit<32> symbol_slots_reserved_value = 0;
        bit<32> coeff_slots_reserved_value = 0;

        bit<32> numb_of_symbols = (bit<32>) hdr.rlnc_in.symbols;
        bit<32> numb_of_coeffs = ((bit<32>) hdr.rlnc_in.symbols) * ((bit<32>) hdr.rlnc_in.encoderRank);

        bit<GF_BYTES> is_reserved = 0;

        // variables for generation information
        bit<16> gen_id = hdr.rlnc_out.gen_id;
        bit<32> gen_size = (bit<32>) hdr.rlnc_out.gen_size;
        bit<32> encoder_rank = (bit<32>) hdr.rlnc_in.encoderRank;

        action action_forward(bit<9> port) {
          standard_metadata.egress_spec = port;
        }

        action action_clone(bit<16> group, bit<8> packets_to_send) {
            standard_metadata.mcast_grp = group;
            meta.clone_metadata.n_packets_out = packets_to_send;
        }


        // Updates the index of the generation being coded each time a new packet count
        // from that specific generation arrives
        action action_update_gen_symbol_index() {
            gen_symbol_index = gen_symbol_index + numb_of_symbols;
            symbol_index_per_generation.write((bit<32>)gen_id, gen_symbol_index);
        }

        // Updates the index of the buffer containing the coefficients
        action action_update_gen_coeff_index() {
            gen_coeff_index = gen_coeff_index + numb_of_coeffs;
            coeff_index_per_generation.write((bit<32>) gen_id, gen_coeff_index);
        }

        // Saving symbols to registers
        // CONFIGURABLE: changes depending on the number of symbols in a packet
        // number of buffered symbols = hdr.rlnc_in.symbols
        action action_buffer_symbols() {
            ##buf_symbols.write(gen_symbol_index + N, hdr.symbols[N].symbol);
        }

        // Saves coefficients to registers
        // CONFIGURABLE: changes depending on the GEN_SIZE
        // number of buffered coefficients = hdr.rlnc_out.gen_size
        action action_buffer_coefficients() {
            $buf_coeffs.write(gen_coeff_index + N, hdr.coefficients[N].coef);
        }

        action my_drop() {
            mark_to_drop(standard_metadata);
        }

        action action_enable_rlnc(bit rlnc_enable) {
            meta.rlnc_enable = rlnc_enable;
        }

        table table_enable_rlnc {
            actions = {
                action_enable_rlnc;
            }
        }

        table table_clone{
            key = {
                  standard_metadata.ingress_port : exact;
            }
            actions = {
                action_clone;
            }
        }

        table table_forwarding_behaviour {
            key = {
                standard_metadata.ingress_port: ternary;
				meta.rlnc_enable : exact;
                hdr.rlnc_in.type: ternary; // To Diogo: why do we need this match field in this table?
            }
            actions = {
                action_forward;
                my_drop;
            }
			default_action = my_drop();
        }


        apply {
            if(hdr.rlnc_in.isValid()) {

                table_enable_rlnc.apply();

				table_forwarding_behaviour.apply();

				// I have moved all the following commented logic to the single table above
                //if(meta.rlnc_enable == 0) {
				//	// TODO: to Diogo, why is this hard-coded?
				//	// change this to table/action to specify forwarding behaviors from input to ouput ports
                //    action_forward(2);
                //} else {
                //    table_forwarding_behaviour.apply();

				// Type == 2 is packets carrying seed to generate coefficients, a case we do not deal with in this program
                if((hdr.rlnc_in.type == 1 || hdr.rlnc_in.type == 3)) {

                    // loading the buffer index for the current generation
                    symbol_index_per_generation.read(gen_symbol_index, (bit<32>)gen_id);

                    // loading the number of slots that were already reserved by all generations so far (circular buffer to reuse space across diff generations)
                    symbol_slots_reserved_buffer.read(symbol_slots_reserved_value, 0);

                    // loading the starting index of the generation
                    starting_symbol_index_of_generation_buffer.read(starting_symbol_index_of_generation, (bit<32>) gen_id);

                    // the storing of new generation is based on the free buffer space
                    if(gen_symbol_index == 0) {

                        starting_symbol_index_of_generation = symbol_slots_reserved_value % MAX_BUF_SIZE;

                        // checking space availability at the computed index
                        buf_symbols.read(is_reserved, starting_symbol_index_of_generation);

                        // if buffer overflows or starting_symbol_index_of_generation is already allocated then the packet will be dropped
                        if(starting_symbol_index_of_generation + gen_size > MAX_BUF_SIZE) {
                            my_drop();
							//TODO: we should generate a notification to keep track of these losses!
                            return;
                        }
                        starting_symbol_index_of_generation_buffer.write((bit<32>)gen_id, starting_symbol_index_of_generation);
                        gen_symbol_index = starting_symbol_index_of_generation;

                        // incrementing the number of slots reserved
                        symbol_slots_reserved_buffer.write(0, symbol_slots_reserved_value + gen_size);
                    }

                    // Using the generation index to save to the registers the packet symbols
                    action_buffer_symbols();

                    // incrementing the gen_symbol_index
                    action_update_gen_symbol_index();

                }

        		// processing of either coded or re-coded packets with coeff included into the header
                if(hdr.rlnc_in.type == 3) {

                    //loading the coeff buffer index for the generation
                    coeff_index_per_generation.read(gen_coeff_index, (bit<32>) gen_id);

                    //loading the number of slots that are already reserved
                    coeff_slots_reserved_buffer.read(coeff_slots_reserved_value, 0);

                    //loading the starting index of the generation in the coeff buffer
                    starting_coeff_index_of_generation_buffer.read(starting_coeff_index_of_generation, (bit<32>) gen_id);

                    //if condition to check if its the first time seing a generation
        			// SALVO: why do we not reuse here the previous check on "gen_symbol_index == 0"?
					// answer: since that is incremented by the action_update_gen_symbol_index() called previously
                    if(gen_coeff_index == 0) {

                        starting_coeff_index_of_generation = coeff_slots_reserved_value % MAX_BUF_SIZE;

                        //saving the starting index for future use
                        starting_coeff_index_of_generation_buffer.write((bit<32>)gen_id, starting_coeff_index_of_generation);

                        gen_coeff_index = starting_coeff_index_of_generation;

                        // incrementing the number of slots reserved
                        coeff_slots_reserved_buffer.write(0, coeff_slots_reserved_value + (encoder_rank*gen_size));
                    }

                    // saving the symbol's coefficients to the register
                    action_buffer_coefficients();

                    action_update_gen_coeff_index();
                }

                // Coding iff num of stored symbols for the current generation is  equal to or greater than generation size
                if((gen_symbol_index-starting_symbol_index_of_generation >= gen_size)) {

                    // values for egress processing are here copied to metadata:
                    meta.clone_metadata.gen_symbol_index =  gen_symbol_index;
                    meta.clone_metadata.starting_gen_symbol_index = starting_symbol_index_of_generation;
                    meta.clone_metadata.starting_gen_coeff_index =  starting_coeff_index_of_generation;

                    // activate multicast here to generate packets holding different linear combinations in egress
                    table_clone.apply();
                }
                //}
            }
        }
}
