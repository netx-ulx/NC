/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>
#include "includes/headers.p4"
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

    // variables for generation information
    bit<32> gen_id = (bit<32>) hdr.rlnc.generation; // TODO: check what would be the proper size for the generation ID field
    bit<32> gen_size = GEN_SIZE;

	// Variable for results of the arithmetic operations
    bit<GF_BYTES> mult_result_1 = 0;
    bit<GF_BYTES> mult_result_2 = 0;
    bit<GF_BYTES> lin_comb = 0;

    // The LOG and ANTILOG tables
    register<bit<GF_BYTES>>(GF_BITS)          GF256_log;
    register<bit<GF_BYTES>>(509)       GF256_invlog;

    // Sets the port to forward the packet
    action action_forward(egressSpec_t port) {
      standard_metadata.egress_spec = port;
    }

    // Frees the space reserved by the current generation
    action action_free_buffer() {
        reserved_space.write(starting_index_of_generation, 0);
        index_per_generation.write(gen_id, 0);
    }

    // Updates the index of the generation being coded each time a new packet count
    // from that specific generation arrives
    action action_update_buffer_index() {
        gen_index = gen_index + 1;
        index_per_generation.write(gen_id, gen_index);
    }

    // Saving symbols and coefficients to registers
    action action_write() {
        buf_c1.write(gen_index, hdr.coeff[0].coeff);
        buf_c2.write(gen_index, hdr.coeff[1].coeff);
        buf_s1.write(gen_index, hdr.msg[0].content);
        buf_s2.write(gen_index, hdr.msg[1].content);
    }

    //Loads a coefficient and a symbol from the provided index to the first set of metadata
    action action_load_to_pkt_1(bit<32> idx) {
        buf_c1.read(meta.rlnc_metadata.c1_1, idx);
        buf_c2.read(meta.rlnc_metadata.c1_2, idx);
        buf_s1.read(meta.rlnc_metadata.p1_1, idx);
        buf_s2.read(meta.rlnc_metadata.p1_2, idx);

    }
    //Loads a coefficient and a symbol from the provided index to the second set of metadata
    action action_load_to_pkt_2(bit<32> idx) {
        buf_c1.read(meta.rlnc_metadata.c2_1, idx);
        buf_c2.read(meta.rlnc_metadata.c2_2, idx);
        buf_s1.read(meta.rlnc_metadata.p2_1, idx);
        buf_s2.read(meta.rlnc_metadata.p2_2, idx);
    }

    // GF Addition Arithmetic Operation
    action action_GF_add(bit<GF_BYTES> a, bit<GF_BYTES> b) {
        lin_comb = (a ^ b);
    }

    // GF Multiplication Arithmetic Operation
    // multiplication_result = antilog[log[a] + log[b]]
    action action_GF_mult(bit<GF_BYTES> x1, bit<GF_BYTES> y1, bit<GF_BYTES> x2, bit<GF_BYTES> y2) {
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
    }

    // The arithmetic operations needed for network coding are
    // multiplication and addition. First we multiply each value
    // by each random coefficient generated and then we add every
    // multiplication product, finally obtating the final result
    action action_GF_arithmetic(bit<GF_BYTES> x1, bit<GF_BYTES> y1, bit<GF_BYTES> x2, bit<GF_BYTES> y2) {
        action_GF_mult(x1,y1,x2,y2);
        action_GF_add(mult_result_1, mult_result_2);
    }

    action action_code_packet() {
        // Initializing some variables to generate the random coefficients
        // with the minimum value being 0 and the maximum value being 2^n - 1
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MAX_VALUE;
        bit<GF_BYTES> rand_num1 = 0;
        bit<GF_BYTES> rand_num2 = 0;
        // generating a number of random coefficients equal to the generation size
        random(rand_num1, low, high);
        random(rand_num2, low, high);

        // Loading symbols and coefficients in metadata
        // The number of packets that need to be loaded is
        // equal to GEN_SIZE. Meaning loading all the packets from the following positions:
        action_load_to_pkt_1(gen_index - 2);
        action_load_to_pkt_2(gen_index - 1);

        // Coding and copying the symbols
		// SALVO: can you the same coefficients for the different combinations?
        action_GF_arithmetic(meta.rlnc_metadata.p1_1, rand_num1, meta.rlnc_metadata.p2_1, rand_num2);
        hdr.msg[0].content = lin_comb;
        action_GF_arithmetic(meta.rlnc_metadata.p1_2, rand_num1, meta.rlnc_metadata.p2_2, rand_num2);
        hdr.msg[1].content = lin_comb;

        // SALVO: if you code the coefficients too, then it means you are recoding
        action_GF_arithmetic(meta.rlnc_metadata.c1_1, rand_num1, meta.rlnc_metadata.c2_1, rand_num2);
        hdr.coeff[0].coeff = lin_comb;
        action_GF_arithmetic(meta.rlnc_metadata.c1_2, rand_num1, meta.rlnc_metadata.c2_2, rand_num2);
        hdr.coeff[1].coeff = lin_comb;
    }

    // Changes the type of the packet to a value of 3, which indicates that
    // the packet is either coded or recoded
    action action_systematic_to_coded() {
    	hdr.rlnc.type = TYPE_CODED_OR_RECODED;
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
		// TODO: make this behavior customazible from the control-plane. For ex., you may decided to either forward uncoded packets or drop them waiting for the current generation's buffer to fill
    	table_forward.apply();

        if(hdr.rlnc.isValid()) {
            // loading the buffer index for the current generation
            index_per_generation.read(gen_index, gen_id);
            // loading the number of slots that were already reserved by all generations so far (circular buffer to reuse space across diff generations)
            slots_reserved_buffer.read(slots_reserved_value, 0);

            // if it's the first time seeing a particular generation
            // the index in which to store the first packet of this new generation is based on the buffer free space
            if(gen_index == 0) {
                starting_index_of_generation = slots_reserved_value % MAX_BUF_SIZE;
                // if the computed index it's reserved already then that generation will not be
                // coded, yet simply forwarded.
                reserved_space.read(reserved_space_value, starting_index_of_generation);
                if(reserved_space_value == 1) {
                    // This returns assures that all of the following computation will
                    // not be executed, as is intended
                    return;
                }
                gen_index = starting_index_of_generation;
                starting_index_of_generation_buffer.write(gen_id, starting_index_of_generation);
                // We mark the slot of that starting index of the generation as reserved_space
                // so that future generation won't be able to overwrite the current one
                reserved_space.write(starting_index_of_generation, 1);
                slots_reserved_buffer.write(0, slots_reserved_value + gen_size);
            }

            // Using the generation index to save to the registers the packet contents
            action_write();

            // incrementing the gen_index
            action_update_buffer_index();

            // Coding iff num of stored symbols for the current generation is  equal to generation size
            if(gen_index-starting_index_of_generation >= GEN_SIZE) {
                action_code_packet();
                // updating packet type
                action_systematic_to_coded();
            }
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {

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
