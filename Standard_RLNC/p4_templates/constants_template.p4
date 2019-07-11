//Type of the packets
#define TYPE_SYSTEMATIC 1
#define TYPE_CODED_WSEED 2
#define TYPE_CODED_OR_RECODED 3

@
//The size for the log and antilog tables, max value of the field
#define GF_BITS BITS_PLACEHOLDER
#define GF_BYTES BYTES_PLACEHOLDER
//Value used in the generation of the random coefficients
#define GF_MAX_VALUE MAX_VALUE_PLACEHOLDER
//The original value should be 283 for 2^8 and 69643 for 2^16. However, the value in here is the value then used by the algorithm since it computes with 8-bit fields or 16-bit fields
#define IRRED_POLY IRRED_PLACEHOLDER
@
//The maximum size of the buffer that store the packets contents
#define MAX_BUF_SIZE 1024

const bit<16>  TYPE_RLNC = 0x0809;
const bit<16>  TYPE_ACK = 0x0899;
#define MAX_COEFFS 100 // this const and the following MAX_SYMBOLS do not hold the same value, since a coding vector of several coefficients is usually assigned to a single coded symbol.

// The following values are usually agreed upon a sender and a receiver and exchanged through an outer rlnc header like the ones defined in headers.p4. Yet, there might be parts of this p4 code where it could be necessary to have those values already defined. Therefore, I set them here for the time being.
#define MAX_SYMBOLS 15 // this value is used by the symbol representation header and is bounded by the lenght of the symbols header field which is 4 bits long.
#define SYMBOL_SIZE 8
