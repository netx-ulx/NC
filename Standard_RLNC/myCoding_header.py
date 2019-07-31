
from scapy.all import *
import sys, os


# The RLNC Header, holds the type of the packet.
class P4RLNC(Packet):
    name = "P4RLNC"
    fields_desc = [BitField("Gen_ID", 0, 16),
                   ByteField("Gen_Size", 8),
                   BitField("Symbol_Size", 16, 16),
                   BitField("Field_Size", 16, 16),
                   BitField("Type", 1, 2),
                   BitField("Symbols", 2,4),
                   BitField("Padding", 0,2),
                   ByteField("Encoder_Rank", 0),
                   ConditionalField(FieldListField("coefficient_vector", None, ByteField("symbol", 0), count_from=lambda pkt:(pkt.Encoder_Rank*pkt.Symbols)), lambda pkt:pkt.Type==3 and pkt.Field_Size==8),
                   ConditionalField(FieldListField("symbols_vector", None, ByteField("coefficient", 0), count_from=lambda pkt:(pkt.Symbols*1)), lambda pkt:pkt.Symbols!=0 and pkt.Field_Size==8),
                   ConditionalField(FieldListField("coefficient_vector", None, BitField("symbol", 16, 16), count_from=lambda pkt:(pkt.Encoder_Rank*pkt.Symbols)), lambda pkt:pkt.Type==3 and pkt.Field_Size==16),
                   ConditionalField(FieldListField("symbols_vector", None, BitField("coefficient", 16, 16), count_from=lambda pkt:(pkt.Symbols*1)), lambda pkt:pkt.Symbols!=0 and pkt.Field_Size==16)]


bind_layers(Ether, P4RLNC, type=0x0809)
