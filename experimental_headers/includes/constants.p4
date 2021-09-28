const bit<16> TYPE_RLNC= 0x0809;

#define MAX_COEFFS 100 // this const and the following MAX_SYMBOLS may always have the same value. So far I do not see a case where those values should be different. 

// The following values are usually agreed upon a sender and a receiver and exchanged through an outer rlnc header like the ones defined in headers.p4. Yet, there might be parts of this p4 code where it could be necessary to have those values already defined. Therefore, I set them here for the time being.
#define SYMBOL_SIZE 8
#define W_SIZE 8 // defined to use functions in modulo.p4
#define FIELD_SIZE 255
#define GEN_SIZE 10
#define GEN_IDX_SIZE 8
#define MAX_GENS 4
#define MAX_BUF_SIZE = GEN_SIZE * MAX_GENS


