/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/
#include "constants.p4"


header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header rlnc_t {
    bit<2> type;
    bit<6> symbols;
    bit<8> generation;
    bit<8> encoder_rank;
}
header coeff_t {
    bit<GF_BYTES> coeff;
}

header msg_t {
    bit<GF_BYTES> content;
}

struct parser_metadata_t {
    bit<8>  remaining_coeff;
    bit<6>  remaining_msg;
}



//The metadata to manipulate the symbols and coefficients of the packets
struct rlnc_metadata_t {
    bit<GF_BYTES>   p1_1;
    bit<GF_BYTES>   p1_2;

    bit<GF_BYTES>   p2_1;
    bit<GF_BYTES>   p2_2;

    bit<GF_BYTES>   c1_1;
    bit<GF_BYTES>   c1_2;

    bit<GF_BYTES>   c2_1;
    bit<GF_BYTES>   c2_2;
}

struct metadata {
    parser_metadata_t       parser_metadata;
    rlnc_metadata_t         rlnc_metadata;
}

struct headers {
    ethernet_t          ethernet;
    rlnc_t              rlnc;
    coeff_t[GEN_SIZE]   coeff;
    msg_t[PAY_SIZE]     msg;
}
