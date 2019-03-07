/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.rlnc_out);
        packet.emit(hdr.rlnc_in);
        packet.emit(hdr.seed);
        packet.emit(hdr.coefficients);
        packet.emit(hdr.symbols);
    }
}
