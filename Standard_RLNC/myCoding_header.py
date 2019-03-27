
from scapy.all import *
import sys, os


# The RLNC Header, holds the type of the packet.
class P4RLNC(Packet):
    name = "P4RLNC"
    fields_desc = [ByteField("Gen_ID", 0),
                   ByteField("Gen_Size", 4),
                   ByteField("Symbol_Size", 8),
                   BitField("Field_Size", 8, 16),
                   BitField("Type", 1, 2),
                   BitField("Symbols", 2,6),
                   ByteField("Encoder_Rank", 0),
                   ConditionalField(FieldListField("coefficient_vector", None, ByteField("coefficient",0), count_from=lambda pkt:(pkt.Encoder_Rank*pkt.Symbols)), lambda pkt:pkt.Type==3),
                   ConditionalField(FieldListField("symbols_vector", None, ByteField("symbol",0), count_from=lambda pkt:(pkt.Symbols*1)), lambda pkt:pkt.Symbols!=0)]


bind_layers(Ether, P4RLNC, type=0x0809)
