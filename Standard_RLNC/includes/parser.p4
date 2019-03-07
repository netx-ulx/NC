#include "headers.p4"
#include "metadata.p4"
#include <core.p4>
#include <v1model.p4>

parser MyParser(packet_in pkt, out headers hdr, inout metadata meta, inout standard_metadata_t std_meta){

	state start {
		transition parse_ethernet;
	}

	state parse_ethernet{
		pkt.extract(hdr.ethernet);
		transition select(hdr.ethernet.etherType) {
			TYPE_RLNC: parse_rlnc_out;
			default: accept;
		}
	}


	state parse_rlnc_out{
		pkt.extract(hdr.rlnc_out);
		transition  parse_rlnc_in;
	}

	state parse_rlnc_in{
		pkt.extract(hdr.rlnc_in);
		// if symbols contains zero, then the packet does not contain any symbol and parsing must stop here
		transition select(hdr.rlnc_in.symbols) {
			0: accept;
			default: parse_seed_or_coeffs;
		}
	}

	state parse_seed_or_coeffs{
        meta.symbols = hdr.rlnc_in.symbols;
        meta.coeffs =  hdr.rlnc_in.encoderRank;
		transition select(hdr.rlnc_in.type) {
			1: parse_symbols;
			2: parse_seed;
			3: parse_coeffs;
			// explicit transition to reject is not supported, so this must exit and go to the accept state anyway
			// default: reject;
			default: accept;
		}
	}

	state parse_seed{
		pkt.extract(hdr.seed);
		transition parse_symbols;
	}

	state parse_coeffs{
		pkt.extract(hdr.coefficients.next);
		meta.coeffs = meta.coeffs - 1;
		transition select(meta.coeffs) {
			0 : parse_symbols;
			default: parse_coeffs;
		}
	}

	state parse_symbols{
		pkt.extract(hdr.symbols.next);
		meta.symbols = meta.symbols - 1;
		transition select(meta.symbols) {
			0 : accept;
			default: parse_symbols;
		}
	}
}
