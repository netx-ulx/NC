
from scapy.all import *
import sys, os

# The RLNC Header, holds the type of the packet.
class P4RLNC_OUT(Packet):
    name = "P4RLNC_OUT"
    fields_desc = [ByteField("Gen_ID", 0),
                   ByteField("Gen_Size", 4),
                   ByteField("Symbol_Size", 8),
                   BitField("Field_Size", 8, 16)]


class P4RLNC_IN(Packet):
    name = "P4RLNC_IN"
    fields_desc = [BitField("Type", 1, 2),
                   BitField("Symbols", 2,6)]

# The coefficients necessary for performing the linear combinations
class Coefficient(Packet):
   fields_desc = [ByteField("coefficient", 1)]
   def extract_padding(self, p):
                return "", p

class Symbol(Packet):
    fields_desc = [ByteField("symbol",0)]
    def extract_padding(self, p):
                 return "", p

# The symbols to be coded
class SymbolVector(Packet):
   fields_desc = [FieldListField("symbols_vector", None, ByteField("symbol",0))]

class CoefficientVector(Packet):
	fields_desc = [ByteField("Encoder_Rank", 0),
				   PacketListField("coefficients",
				   					[],
				   					Coefficient,
				   					count_from=lambda pkt:(pkt.Encoder_Rank*1))]
