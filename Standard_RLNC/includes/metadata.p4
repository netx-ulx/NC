struct clone_metadata_t {
    bit<32> gen_symbol_index;
    bit<32> starting_gen_symbol_index;
    bit<32> starting_gen_coeff_index;
    bit<8> n_packets_out;
    bit<8> coding_flag;
}

struct metadata {
    clone_metadata_t        clone_metadata;
    bit<16> coeffs;
	bit<6> symbols;
	bit<32> tmp;
    bit rlnc_enable;
}
