/*
The header format implemented in this file follows the encoded symbols representation documented in the IETF draft at

https://tools.ietf.org/id/draft-heide-nwcrg-rlnc-00.html

Hence, any interpretation of the inner RLNC header definition below should refer to that document.
*/


#include "constants.p4"

typedef bit<48> macAddr_t;
typedef bit<8> byte_t;

header Ethernet_t{
	macAddr_t dstAddr;
	macAddr_t srcAddr;
	bit<16> etherType;
}

// TODO: understand better if there might be the need to increase any of these fields size
header Rlnc_out_t{
	byte_t gen_id;
	byte_t gen_size;
	byte_t symbol_size;
	bit<16> field_size;
}

header Rlnc_in_t{
	bit<2> type;
	bit<6> symbols;
	byte_t encoderRank;
}

// SEED is used to generate the coding coefficient vector(s) using a pseudo-random number
// generator for a compact form of the symbol representation
header Seed_t{
	byte_t seed;
}

// each symbol may contain its own coding vector which is made of size Encoding Rank coefficients
header Coeffs_t{
	bit<SYMBOL_SIZE> coef;
}

//  meant to contain the packet  payload over which {re-}coding operations are perfomed
header Symbols_t{
	bit<SYMBOL_SIZE> symbol;
}

struct headers{
	Ethernet_t ethernet;
	Rlnc_out_t	rlnc_out;
	Rlnc_in_t	rlnc_in;
	Seed_t  seed;
	Coeffs_t[MAX_COEFFS] coefficients;
	Symbols_t[MAX_SYMBOLS] symbols;
}
