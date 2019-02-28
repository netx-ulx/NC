// Payload buffers, one per symbol
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_s1;
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_s2;

// Coefficient Buffers, the numbers of coefficients buffers must
// be equal to the generation size
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_c1;
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_c2;

//Stores and Dictates the index in which a payload from a specific generation should be stored to
register<bit<32>>(10) index_per_generation;

//Buffers the starting index of each generation in the payload_buffer register
register<bit<32>>(10) starting_index_of_generation_buffer;

//Keeps track of the number of slots reserved by all generations
register<bit<32>>(1) slots_reserved_buffer;

//Dictates if there is enough space for the generation to be buffered in the payload_buffer register
register<bit<1>>(MAX_BUF_SIZE) reserved_space;
