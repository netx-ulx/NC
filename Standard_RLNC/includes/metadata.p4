struct clone_metadata_t {
    bit<8> gen_symbol_index;
    bit<8> starting_gen_symbol_index;
    bit<8> starting_gen_coeff_index;
}



//The metadata to manipulate the symbols and coefficients of the packets
struct rlnc_metadata_t {
    bit<GF_BYTES>   s1;
    bit<GF_BYTES>   s2;

    bit<GF_BYTES>   s3;
    bit<GF_BYTES>   s4;
}

struct metadata {
    rlnc_metadata_t         rlnc_metadata;
    clone_metadata_t        clone_metadata;
    bit<16> coeffs;
	bit<6> symbols;
	bit<32> tmp;
}
