/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>
#include "includes/headers.p4"
#include "includes/parser.p4"
#include "includes/deparser.p4"
#include "includes/registers.p4"

//The irreducible polynomial choosen to be used in the multiplication operation
#define IRRED_POLY 0x11b

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

    // For the online arithmetic.
    // The indexing functions as follows:
    // 0-5: These indexes store the 3 pairs of values that are multiplied together
    // 6-8: These indedes store the result of each multiplication of the 3 pairs
    // 9: Finally in this last index is the result of adding the 3 products together
    register<bit<8>>(10)		    arithmetic_args;

    action action_forward(egressSpec_t port) {
      standard_metadata.egress_spec = port;
    }

    // Updates the packet buffer index each time a new packet arrives
    action action_update_buffer_index() {
        buf_index.write(0, meta.coding_metadata.buf_index + 1);
        buf_index.read(meta.coding_metadata.buf_index, 0);
    }

    // When a generation is fully decoded it's time to advance to the next generation
    action action_step_to_next_gen() {
        gen_current.write(0, meta.coding_metadata.gen_current + 1);
        gen_current.read(meta.coding_metadata.gen_current, 0);
    }

    // Buffers the symbols and coefficients to the respective indexes
    action action_write() {
        buf_index.read(meta.coding_metadata.buf_index, 0);
        buf_c1.write(meta.coding_metadata.buf_index, hdr.coeff[0].coeff);
        buf_c2.write(meta.coding_metadata.buf_index, hdr.coeff[1].coeff);
        buf_c3.write(meta.coding_metadata.buf_index, hdr.coeff[2].coeff);
        buf_p1.write(meta.coding_metadata.buf_index, hdr.msg[0].content);
        buf_p2.write(meta.coding_metadata.buf_index, hdr.msg[1].content);
    }

    //Loads a coefficient and a symbol from the provided index to metadata
    action action_load_to_pkt(bit<32> idx) {
        buf_c1.read(meta.rlnc_metadata.c1_1, idx);
        buf_c2.read(meta.rlnc_metadata.c1_2, idx);
        buf_c3.read(meta.rlnc_metadata.c1_3, idx);

        buf_p1.read(meta.rlnc_metadata.p1_1, idx);
        buf_p2.read(meta.rlnc_metadata.p1_2, idx);

    }

    //Enables coding through a flag
    action action_load_nc_metadata(bit<1> nc_flag, bit<1> gen_flag) {
        meta.coding_metadata.nc_enabled_flag = nc_flag;
        meta.coding_metadata.gen_current_flag = gen_flag;
    }

    action action_set_gen_current() {
        gen_current.write(0, hdr.rlnc.generation);
        gen_current_flag.write(0, 1);
    }

    action action_load_gen_metadata() {
        gen_current.read(meta.coding_metadata.gen_current, 0);
        gen_current_flag.read(meta.coding_metadata.gen_current_flag, 0);
    }

    // GF Addition Arithmetic Operation of the 3 products
    action action_GF_add(bit<GF_BYTES> a, bit<GF_BYTES> b, bit<GF_BYTES> c) {
        arithmetic_args.write(9, a ^ b ^ c);
    }

    // Shift-and-Add method to perform multiplication
    // There are 3 pairs of values being multiplied at the same time, that's why
    // there are x1,...,x3 and y1,...,y3 which are the values that are going to be multiplied
    // Then we have result1,...,result3 where the product is going to be stored in
    // Since we perform this action multiple times we need to buffer the resulting values in
    // registers to pass it over to the next iteration. To do so we read the value that is present
    // in the register at the moment and when all operations are done we write the resulting values
    // to the registers.
    action action_ffmult_iteration() {
        bit<8> x1 = 0;
        bit<8> y1 = 0;
        bit<8> x2 = 0;
        bit<8> y2 = 0;
        bit<8> x3 = 0;
        bit<8> y3 = 0;
        bit<8> result1 = 0;
        bit<8> result2 = 0;
        bit<8> result3 = 0;
        arithmetic_args.read(x1, 0);
        arithmetic_args.read(y1, 1);
        arithmetic_args.read(x2, 2);
        arithmetic_args.read(y2, 3);
        arithmetic_args.read(x3, 4);
        arithmetic_args.read(y3, 5);
        arithmetic_args.read(result1, 6);
        arithmetic_args.read(result2, 7);
        arithmetic_args.read(result3, 8);
        if(y1 & 1 == 1) {
        	result1 = result1 ^ x1;
        }
        if(x1 >= 128) {
        	x1 = (x1 << 1) ^ IRRED_POLY;
        }else{
        	x1 = x1 << 1;
        }
        y1 = y1 >> 1;

        if(y2 & 1 == 1) {
        	result2 = result2 ^ x2;
        }
        if(x2 >= 128) {
        	x2 = (x2 << 1) ^ IRRED_POLY;
        }else{
        	x2 = x2 << 1;
        }
        y2 = y2 >> 1;

        if(y3 & 1 == 1) {
        	result3 = result3 ^ x3;
        }
        if(x3 >= 128) {
        	x3 = (x3 << 1) ^ IRRED_POLY;
        }else{
        	x3 = x3 << 1;
        }
        y3 = y3 >> 1;
        arithmetic_args.write(0,x1);
        arithmetic_args.write(1,y1);
        arithmetic_args.write(2,x2);
        arithmetic_args.write(3,y2);
        arithmetic_args.write(4,x3);
        arithmetic_args.write(5,y3);
        arithmetic_args.write(6,result1);
        arithmetic_args.write(7,result2);
        arithmetic_args.write(8,result3);
    }
    
    // GF Multiplication Arithmetic Operation
    // First we initialise the values into the respective register
    // Then we perform the same action 8 times, for each bit, to perform multiplication.
    // Finally we load the results to metadata to perform addition later on
    action action_GF_mult(bit<GF_BYTES> x1, bit<GF_BYTES> y1, bit<GF_BYTES> x2, bit<GF_BYTES> y2, bit<GF_BYTES> x3, bit<GF_BYTES> y3) {
        arithmetic_args.write(0,x1);
        arithmetic_args.write(1,y1);
        arithmetic_args.write(2,x2);
        arithmetic_args.write(3,y2);
        arithmetic_args.write(4,x3);
        arithmetic_args.write(5,y3);
        arithmetic_args.write(6,0);
        arithmetic_args.write(7,0);
        arithmetic_args.write(8,0);
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        arithmetic_args.read(meta.arithmetic_metadata.mult_result_1,6);
        arithmetic_args.read(meta.arithmetic_metadata.mult_result_2,7);
        arithmetic_args.read(meta.arithmetic_metadata.mult_result_3,8);


    }

    //Bellow we find similiar actions but with a different number of arguments.
    //If the action has a lower number of arguments then it will call action_GF_add or action_GF_mult and padd the rest with zeros
    //This is done so that the code won't grow larger than it is
    action action_GF_add_1(bit<GF_BYTES> x1, bit<GF_BYTES> x2) {
        action_GF_add(x1, x2, 0);
    }

    action action_GF_add_2(bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3) {
        action_GF_add(x1, x2, x3);
    }

    action action_GF_mult_1(bit<GF_BYTES> x1, bit<GF_BYTES> x2) {	
        action_GF_mult(x1, x2, 0, 0, 0, 0);
    }

    action action_GF_mult_2(bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3, bit<GF_BYTES> x4) {
        action_GF_mult(x1, x2, x3, x4, 0, 0);
    }

    action action_GF_mult_3(bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3, bit<GF_BYTES> x4, bit<GF_BYTES> x5, bit<GF_BYTES> x6) {
        action_GF_mult(x1, x2, x3, x4, x5, x6);
    }

    // This action is called when only 1 packet is available for coding
    action action_recode_1() {
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MOD;
        bit<GF_BYTES> rand_num1 = 0;
        random(rand_num1, low, high);


        // Load Packets to Metadata
        action_load_to_pkt(0);

        // Update packet’s PAYLOAD
        action_GF_mult_1(rand_num1, meta.rlnc_metadata.p1_1);
        hdr.msg[0].content = meta.arithmetic_metadata.mult_result_1;

        action_GF_mult_1(rand_num1, meta.rlnc_metadata.p1_2);
        hdr.msg[1].content = meta.arithmetic_metadata.mult_result_1;

        // Update packet's COEFFICIENTS
        action_GF_mult_1(rand_num1, meta.rlnc_metadata.c1_1);
        hdr.coeff[0].coeff = meta.arithmetic_metadata.mult_result_1;

        action_GF_mult_1(rand_num1, meta.rlnc_metadata.c1_2);
        hdr.coeff[1].coeff = meta.arithmetic_metadata.mult_result_1;

        action_GF_mult_1(rand_num1, meta.rlnc_metadata.c1_3);
        hdr.coeff[2].coeff = meta.arithmetic_metadata.mult_result_1;
    }

    // This action is called when only 2 packets are available for coding
    action action_recode_2() {
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MOD;
        bit<GF_BYTES> rand_num1 = 0;
        bit<GF_BYTES> rand_num2 = 0;
        random(rand_num1, low, high);
        random(rand_num2, low, high);


        // Load Packets to Metadata
        action_load_to_pkt(0);
        action_load_to_pkt(1);

        // Update packet’s PAYLOAD
        action_GF_mult_2(rand_num1, meta.rlnc_metadata.p1_1, rand_num2, meta.rlnc_metadata.p2_1);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        arithmetic_args.read(hdr.msg[0].content, 9);

        action_GF_mult_2(rand_num1, meta.rlnc_metadata.p1_2, rand_num2, meta.rlnc_metadata.p2_2);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        arithmetic_args.read(hdr.msg[1].content, 9);

        // Update packet's COEFFICIENTS
        action_GF_mult_2(rand_num1, meta.rlnc_metadata.c1_1, rand_num2, meta.rlnc_metadata.c2_1);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);


        arithmetic_args.read(hdr.coeff[0].coeff, 9);

        action_GF_mult_2(rand_num1, meta.rlnc_metadata.c1_2, rand_num2, meta.rlnc_metadata.c2_2);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        arithmetic_args.read(hdr.coeff[1].coeff, 9);

        action_GF_mult_2(rand_num1, meta.rlnc_metadata.c1_3, rand_num2, meta.rlnc_metadata.c2_3);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        arithmetic_args.read(hdr.coeff[2].coeff, 9);

    }

    // This action is called when 3 packets are available for coding
    action action_recode_3() {
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MOD;
        bit<GF_BYTES> rand_num1 = 0;
        bit<GF_BYTES> rand_num2 = 0;
        bit<GF_BYTES> rand_num3 = 0;
        random(rand_num1, low, high);
        random(rand_num2, low, high);
        random(rand_num3, low, high);

        // Load Packets to Metadata
        action_load_to_pkt(0);
        action_load_to_pkt(1);
        action_load_to_pkt(2);

        // Update packet’s PAYLOAD
        action_GF_mult_3(rand_num1, meta.rlnc_metadata.p1_1,
                         rand_num2, meta.rlnc_metadata.p2_1,
                         rand_num3, meta.rlnc_metadata.p3_1);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        arithmetic_args.read(hdr.msg[0].content, 9);

        action_GF_mult_3(rand_num1, meta.rlnc_metadata.p1_2,
                         rand_num2, meta.rlnc_metadata.p2_2,
                         rand_num3, meta.rlnc_metadata.p3_2);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        arithmetic_args.read(hdr.msg[1].content, 9);

        // Update packet's COEFFICIENTS
        action_GF_mult_3(rand_num1, meta.rlnc_metadata.c1_1,
                         rand_num2, meta.rlnc_metadata.c2_1,
                         rand_num3, meta.rlnc_metadata.c3_1);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);


        arithmetic_args.read(hdr.coeff[0].coeff, 9);

        action_GF_mult_3(rand_num1, meta.rlnc_metadata.c1_2,
                         rand_num2, meta.rlnc_metadata.c2_2,
                         rand_num3, meta.rlnc_metadata.c3_2);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        arithmetic_args.read(hdr.coeff[1].coeff, 9);

        action_GF_mult_3(rand_num1, meta.rlnc_metadata.c1_3,
                         rand_num2, meta.rlnc_metadata.c2_3,
                         rand_num3, meta.rlnc_metadata.c3_3);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        arithmetic_args.read(hdr.coeff[2].coeff, 9);

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
        if(meta.coding_metadata.nc_enabled_flag == 1) {


            if(meta.coding_metadata.gen_current_flag == 0) {
                action_set_gen_current();
            }

            action_load_gen_metadata();

            if(hdr.rlnc.type == TYPE_DATA && hdr.rlnc.generation == meta.coding_metadata.gen_current) {
                if(meta.coding_metadata.buf_index <= BUF_SIZE) {
                    action_write();
                    action_update_buffer_index();
                }

                if(meta.coding_metadata.buf_index == 1) {
                    action_recode_1();
                }

                else if(meta.coding_metadata.buf_index == 2) {
                    action_recode_2();
                }
                else if(meta.coding_metadata.buf_index == 3) {
                    action_recode_3();
                }
            }
            else if(hdr.rlnc.type == TYPE_ACK && hdr.rlnc.generation == meta.coding_metadata.gen_current) {
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
