/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>


#define IRRED_POLY 0b100011101
#define HIGH_BIT_MASK 128

const bit<16>  TYPE_CODING = 0x1234;



/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;


header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ff_calc_t {
	bit<8> a;
	bit<8> b;
    bit<8> result;
}

struct arithmetic_metadata_t{
    bit<8>  a;
    bit<8>  b;
    bit<8>  result;
    bit<8>  low_bit_flag;
    bit<8>  high_bit_flag;
}

struct metadata {
    arithmetic_metadata_t   arithmetic_metadata;
}

struct headers {
    ethernet_t			ethernet;
    ff_calc_t			ff_calc;

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
            TYPE_CODING: parse_ff_calc;
            default: accept;
        }
    }

    state parse_ff_calc {
    	packet.extract(hdr.ff_calc);
        transition accept;
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

    action action_ff_mult_1() {
        meta.arithmetic_metadata.low_bit_flag = meta.arithmetic_metadata.b & 0x1;

        if (meta.arithmetic_metadata.low_bit_flag != 0){
            meta.arithmetic_metadata.result = meta.arithmetic_metadata.result ^ meta.arithmetic_metadata.a;
        }

       meta.arithmetic_metadata. high_bit_flag = meta.arithmetic_metadata.a & HIGH_BIT_MASK;

        meta.arithmetic_metadata.a = meta.arithmetic_metadata.a << 1;
        meta.arithmetic_metadata.b = meta.arithmetic_metadata.b >> 1;

        if (meta.arithmetic_metadata.high_bit_flag != 0){
            meta.arithmetic_metadata.a = meta.arithmetic_metadata.a ^ IRRED_POLY;
        }
    }

    action action_ff_mult_2() {
        meta.arithmetic_metadata.low_bit_flag = meta.arithmetic_metadata.b & 0x1;

        if (meta.arithmetic_metadata.low_bit_flag != 0){
            meta.arithmetic_metadata.result = meta.arithmetic_metadata.result ^ meta.arithmetic_metadata.a;
        }

       meta.arithmetic_metadata. high_bit_flag = meta.arithmetic_metadata.a & HIGH_BIT_MASK;

        meta.arithmetic_metadata.a = meta.arithmetic_metadata.a << 1;
        meta.arithmetic_metadata.b = meta.arithmetic_metadata.b >> 1;

        if (meta.arithmetic_metadata.high_bit_flag != 0){
            meta.arithmetic_metadata.a = meta.arithmetic_metadata.a ^ IRRED_POLY;
        }
    }

    action action_ff_mult_3() {
        meta.arithmetic_metadata.low_bit_flag = meta.arithmetic_metadata.b & 0x1;

        if (meta.arithmetic_metadata.low_bit_flag != 0){
            meta.arithmetic_metadata.result = meta.arithmetic_metadata.result ^ meta.arithmetic_metadata.a;
        }

       meta.arithmetic_metadata. high_bit_flag = meta.arithmetic_metadata.a & HIGH_BIT_MASK;

        meta.arithmetic_metadata.a = meta.arithmetic_metadata.a << 1;
        meta.arithmetic_metadata.b = meta.arithmetic_metadata.b >> 1;

        if (meta.arithmetic_metadata.high_bit_flag != 0){
            meta.arithmetic_metadata.a = meta.arithmetic_metadata.a ^ IRRED_POLY;
        }
    }

    action action_ff_mult_4() {
        meta.arithmetic_metadata.low_bit_flag = meta.arithmetic_metadata.b & 0x1;

        if (meta.arithmetic_metadata.low_bit_flag != 0){
            meta.arithmetic_metadata.result = meta.arithmetic_metadata.result ^ meta.arithmetic_metadata.a;
        }

       meta.arithmetic_metadata. high_bit_flag = meta.arithmetic_metadata.a & HIGH_BIT_MASK;

        meta.arithmetic_metadata.a = meta.arithmetic_metadata.a << 1;
        meta.arithmetic_metadata.b = meta.arithmetic_metadata.b >> 1;

        if (meta.arithmetic_metadata.high_bit_flag != 0){
            meta.arithmetic_metadata.a = meta.arithmetic_metadata.a ^ IRRED_POLY;
        }
    }

    action action_ff_mult_5() {
        meta.arithmetic_metadata.low_bit_flag = meta.arithmetic_metadata.b & 0x1;

        if (meta.arithmetic_metadata.low_bit_flag != 0){
            meta.arithmetic_metadata.result = meta.arithmetic_metadata.result ^ meta.arithmetic_metadata.a;
        }

       meta.arithmetic_metadata. high_bit_flag = meta.arithmetic_metadata.a & HIGH_BIT_MASK;

        meta.arithmetic_metadata.a = meta.arithmetic_metadata.a << 1;
        meta.arithmetic_metadata.b = meta.arithmetic_metadata.b >> 1;

        if (meta.arithmetic_metadata.high_bit_flag != 0){
            meta.arithmetic_metadata.a = meta.arithmetic_metadata.a ^ IRRED_POLY;
        }
    }

    action action_ff_mult_6() {
        meta.arithmetic_metadata.low_bit_flag = meta.arithmetic_metadata.b & 0x1;

        if (meta.arithmetic_metadata.low_bit_flag != 0){
            meta.arithmetic_metadata.result = meta.arithmetic_metadata.result ^ meta.arithmetic_metadata.a;
        }

       meta.arithmetic_metadata. high_bit_flag = meta.arithmetic_metadata.a & HIGH_BIT_MASK;

        meta.arithmetic_metadata.a = meta.arithmetic_metadata.a << 1;
        meta.arithmetic_metadata.b = meta.arithmetic_metadata.b >> 1;

        if (meta.arithmetic_metadata.high_bit_flag != 0){
            meta.arithmetic_metadata.a = meta.arithmetic_metadata.a ^ IRRED_POLY;
        }
    }

    action action_ff_mult_7() {
        meta.arithmetic_metadata.low_bit_flag = meta.arithmetic_metadata.b & 0x1;

        if (meta.arithmetic_metadata.low_bit_flag != 0){
            meta.arithmetic_metadata.result = meta.arithmetic_metadata.result ^ meta.arithmetic_metadata.a;
        }

       meta.arithmetic_metadata. high_bit_flag = meta.arithmetic_metadata.a & HIGH_BIT_MASK;

        meta.arithmetic_metadata.a = meta.arithmetic_metadata.a << 1;
        meta.arithmetic_metadata.b = meta.arithmetic_metadata.b >> 1;

        if (meta.arithmetic_metadata.high_bit_flag != 0){
            meta.arithmetic_metadata.a = meta.arithmetic_metadata.a ^ IRRED_POLY;
        }
    }

    action action_ff_mult_8() {
        meta.arithmetic_metadata.low_bit_flag = meta.arithmetic_metadata.b & 0x1;

        if (meta.arithmetic_metadata.low_bit_flag != 0){
            meta.arithmetic_metadata.result = meta.arithmetic_metadata.result ^ meta.arithmetic_metadata.a;
        }

       meta.arithmetic_metadata. high_bit_flag = meta.arithmetic_metadata.a & HIGH_BIT_MASK;

        meta.arithmetic_metadata.a = meta.arithmetic_metadata.a << 1;
        meta.arithmetic_metadata.b = meta.arithmetic_metadata.b >> 1;

        if (meta.arithmetic_metadata.high_bit_flag != 0){
            meta.arithmetic_metadata.a = meta.arithmetic_metadata.a ^ IRRED_POLY;
        }
    }

    action action_ff_mult() {
        action_ff_mult_1();
        action_ff_mult_2();
        action_ff_mult_3();
        action_ff_mult_4();
        action_ff_mult_5();
        action_ff_mult_6();
        action_ff_mult_7();
        action_ff_mult_8();
    }

    action action_forward(egressSpec_t port) {
      standard_metadata.egress_spec = port;
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
        table_forward.apply();
        if ((hdr.ff_calc.a == 0) || (hdr.ff_calc.b == 0)){
            hdr.ff_calc.result = 0;
        }else{
            meta.arithmetic_metadata.a = hdr.ff_calc.a;
            meta.arithmetic_metadata.b = hdr.ff_calc.b;
            meta.arithmetic_metadata.result = hdr.ff_calc.result;
            action_ff_mult();
            hdr.ff_calc.result = meta.arithmetic_metadata.result;
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
        packet.emit(hdr.ff_calc);
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
