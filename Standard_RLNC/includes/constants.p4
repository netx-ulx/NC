//Type of the packets
#define TYPE_ACK 0
#define TYPE_SYSTEMATIC 1
#define TYPE_CODED 2
#define TYPE_CODED_OR_RECODED 3
//The size for the log and antilog tables, max value of the field
#define GF_BITS 256
//The size of each element of the field
#define GF_BYTES 8
//Value used in the generation of the random coefficients
#define GF_MAX_VALUE 255
//The size of the generation
#define GEN_SIZE 2
//The number of symbols the packet carries
#define PAY_SIZE 2
//The maximum size of the buffer that store the packets contents
#define MAX_BUF_SIZE 4

const bit<16>  TYPE_CODING = 0x1234;
typedef bit<48> macAddr_t;
typedef bit<9>  egressSpec_t;
