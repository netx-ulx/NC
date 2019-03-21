struct clone_metadata_t {
    bit<8> gen_symbol_index;
    bit<8> starting_gen_symbol_index;
    bit<8> starting_gen_coeff_index;
}



struct metadata {
    clone_metadata_t        clone_metadata;
    bit<16> coeffs;
	bit<6> symbols;
	bit<32> tmp;
}
