//Type of the packets
#define TYPE_SYSTEMATIC 1
#define TYPE_CODED 2
#define TYPE_CODED_OR_RECODED 3

//The size for the log and antilog tables, max value of the field
#define GF_BITS 256
#define GF_BYTES 8
//Value used in the generation of the random coefficients
#define GF_MAX_VALUE 255
//The original value should be 283 for 2^8 and 69643 for 2^16. However, the value in here is the value then used by the algorithm since it computes with 8-bit fields or 16-bit fields
#define IRRED_POLY 27

//The maximum size of the buffer that store the packets contents
#define MAX_BUF_SIZE 1024

const bit<16>  TYPE_RLNC = 0x0809;
const bit<16>  TYPE_ACK = 0x0899;
#define MAX_COEFFS 100 // this const and the following MAX_SYMBOLS may always have the same value. So far I do not see a case where those values should be different.

// The following values are usually agreed upon a sender and a receiver and exchanged through an outer rlnc header like the ones defined in headers.p4. Yet, there might be parts of this p4 code where it could be necessary to have those values already defined. Therefore, I set them here for the time being.
#define MAX_SYMBOLS 100
#define SYMBOL_SIZE 8
