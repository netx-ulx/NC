/* Some tips to implement your circular buffer. To make it easier to implement, let's assume the following things (even though some are very stupid/inefficient choices):
- when there is no space to store a new generation, drop the packet
- information about the same generation (coeff and smbols) is always stored in consecutive cells
- the gen_size is fixed and it's the same for all the processed generations
Then, try to use a single register for all the symbols, likewise for the coefficients
MEMO: you cannot use the mod operation since that is not supported, so try to implement a different mechanism to keep track of free positions in the buffer.
*/
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
