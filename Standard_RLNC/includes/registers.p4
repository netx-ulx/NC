// Symbol buffers
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_symbols;

// Coefficient Buffers
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_coeffs;

//Stores and Dictates the index in which a payload from a specific generation should be stored to
register<bit<32>>(10) index_per_generation;

//Buffers the starting index of each generation in the payload_buffer register
register<bit<32>>(10) starting_index_of_generation_buffer;

//Keeps track of the number of slots reserved by all generations
register<bit<32>>(1) slots_reserved_buffer;
