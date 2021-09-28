/*
The coding scheme here implemented is a variant of the standard RLNC, called Sparse RLNC with Incremental Density. The density indicates the number of packets used as input to the encoding/recoding process. This differ from the standard RLNC where the generation size is always used as number of packets for any encoding/recoding operation.
*/

/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>
#include "includes/headers.p4"
#include "includes/parser.p4"
#include "includes/deparser.p4"
#include "includes/registers.p4"

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

    // The LOG table
    register<bit<32>>(GF_BITS)          GF256_log;
    // The ANTILOG table
    register<bit<GF_BYTES>>(1025)       GF256_invlog;

    // For the random algorithm
    register<bit<32>>(MAX_BUF_SIZE)	    rng_array;

    action action_forward(egressSpec_t port) {
      standard_metadata.egress_spec = port;
    }

    action action_update_buffer_index() {
        buf_index.write(0, meta.coding.buf_index + 1);
        buf_index.read(meta.coding.buf_index, 0);
    }

    action action_step_to_next_gen() {
        gen_current.write(0, meta.coding.gen_current + 1);
        gen_current.read(meta.coding.gen_current, 0);
    }


    action action_load_to_pkt_1 (bit<32> idx) {
        buf_c1.read(meta.rlnc_metadata.c1_1, idx);
        buf_c2.read(meta.rlnc_metadata.c1_2, idx);
        buf_c3.read(meta.rlnc_metadata.c1_3, idx);

        buf_p1.read(meta.rlnc_metadata.p1_1, idx);
        buf_p2.read(meta.rlnc_metadata.p1_2, idx);

    }

    action action_load_to_pkt_2 (bit<32> idx) {
        buf_c1.read(meta.rlnc_metadata.c2_1, idx);
        buf_c2.read(meta.rlnc_metadata.c2_2, idx);
        buf_c3.read(meta.rlnc_metadata.c2_3, idx);

        buf_p1.read(meta.rlnc_metadata.p2_1, idx);
        buf_p2.read(meta.rlnc_metadata.p2_2, idx);

    }

    action action_load_to_pkt_3 (bit<32> idx) {
        buf_c1.read(meta.rlnc_metadata.c3_1, idx);
        buf_c2.read(meta.rlnc_metadata.c3_2, idx);
        buf_c3.read(meta.rlnc_metadata.c3_3, idx);

        buf_p1.read(meta.rlnc_metadata.p3_1, idx);
        buf_p2.read(meta.rlnc_metadata.p3_2, idx);

    }




    action action_write() {
        buf_index.read(meta.coding.buf_index, 0);
        buf_c1.write(meta.coding.buf_index, hdr.coeff[0].coeff);
        buf_c2.write(meta.coding.buf_index, hdr.coeff[1].coeff);
        buf_c3.write(meta.coding.buf_index, hdr.coeff[2].coeff);
        buf_p1.write(meta.coding.buf_index, hdr.msg[0].content);
        buf_p2.write(meta.coding.buf_index, hdr.msg[1].content);
    }

    action action_overwrite() {
        bit<32> low = 0;
        bit<32> high = (bit<32>) meta.coding.buf_index - 1;
        random(meta.coding.buf_index_r, low, high);

        buf_index.read(meta.coding.buf_index_r, 0);
        buf_c1.write(meta.coding.buf_index_r, hdr.coeff[0].coeff);
        buf_c2.write(meta.coding.buf_index_r, hdr.coeff[1].coeff);
        buf_c3.write(meta.coding.buf_index_r, hdr.coeff[2].coeff);
        buf_p1.write(meta.coding.buf_index_r, hdr.msg[0].content);
        buf_p2.write(meta.coding.buf_index_r, hdr.msg[1].content);

    }

    action action_rng_random_idx() {
    	bit<32> low = 0;
        bit<32> high = (bit<32>) meta.random_metadata.rng_idx_max;
    	random(meta.random_metadata.rng_idx_rng, low, high);
    }

    action action_rng_swap() {
    	rng_array.read(meta.random_metadata.rng_num_at_idx, meta.random_metadata.rng_idx_rng);
    	rng_array.read(meta.random_metadata.rng_num_at_max, meta.random_metadata.rng_idx_max);

    	rng_array.write(meta.random_metadata.rng_idx_rng, meta.random_metadata.rng_num_at_max);
    	rng_array.write(meta.random_metadata.rng_idx_max, meta.random_metadata.rng_num_at_idx);
    }

    action action_rng_update_max() {
    	meta.random_metadata.rng_idx_max = meta.random_metadata.rng_idx_max - 1;
    }

    action action_rng_random_1() {
    	action_rng_random_idx();
    	action_rng_swap();
    	rng_array.read(meta.random_metadata.rng_result_1, meta.random_metadata.rng_num_at_max);

    	action_rng_update_max();
    }

    action action_rng_random_2() {
    	action_rng_random_idx();
    	action_rng_swap();
    	rng_array.read(meta.random_metadata.rng_result_2, meta.random_metadata.rng_num_at_max);

    	action_rng_update_max();

    	action_rng_random_1();
    	
    }

    action action_rng_random_3() {
    	action_rng_random_idx();
    	action_rng_swap();
    	rng_array.read(meta.random_metadata.rng_result_3, meta.random_metadata.rng_num_at_max);

    	action_rng_update_max();

    	action_rng_random_2();
    	
    }

    action action_rng_init() {
    	// Create array for indexes [0, MAX_BUF_SIZE]
    	rng_array.write(0,0);
    	rng_array.write(1,1);
    	rng_array.write(2,2);
    	rng_array.write(3,3);
    	rng_array.write(4,4);
    	rng_array.write(5,5);
    	rng_array.write(6,6);
    	rng_array.write(7,7);
    	rng_array.write(8,8);
    	rng_array.write(9,9);

    	meta.random_metadata.rng_idx_max = meta.coding.buf_index - 1;

    	action_rng_random_3();
    }

    // GF Addition Arithmetic Operation
    action action_GF_add(bit<GF_BYTES> a, bit<GF_BYTES> b) {
        meta.arithmetic_metadata.add_result = (a ^ b);
    }

    // GF Multiplication Arithmetic Operation
    action action_GF_mult(bit<GF_BYTES> a, bit<GF_BYTES> b) {
        bit<32> log1 = 0;
        bit<32> log2 = 0;
        GF256_log.read(log1, (bit<32>) a);
        GF256_log.read(log2, (bit<32>) b);
        bit<32> add_a = (bit<32>) log1;
        bit<32> add_b = (bit<32>) log2;
        bit<32> result = add_a + add_b;
        GF256_invlog.read(meta.arithmetic_metadata.invlog, result);

    }

    // GF Addition: Cumulative Loop
    action action_GF_add_1(bit<GF_BYTES> x1, bit<GF_BYTES> x2) {
        action_GF_add(x1, x2);
        meta.arithmetic_metadata.add_result_1 = meta.arithmetic_metadata.add_result;
    }

    action action_GF_add_2(bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3) {
        action_GF_add_1(x1, x2);
        action_GF_add(meta.arithmetic_metadata.add_result_1, x3);
        meta.arithmetic_metadata.add_result_2 = meta.arithmetic_metadata.add_result;
    }

    // GF Multiplication: Pairing Loop
    action action_GF_mult_1(bit<GF_BYTES> x1, bit<GF_BYTES> x2) {	
        action_GF_mult(x1, x2);
        meta.arithmetic_metadata.mult_result_1 = meta.arithmetic_metadata.invlog;
    }

    action action_GF_mult_2(bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3, bit<GF_BYTES> x4) {
        action_GF_mult_1(x1, x2);
        action_GF_mult(x3, x4);
        meta.arithmetic_metadata.mult_result_2 = meta.arithmetic_metadata.invlog;
    }

    action action_GF_mult_3(bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3, bit<GF_BYTES> x4, bit<GF_BYTES> x5, bit<GF_BYTES> x6) {
        action_GF_mult_2(x1, x2, x3, x4);
        action_GF_mult(x5, x6);
        meta.arithmetic_metadata.mult_result_3 = meta.arithmetic_metadata.invlog;
    }

    action action_recode_1() {
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MOD;
        random(meta.arithmetic_metadata.rng_c1, low, high);


        // Load Packets to Metadata
        action_load_to_pkt_1(0);

        // Update packet’s PAYLOAD
        action_GF_mult_1(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.p1_1);
        hdr.msg[0].content = meta.arithmetic_metadata.mult_result_1;

        action_GF_mult_1(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.p1_2);
        hdr.msg[1].content = meta.arithmetic_metadata.mult_result_1;

        // Update packet's COEFFICIENTS
        action_GF_mult_1(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_1);
        hdr.coeff[0].coeff = meta.arithmetic_metadata.mult_result_1;

        action_GF_mult_1(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_2);
        hdr.coeff[1].coeff = meta.arithmetic_metadata.mult_result_1;

        action_GF_mult_1(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_3);
        hdr.coeff[2].coeff = meta.arithmetic_metadata.mult_result_1;
    }

    action action_recode_2() {
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MOD;
        random(meta.arithmetic_metadata.rng_c1, low, high);
        random(meta.arithmetic_metadata.rng_c2, low, high);


        // Load Packets to Metadata
        action_load_to_pkt_1(0);
        action_load_to_pkt_2(1);

        // Update packet’s PAYLOAD
        action_GF_mult_2(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.p1_1, meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.p2_1);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        hdr.msg[0].content = meta.arithmetic_metadata.add_result_1;

        action_GF_mult_2(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.p1_2, meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.p2_2);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        hdr.msg[1].content = meta.arithmetic_metadata.add_result_1;

        // Update packet's COEFFICIENTS
        action_GF_mult_2(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_1, meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.c2_1);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        
        hdr.coeff[0].coeff = meta.arithmetic_metadata.add_result_1;

        action_GF_mult_2(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_2, meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.c2_2);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        hdr.coeff[1].coeff = meta.arithmetic_metadata.add_result_1;

        action_GF_mult_2(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_3, meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.c2_3);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        hdr.coeff[2].coeff = meta.arithmetic_metadata.add_result_1;

    }

    action action_recode_3() {
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MOD;
        random(meta.arithmetic_metadata.rng_c1, low, high);
        random(meta.arithmetic_metadata.rng_c2, low, high);
        random(meta.arithmetic_metadata.rng_c3, low, high);

        // Load Packets to Metadata
        action_load_to_pkt_1(0);
        action_load_to_pkt_2(1);
        action_load_to_pkt_3(2);

        // Update packet’s PAYLOAD
        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.p1_1,
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.p2_1,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.p3_1);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        hdr.msg[0].content = meta.arithmetic_metadata.add_result_2;

        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.p1_2, 
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.p2_2,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.p3_2);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        hdr.msg[1].content = meta.arithmetic_metadata.add_result_2;

        // Update packet's COEFFICIENTS
        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_1,
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.c2_1,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.c3_1);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        
        hdr.coeff[0].coeff = meta.arithmetic_metadata.add_result_2;

        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_2,
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.c2_2,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.c3_2);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        hdr.coeff[1].coeff = meta.arithmetic_metadata.add_result_2;

        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_3,
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.c2_3,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.c3_3);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        hdr.coeff[2].coeff = meta.arithmetic_metadata.add_result_2;

    }

    action action_recode_r() {
    	bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MOD;
        random(meta.arithmetic_metadata.rng_c1, low, high);
        random(meta.arithmetic_metadata.rng_c2, low, high);
        random(meta.arithmetic_metadata.rng_c3, low, high);

        action_rng_init();
        action_load_to_pkt_1(meta.random_metadata.rng_result_1);
        action_load_to_pkt_2(meta.random_metadata.rng_result_2);
        action_load_to_pkt_3(meta.random_metadata.rng_result_3);

        // Update packet’s PAYLOAD
        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.p1_1,
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.p2_1,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.p3_1);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        hdr.msg[0].content = meta.arithmetic_metadata.add_result_2;

        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.p1_2, 
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.p2_2,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.p3_2);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        hdr.msg[1].content = meta.arithmetic_metadata.add_result_2;

        // Update packet's COEFFICIENTS
        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_1,
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.c2_1,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.c3_1);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        
        hdr.coeff[0].coeff = meta.arithmetic_metadata.add_result_2;

        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_2,
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.c2_2,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.c3_2);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        hdr.coeff[1].coeff = meta.arithmetic_metadata.add_result_2;

        action_GF_mult_3(meta.arithmetic_metadata.rng_c1, meta.rlnc_metadata.c1_3,
                         meta.arithmetic_metadata.rng_c2, meta.rlnc_metadata.c2_3,
                         meta.arithmetic_metadata.rng_c3, meta.rlnc_metadata.c3_3);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        hdr.coeff[2].coeff = meta.arithmetic_metadata.add_result_2;
    }

    action action_load_nc_metadata(bit<1> nc_flag, bit<1> gen_flag) {
        meta.coding.nc_enabled_flag = nc_flag;
        meta.coding.gen_current_flag = gen_flag;
    }

    action action_set_gen_current() {
        gen_current.write(0, hdr.rlnc.generation);
        gen_current.read(meta.coding.gen_current, 0);
        gen_current_flag.write(0, 1);
        gen_current_flag.read(meta.coding.gen_current_flag, 0);
    }

    table table_forward {
      key = {
        standard_metadata.ingress_port: exact;
      }
      actions = {
        action_forward;
      }
    }

    table table_load_1 {
        key = {
            hdr.rlnc.type: exact;
        }
        actions = {
            action_load_nc_metadata;
        }
    }



    apply {
        table_forward.apply();
        table_load_1.apply();
        if(meta.coding.nc_enabled_flag == 1) {

            action_set_gen_current();

            if(hdr.rlnc.type == TYPE_DATA && hdr.rlnc.generation == meta.coding.gen_current) {
                if(meta.coding.buf_index <= MAX_BUF_SIZE) {
                    action_write();
                    action_update_buffer_index();
                }
                else {
                    action_overwrite();
                }

                if(meta.coding.buf_index == 1) {
                    action_recode_1();
                }

                else if(meta.coding.buf_index == 2) {
                    action_recode_2();
                }
                else if(meta.coding.buf_index == 3) {
                    action_recode_3();
                }
            }
            else if(hdr.rlnc.type == TYPE_ACK && hdr.rlnc.generation == meta.coding.gen_current) {
                action_step_to_next_gen();
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
