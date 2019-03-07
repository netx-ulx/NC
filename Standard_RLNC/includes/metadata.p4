struct clone_metadata_t {
    bit<8> gen_index;
    bit<8> starting_gen_index;
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
    rlnc_metadata_t         rlnc_metadata;
    clone_metadata_t        clone_metadata;
    bit<8> coeffs;
	bit<6> symbols;
	bit<32> tmp;
}
