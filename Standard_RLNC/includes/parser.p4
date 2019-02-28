/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_CODING: parse_rlnc;
            default: accept;
        }
    }

    state parse_rlnc {
        packet.extract(hdr.rlnc);
        meta.parser_metadata.remaining_coeff = hdr.rlnc.encoder_rank;
        meta.parser_metadata.remaining_msg = hdr.rlnc.symbols;
        transition parse_coeff;
    }

    state parse_coeff {
        packet.extract(hdr.coeff.next);
        meta.parser_metadata.remaining_coeff = meta.parser_metadata.remaining_coeff - 1;
        transition select(meta.parser_metadata.remaining_coeff) {
            0 : parse_msg;
            default: parse_coeff;
        }
    }

    state parse_msg {
        packet.extract(hdr.msg.next);
        meta.parser_metadata.remaining_msg = meta.parser_metadata.remaining_msg - 1;
        transition select(meta.parser_metadata.remaining_msg) {
            0 : accept;
            default: parse_msg;
        }
    }

}