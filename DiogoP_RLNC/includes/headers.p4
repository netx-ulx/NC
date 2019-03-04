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
    bit<8> type;
    bit<8> generation;
    //To keep track of the number of coefficients
    bit<8> count;
}

header coeff_t {
    bit<8> coeff;
}

header msg_t {
    bit<GF_BYTES> content;
}

struct parser_metadata_t {
    bit<8>  remaining_coeff;
    //bit<8>  remaining_msg;
}

struct coding_metadata_t {
    bit<1>          nc_enabled_flag;
    bit<32>         buf_index;
    bit<32>         buf_index_r;
    bit<8>          gen_current;
    bit<1>          gen_current_flag;

}

//The metadata to manipulate the symbols and coefficients of the packets
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

//Metadata to manipulate the values of the arithmetic operations
struct arithmetic_metadata_t {
    //The three random coefficients
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
}

//Metadata for the random choosing packet algorithm
struct random_metadata_t {
	bit<32>	rng_result_1;
	bit<32>	rng_result_2;
	bit<32>	rng_result_3;

	bit<32>	rng_idx_max;
	bit<32>	rng_idx_rng;

	bit<32>	rng_num_at_idx;
	bit<32>	rng_num_at_max;
}

struct metadata {
    parser_metadata_t       parser_metadata;
    coding_metadata_t       coding;
    rlnc_metadata_t         rlnc_metadata;
    arithmetic_metadata_t   arithmetic_metadata;
    random_metadata_t	    random_metadata;
}

struct headers {
    ethernet_t          ethernet;
    rlnc_t              rlnc;
    coeff_t[GEN_SIZE]   coeff;
    msg_t[PAY_SIZE]     msg;
}

