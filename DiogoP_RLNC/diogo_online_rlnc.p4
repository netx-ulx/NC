/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>


const bit<16>  TYPE_CODING = 0x1234;

#define TYPE_DATA 2
#define TYPE_ACK  3

#define IRRED_POLY 0x11b
#define HIGH_BIT_MASK 128

#define GF_BITS 256
#define GF_BYTES 8
#define GF_MOD 255
#define GEN_SIZE 3
#define PAY_SIZE 2
#define BUF_SIZE 10
/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;


header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header rlnc_t {
    bit<8> type;
    bit<8> generation;
    bit<8> buf_index;
}

header coeff_counter_t {
    bit<8>     count;
}

header coeff_t {
    bit<8> coeff;
}

header msg_counter_t {
    bit<8>     count;
}

header msg_t {
    bit<GF_BYTES> content;
}

struct parser_metadata_t {
    bit<8>  remaining_coeff;
    bit<8>  remaining_msg;
}

struct coding_metadata_t {
    bit<1>          nc_enabled_flag;
    bit<32>         buf_index;
    bit<32>         buf_index_r;
    bit<8>          gen_current;
    bit<1>          gen_current_flag;

}

struct rlnc_metadata_t {
    bit<GF_BYTES>   p1_1;
    bit<GF_BYTES>   p1_2;
    bit<GF_BYTES>   p1_3;
    bit<GF_BYTES>   p1_4;

    bit<GF_BYTES>   p2_1;
    bit<GF_BYTES>   p2_2;
    bit<GF_BYTES>   p2_3;
    bit<GF_BYTES>   p2_4;

    bit<GF_BYTES>   p3_1;
    bit<GF_BYTES>   p3_2;
    bit<GF_BYTES>   p3_3;
    bit<GF_BYTES>   p3_4;

    bit<GF_BYTES>   c1_1;
    bit<GF_BYTES>   c1_2;
    bit<GF_BYTES>   c1_3;

    bit<GF_BYTES>   c2_1;
    bit<GF_BYTES>   c2_2;
    bit<GF_BYTES>   c2_3;

    bit<GF_BYTES>   c3_1;
    bit<GF_BYTES>   c3_2;
    bit<GF_BYTES>   c3_3;
}

struct arithmetic_metadata_t {
    bit<GF_BYTES>           rng_c1;
    bit<GF_BYTES>           rng_c2;
    bit<GF_BYTES>           rng_c3;
    // Multiplication: Pairs
    bit<GF_BYTES>           mult_result_1;
    bit<GF_BYTES>           mult_result_2;
    bit<GF_BYTES>           mult_result_3;
    // Multiplication: one result
    bit<GF_BYTES>           log1;
    bit<GF_BYTES>           log2;
    bit<GF_BYTES>           invlog;
    // Addition: one result
    bit<GF_BYTES>           add_result;
    // Addition: cumulative
    bit<GF_BYTES>           add_result_1;
    bit<GF_BYTES>           add_result_2;
    // Multiplication: Online
}



struct metadata {
    parser_metadata_t       parser_metadata;
    coding_metadata_t       coding_metadata;
    rlnc_metadata_t         rlnc_metadata;
    arithmetic_metadata_t   arithmetic_metadata;
}

struct headers {
    ethernet_t          ethernet;
    rlnc_t              rlnc;
    coeff_counter_t     coeff_counter;
    coeff_t[GEN_SIZE]   coeff;
    msg_t[PAY_SIZE]     msg;
}


/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_CODING: parse_rlnc;
            default: accept;
        }
    }

    state parse_rlnc {
        packet.extract(hdr.rlnc);
        transition parse_coeff_counter;
    }

    state parse_coeff_counter {
        packet.extract(hdr.coeff_counter);
        meta.parser_metadata.remaining_coeff = hdr.coeff_counter.count;
        transition parse_coeff;
    }

    state parse_coeff {
        packet.extract(hdr.coeff.next);
        meta.parser_metadata.remaining_coeff = meta.parser_metadata.remaining_coeff - 1;
        transition select(meta.parser_metadata.remaining_coeff) {
            0 : parse_msg;
            default: parse_coeff;
        } 
    }

    state parse_msg {
        packet.extract(hdr.msg.next);
        transition parse_msg;
    }

}

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

    // Flags/Pointers
    register<bit<32>>(1)                buf_index;
    register<bit<8>>(1)                 gen_current;
    register<bit<1>> (1)                gen_current_flag;
    
    // Payload Buffers
    register<bit<GF_BYTES>>(BUF_SIZE)   buf_p1;
    register<bit<GF_BYTES>>(BUF_SIZE)   buf_p2;

    // Coefficient Buffers
    register<bit<GF_BYTES>>(BUF_SIZE)   buf_c1;
    register<bit<GF_BYTES>>(BUF_SIZE)   buf_c2;
    register<bit<GF_BYTES>>(BUF_SIZE)   buf_c3;


    register<bit<8>>(6)					mult_args;
    register<bit<8>>(3)					mult_results;
    register<bit<8>>(1)					add_result;

    /*
    register<bit<8>>(1)                 mult_result_1;
    register<bit<8>>(1)                 mult_result_2;
    register<bit<8>>(1)                 mult_result_3;

    register<bit<8>>(1)                 add_result;
    register<bit<8>>(1)                 add_result_1;
    register<bit<8>>(1)                 add_result_2;
    */


    action action_forward(egressSpec_t port) {
      standard_metadata.egress_spec = port;
    }

    action action_update_buffer_index() {
        buf_index.write(0, meta.coding_metadata.buf_index + 1);
        buf_index.read(meta.coding_metadata.buf_index, 0);
    }

    action action_step_to_next_gen() {
        gen_current.write(0, meta.coding_metadata.gen_current + 1);
        gen_current.read(meta.coding_metadata.gen_current, 0);
    }

    action action_write() {
        buf_index.read(meta.coding_metadata.buf_index, 0);
        buf_c1.write(meta.coding_metadata.buf_index, hdr.coeff[0].coeff);
        buf_c2.write(meta.coding_metadata.buf_index, hdr.coeff[1].coeff);
        buf_c3.write(meta.coding_metadata.buf_index, hdr.coeff[2].coeff);
        buf_p1.write(meta.coding_metadata.buf_index, hdr.msg[0].content);
        buf_p2.write(meta.coding_metadata.buf_index, hdr.msg[1].content);
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

    // GF Addition Arithmetic Operation
    action action_GF_add(bit<GF_BYTES> a, bit<GF_BYTES> b, bit<GF_BYTES> c) {
        add_result.write(0, a ^ b ^ c);
    }

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
        mult_args.read(x1, 0);
        mult_args.read(y1, 1);
        mult_args.read(x2, 2);
        mult_args.read(y2, 3);
        mult_args.read(x3, 4);
        mult_args.read(y3, 5);
        mult_results.read(result1, 0);
        mult_results.read(result2, 1);
        mult_results.read(result3, 2);
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
        mult_args.write(0,x1);
        mult_args.write(1,y1);
        mult_args.write(2,x2);
        mult_args.write(3,y2);
        mult_args.write(4,x3);
        mult_args.write(5,y3);
        mult_results.write(0,result1);
        mult_results.write(1,result2);
        mult_results.write(2,result3);
    }
    
    // GF Multiplication Arithmetic Operation
    action action_GF_mult(bit<GF_BYTES> x1, bit<GF_BYTES> y1, bit<GF_BYTES> x2, bit<GF_BYTES> y2, bit<GF_BYTES> x3, bit<GF_BYTES> y3) {
        mult_args.write(0,x1);
        mult_args.write(1,y1);
        mult_args.write(2,x2);
        mult_args.write(3,y2);
        mult_args.write(4,x3);
        mult_args.write(5,y3);
        mult_results.write(0,0);
        mult_results.write(1,0);
        mult_results.write(2,0);
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        action_ffmult_iteration();
        mult_results.read(meta.arithmetic_metadata.mult_result_1,0);
        mult_results.read(meta.arithmetic_metadata.mult_result_2,1);
        mult_results.read(meta.arithmetic_metadata.mult_result_3,2);


    }

    // GF Addition: Cumulative Loop
    action action_GF_add_1(bit<GF_BYTES> x1, bit<GF_BYTES> x2) {
        action_GF_add(x1, x2, 0);
    }

    action action_GF_add_2(bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3) {
        action_GF_add(x1, x2, x3);
    }

    // GF Multiplication: Pairing Loop
    action action_GF_mult_1(bit<GF_BYTES> x1, bit<GF_BYTES> x2) {	
        action_GF_mult(x1, x2, 0, 0, 0, 0);
    }

    action action_GF_mult_2(bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3, bit<GF_BYTES> x4) {
        action_GF_mult(x1, x2, x3, x4, 0, 0);
    }

    action action_GF_mult_3(bit<GF_BYTES> x1, bit<GF_BYTES> x2, bit<GF_BYTES> x3, bit<GF_BYTES> x4, bit<GF_BYTES> x5, bit<GF_BYTES> x6) {
        action_GF_mult(x1, x2, x3, x4, x5, x6);
    }

    action action_recode_1() {
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MOD;
        bit<GF_BYTES> rand_num1 = 0;
        random(rand_num1, low, high);


        // Load Packets to Metadata
        action_load_to_pkt_1(0);

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

    action action_recode_2() {
        bit<GF_BYTES> low = 0;
        bit<GF_BYTES> high = GF_MOD;
        bit<GF_BYTES> rand_num1 = 0;
        bit<GF_BYTES> rand_num2 = 0;
        random(rand_num1, low, high);
        random(rand_num2, low, high);


        // Load Packets to Metadata
        action_load_to_pkt_1(0);
        action_load_to_pkt_2(1);

        // Update packet’s PAYLOAD
        action_GF_mult_2(rand_num1, meta.rlnc_metadata.p1_1, rand_num2, meta.rlnc_metadata.p2_1);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        add_result.read(hdr.msg[0].content, 0);

        action_GF_mult_2(rand_num1, meta.rlnc_metadata.p1_2, rand_num2, meta.rlnc_metadata.p2_2);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        add_result.read(hdr.msg[1].content, 0);

        // Update packet's COEFFICIENTS
        action_GF_mult_2(rand_num1, meta.rlnc_metadata.c1_1, rand_num2, meta.rlnc_metadata.c2_1);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        
        add_result.read(hdr.coeff[0].coeff, 0);

        action_GF_mult_2(rand_num1, meta.rlnc_metadata.c1_2, rand_num2, meta.rlnc_metadata.c2_2);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        add_result.read(hdr.coeff[1].coeff, 0);

        action_GF_mult_2(rand_num1, meta.rlnc_metadata.c1_3, rand_num2, meta.rlnc_metadata.c2_3);
        action_GF_add_1(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2);

        add_result.read(hdr.coeff[2].coeff, 0);

    }

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
        action_load_to_pkt_1(0);
        action_load_to_pkt_2(1);
        action_load_to_pkt_3(2);

        // Update packet’s PAYLOAD
        action_GF_mult_3(rand_num1, meta.rlnc_metadata.p1_1,
                         rand_num2, meta.rlnc_metadata.p2_1,
                         rand_num3, meta.rlnc_metadata.p3_1);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        add_result.read(hdr.msg[0].content, 0);

        action_GF_mult_3(rand_num1, meta.rlnc_metadata.p1_2, 
                         rand_num2, meta.rlnc_metadata.p2_2,
                         rand_num3, meta.rlnc_metadata.p3_2);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        add_result.read(hdr.msg[1].content, 0);

        // Update packet's COEFFICIENTS
        action_GF_mult_3(rand_num1, meta.rlnc_metadata.c1_1,
                         rand_num2, meta.rlnc_metadata.c2_1,
                         rand_num3, meta.rlnc_metadata.c3_1);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        
        add_result.read(hdr.coeff[0].coeff, 0);

        action_GF_mult_3(rand_num1, meta.rlnc_metadata.c1_2,
                         rand_num2, meta.rlnc_metadata.c2_2,
                         rand_num3, meta.rlnc_metadata.c3_2);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        add_result.read(hdr.coeff[1].coeff, 0);

        action_GF_mult_3(rand_num1, meta.rlnc_metadata.c1_3,
                         rand_num2, meta.rlnc_metadata.c2_3,
                         rand_num3, meta.rlnc_metadata.c3_3);
        action_GF_add_2(meta.arithmetic_metadata.mult_result_1, meta.arithmetic_metadata.mult_result_2, meta.arithmetic_metadata.mult_result_3);

        add_result.read(hdr.coeff[2].coeff, 0);

    }



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
            
            bit<32> tmp = 0;
            buf_index.read(tmp, 0);
            hdr.rlnc.buf_index = (bit<8>) tmp;
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
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.rlnc);
        packet.emit(hdr.coeff_counter);
        packet.emit(hdr.coeff);
        packet.emit(hdr.msg);
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
