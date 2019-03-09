/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>
#include "includes/parser.p4"
#include "includes/deparser.p4"
#include "includes/registers.p4"

// Below is the state of the buffers, with an example with a generation size of 2,
// captured at a moment in time
// Only two generation have arrived at the moment
// The packets buffer has a max size of 4
// The order of arrival of the packets were the following:
// 1 - gen0_p1
// 1 - gen1_p1
// 1 - gen1_p2
// Packet gen0_p2 has yet to arrives
// The "packet buffer":
//    ╔═════════╦═════════╦═══╦═════════╦═════════╗
//   ║ Index   ║ 0       ║ 1 ║ 2       ║ 3       ║
//  ╠═════════╬═════════╬═══╬═════════╬═════════╣
// ║ Packets ║ gen0_p1 ║   ║ gen1_p1 ║ gen1_p2 ║
//╚═════════╩═════════╩═══╩═════════╩═════════╝

// The index_per_generation buffer:
//    ╔═══════╦═══╦═══╗
//   ║ Index ║ 0 ║ 1 ║
//  ╠═══════╬═══╬═══╣
// ║ Value ║ 1 ║ 4 ║
//╚═══════╩═══╩═══╝

// The starting_index_of_generation_buffer:
//    ╔═══════╦═══╦═══╗
//   ║ Index ║ 0 ║ 1 ║
//  ╠═══════╬═══╬═══╣
// ║ Value ║ 0 ║ 2 ║
//╚═══════╩═══╩═══╝

// The slots_reserved_buffer:
//    ╔═══════╦═══╗
//   ║ Index ║ 0 ║
//  ╠═══════╬═══╣
// ║ Value ║ 4 ║
//╚═══════╩═══╝

// The reserved_space buffer:
//    ╔═══════╦═══╦═══╦═══╦═══╗
//   ║ Index ║ 0 ║ 1 ║ 2 ║ 3 ║
//  ╠═══════╬═══╬═══╬═══╬═══╣
// ║ Value ║ 1 ║ 0 ║ 1 ║ 0 ║
//╚═══════╩═══╩═══╩═══╩═══╝

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

// In the ingress the packets contents will be simply written to registers
// for future coding opportunities. We make use of the multicast mechanism
// to "clone" as many packets as we want
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    // variables for the buffering mechanism
    bit<32> gen_index = 0;
    // This value tells us the position in the buffer where the first
    // packet of the generation is buffered
    bit<32> starting_index_of_generation = 0;
    // This value tells us how many slots, in the buffers containing the symbols and coeffs,
    // were reserved
    bit<32> slots_reserved_value = 0;
    // This value tells us if a specific starting position of a generation, in the buffers containing the symbols and coeffs,
    // is reserved already for some other generation or not
    bit<1>  reserved_space_value = 0;
    bit<32> numb_of_symbols = (bit<32>) hdr.rlnc_in.symbols;

    bit<8> is_reserved = 0;

    action action_forward(bit<9> port) {
      standard_metadata.egress_spec = port;
    }

    // variables for generation information
    bit<8> gen_id = hdr.rlnc_out.gen_id;
    bit<32> gen_size = (bit<32>) hdr.rlnc_out.gen_size;

    action action_clone(bit<16> group) {
        standard_metadata.mcast_grp = group;
    }


    // Updates the index of the generation being coded each time a new packet count
    // from that specific generation arrives
    action action_update_buffer_index() {
        gen_index = gen_index + numb_of_symbols;
        index_per_generation.write((bit<32>)gen_id, gen_index);
    }

    // Saving symbols and coefficients to registers
    action action_write() {
        buf_symbols.write(gen_index, hdr.symbols[0].symbol);
        buf_symbols.write(gen_index + 1, hdr.symbols[1].symbol);
    }

    action _drop() {
        mark_to_drop();
    }

    table table_clone{
        key = {
              standard_metadata.ingress_port : exact;
        }
        actions = {
            action_clone;
        }
    }

    table table_debug {
        key = {
            gen_index : exact;
            slots_reserved_value : exact;
            starting_index_of_generation : exact;
            is_reserved : exact;
            numb_of_symbols : exact;
            hdr.symbols[0].symbol : exact;
            hdr.symbols[1].symbol : exact;
        }
        actions = {
            NoAction;
        }
    }

    table table_forward {
      key = {
        standard_metadata.ingress_port: exact;
      }
      actions = {
        action_forward;
      }
    }

    apply {
        // so far, the forwarding of a packet is only based on the ingress port
		// TODO: make this behavior customazible from the control-plane. For ex., you may decided to either forward uncoded packets
        // or drop them waiting for the current generation's buffer to fill
        if(hdr.rlnc_in.type == 1 && hdr.rlnc_in.isValid()) {
            // loading the buffer index for the current generation
            index_per_generation.read(gen_index, (bit<32>)gen_id);
            // loading the number of slots that were already reserved by all generations so far (circular buffer to reuse space across diff generations)
            slots_reserved_buffer.read(slots_reserved_value, 0);

            // if it's the first time seeing a particular generation
            // the index in which to store the first packet of this new generation is based on the buffer free space
            if(gen_index == 0) {
                starting_index_of_generation = slots_reserved_value % MAX_BUF_SIZE;
                // if the computed index it's reserved already then that generation will not be
                // coded, instead it will be dropped
                buf_symbols.read(is_reserved, starting_index_of_generation);
                // iff the buffer overflows or the position in the given starting_index_of_generation is already
                // occupied, then the packet will be dropped and further computation will be stopped

                // debug table, does nothing, serves to check some values on the switch log file
                if(starting_index_of_generation + gen_size > MAX_BUF_SIZE || is_reserved != 0) {
                    // This returns assures that all of the following computation will
                    // not be executed, as is intended
                    _drop();
                    return;
                }
                gen_index = starting_index_of_generation;
                starting_index_of_generation_buffer.write((bit<32>)gen_id, starting_index_of_generation);
                slots_reserved_buffer.write(0, slots_reserved_value + gen_size);
            }
            // Using the generation index to save to the registers the packet symbols
            action_write();

            // incrementing the gen_index
            action_update_buffer_index();

            table_debug.apply();
            // Coding iff num of stored symbols for the current generation is  equal to generation size
            if(gen_index-starting_index_of_generation >= GEN_SIZE) {
                // some values need to be known in the egress, so they are copied to metadata
                meta.clone_metadata.gen_index = (bit<8>) gen_index;
                meta.clone_metadata.starting_gen_index = (bit<8>)starting_index_of_generation;
                // applying the clone mechanism through the use of multicast
                // this is achieved by multicasting packets to the same port
                table_clone.apply();
            }
        }
    }
}

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
    bit<GF_BYTES> mult_result_1 = 0;
    bit<GF_BYTES> mult_result_2 = 0;
    bit<GF_BYTES> mult_result_3 = 0;
    bit<GF_BYTES> mult_result_4 = 0;
    bit<GF_BYTES> lin_comb = 0;

    bit<GF_BYTES> rand_num1 = 0;
    bit<GF_BYTES> rand_num2 = 0;
    bit<GF_BYTES> rand_num3 = 0;
    bit<GF_BYTES> rand_num4 = 0;

    bit<8> numb_of_symbols = (bit<8>) hdr.rlnc_in.symbols;

    // The LOG and ANTILOG tables
    register<bit<GF_BYTES>>(GF_BITS)          GF256_log;
    register<bit<GF_BYTES>>(509)              GF256_invlog;

    // Frees the space reserved by the current generation
    action action_free_buffer() {
        buf_coeffs.write(0, 0);
        buf_symbols.write(0, 0);
        index_per_generation.write((bit<32>)hdr.rlnc_out.gen_id, 0);
    }
    //Loads a coefficient and a symbol from the provided index to the first set of metadata
    action action_load_to_pkt_1(bit<8> idx) {
        buf_symbols.read(meta.rlnc_metadata.p1_s1, (bit<32>)idx);
        buf_symbols.read(meta.rlnc_metadata.p1_s2, (bit<32>)idx + 1);

    }
    //Loads a coefficient and a symbol from the provided index to the second set of metadata
    action action_load_to_pkt_2(bit<8> idx) {
        buf_symbols.read(meta.rlnc_metadata.p2_s1, (bit<32>)idx);
        buf_symbols.read(meta.rlnc_metadata.p2_s2, (bit<32>)idx + 1);
    }

    // GF Addition Arithmetic Operation
    action action_GF_add(bit<GF_BYTES> a, bit<GF_BYTES> b, bit<GF_BYTES> c, bit<GF_BYTES> d) {
        lin_comb = (a ^ b ^ c ^ d);
    }

    // GF Multiplication Arithmetic Operation
    // multiplication_result = antilog[log[a] + log[b]]
    action action_GF_mult(bit<GF_BYTES> x1, bit<GF_BYTES> y1, bit<GF_BYTES> x2, bit<GF_BYTES> y2,
                          bit<GF_BYTES> x3, bit<GF_BYTES> y3, bit<GF_BYTES> x4, bit<GF_BYTES> y4) {
        bit<8> tmp_log_a = 0;
        bit<8> tmp_log_b = 0;
        bit<32> result = 0;
        bit<32> log_a = 0;
        bit<32> log_b = 0;

        GF256_log.read(tmp_log_a, (bit<32>) x1);
        GF256_log.read(tmp_log_b, (bit<32>) y1);
        // These tmp values are used for the registers to fix cast issues, we
        // then cast them to 32 bit. The other workaround was to have the registers storing
        // 32 bit values.
        log_a = (bit<32>) tmp_log_a;
        log_b = (bit<32>) tmp_log_b;
        result = (log_a + log_b);
        GF256_invlog.read(mult_result_1, result);
        // This if is necessary because the table does not handle the case when one of
        // the operands is 0. This is not currently preventing the tables lookups but
        // P4 does not allow registers reads or writes within if/else clauses.
        // The workaround would be to put all the actions called until now
        // in the control apply block, decreasing the code readability.
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
    }

    // The arithmetic operations needed for network coding are
    // multiplication and addition. First we multiply each value
    // by each random coefficient generated and then we add every
    // multiplication product, finally obtating the final result
    // the operation is the following: r = x1*y1 + x2*y2
    action action_GF_arithmetic(bit<GF_BYTES> x1, bit<GF_BYTES> y1, bit<GF_BYTES> x2, bit<GF_BYTES> y2,
                                bit<GF_BYTES> x3, bit<GF_BYTES> y3, bit<GF_BYTES> x4, bit<GF_BYTES> y4) {
        action_GF_mult(x1,y1,x2,y2,x3,y3,x4,y4);
        action_GF_add(mult_result_1, mult_result_2, mult_result_3, mult_result_4);
    }

    action action_code_packet() {
        // Initializing some variables to generate the random coefficients
        // with the minimum value being 0 and the maximum value being 2^n - 1
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MAX_VALUE;
        // generating a number of random coefficients equal to the generation size
        random(rand_num1, low, high);
        random(rand_num2, low, high);
        random(rand_num3, low, high);
        random(rand_num4, low, high);

        // Loading symbols and coefficients in metadata
        // The number of packets that need to be loaded is
        // equal to GEN_SIZE. Meaning loading all the packets from the following positions:
        bit<8> aux_inc = 0;
        action_load_to_pkt_1(meta.clone_metadata.starting_gen_index + (numb_of_symbols * aux_inc));
        aux_inc = aux_inc + 1;
        action_load_to_pkt_2(meta.clone_metadata.starting_gen_index + (numb_of_symbols * aux_inc));

        // Coding and copying the symbols
		// SALVO: can you the same coefficients for the different combinations?
        action_GF_arithmetic(meta.rlnc_metadata.p1_s1, rand_num1, meta.rlnc_metadata.p2_s1, rand_num2,
                             meta.rlnc_metadata.p1_s2, rand_num3, meta.rlnc_metadata.p2_s2, rand_num4);
        hdr.symbols[0].symbol = lin_comb;
        hdr.symbols[1].setInvalid();
    }

    action action_add_coeff_header() {
        hdr.coefficients.push_front(4);
        hdr.coefficients[0].setValid();
        hdr.coefficients[1].setValid();
        hdr.coefficients[2].setValid();
        hdr.coefficients[3].setValid();
        hdr.coefficients[0].coef = rand_num1;
        hdr.coefficients[1].coef = rand_num2;
        hdr.coefficients[2].coef = rand_num3;
        hdr.coefficients[3].coef = rand_num4;
    }
    // Changes the type of the packet to a value of 3, which indicates that
    // the packet is either coded or recoded
    action action_systematic_to_coded() {
    	hdr.rlnc_in.type = TYPE_CODED_OR_RECODED;
    }

    table table_debug {
        key = {
            meta.rlnc_metadata.p1_s1: exact;
            meta.rlnc_metadata.p1_s2 : exact;
            meta.rlnc_metadata.p2_s1 : exact;
            meta.rlnc_metadata.p2_s2 : exact;
            hdr.symbols[0].symbol : exact;
            hdr.symbols[1].symbol : exact;
        }
        actions = {
            NoAction;
        }
    }

    apply {
        if(hdr.rlnc_in.type == 1 && hdr.rlnc_in.isValid()) {
            if(meta.clone_metadata.gen_index - meta.clone_metadata.starting_gen_index >= GEN_SIZE) {
                // We code the packet with all the current packets stored in the buffer
                action_code_packet();

                action_add_coeff_header();
                // Since we coded the packet we change its type to TYPE_CODED_OR_RECODED
                action_systematic_to_coded();
                table_debug.apply();
            }
        }
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply {
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
