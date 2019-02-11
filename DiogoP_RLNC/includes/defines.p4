#define TYPE_DATA 2
#define TYPE_ACK  3
#define GF_BITS 256
#define GF_BYTES 8
#define GF_MOD 255
#define GEN_SIZE 3
#define PAY_SIZE 2
#define BUF_SIZE 10

const bit<16>  TYPE_CODING = 0x1234;
typedef bit<48> macAddr_t;
typedef bit<9>  egressSpec_t;