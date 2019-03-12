// Symbol buffers
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_symbols;

// Coefficient Buffers
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_coeffs;

//Stores and Dictates the index in which a payload from a specific generation should be stored to
register<bit<32>>(10) symbol_index_per_generation;

//Stores and Dictates the index in which a coefficient from a specific generation should be stored to
register<bit<32>>(10) coeff_index_per_generation;

//Buffers the starting index of each generation in the symbol buffer register
register<bit<32>>(10) starting_symbol_index_of_generation_buffer;

//Buffers the starting index of each generation in the coefficient buffer register
register<bit<32>>(10) starting_coeff_index_of_generation_buffer;

//Keeps track of the number of symbol slots reserved by all generations
register<bit<32>>(1) symbol_slots_reserved_buffer;

//Keeps track of the number of coefficients slots reserved by all generations
register<bit<32>>(1) coeff_slots_reserved_buffer;
