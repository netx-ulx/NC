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

    register<bit<8>>(3) mult_args;

    action action_ff_mult_aux() {
        bit<8> a = 0;
        bit<8> b = 0;
        bit<8> result = 0;
        mult_args.read(a, 0);
        mult_args.read(b, 1);
        mult_args.read(result, 2);
        bit<8> low_bit_flag = b & 0x1;

        if (low_bit_flag != 0){
            result = result ^ a;
        }

       bit<8> high_bit_flag = a & HIGH_BIT_MASK;

        a = a << 1;
        b = b >> 1;

        if (high_bit_flag != 0){
            a = a ^ IRRED_POLY;
        }
        mult_args.write(0,a);
        mult_args.write(1,b);
        mult_args.write(2,result);
    }

    action action_ff_mult() {
        action_ff_mult_aux();
        action_ff_mult_aux();
        action_ff_mult_aux();
        action_ff_mult_aux();
        action_ff_mult_aux();
        action_ff_mult_aux();
        action_ff_mult_aux();
        action_ff_mult_aux();
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
            mult_args.write(0,hdr.ff_calc.a);
            mult_args.write(1,hdr.ff_calc.b);
            mult_args.write(2,hdr.ff_calc.result);
            action_ff_mult();
            mult_args.read(hdr.ff_calc.result,2);
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
