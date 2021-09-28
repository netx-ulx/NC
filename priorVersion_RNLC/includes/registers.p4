// Flags/Pointers
register<bit<32>>(1)                buf_index;
register<bit<8>>(1)                 gen_current;
register<bit<1>> (1)                gen_current_flag;

// Payload Buffers
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_p1;
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_p2;

// Coefficient Buffers
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_c1;
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_c2;
register<bit<GF_BYTES>>(MAX_BUF_SIZE)   buf_c3;


