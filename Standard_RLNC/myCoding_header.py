
from scapy.all import *
import sys, os

# The RLNC Header, holds the type of the packet.
# A value of 2 means it's a DATA packet or a coded packet
# A value of 3 means it's an ACK packet
class P4RLNC_OUT(Packet):
    name = "P4RLNC_OUT"
    fields_desc = [ByteField("Gen_ID", 1),
                   ByteField("Gen_Size", 2),
                   ByteField("Symbol_Size", 8),
                   BitField("Field_Size", 8, 16)]

class P4RLNC_IN(Packet):
    name = "P4RLNC_IN"
    fields_desc = [BitField("Type", 3, 2),
                   BitField("Symbols", 2,6)]

# The coefficients necessary for performing the linear combinations
class Coefficient(Packet):
   fields_desc = [ByteField("coefficient", 1)]
   def extract_padding(self, p):
                return "", p

# The symbols to be coded
class SymbolVector(Packet):
   fields_desc = [ByteField("symbol1", 1),
                  ByteField("symbol2", 1)]


# A list to hold all the coefficients
# The number of the coefficients is equal to the size of the generation
class CoefficientVector(Packet):
	fields_desc = [ByteField("Encoder_Rank", 2),
				   PacketListField("coefficients",
				   					[],
				   					Coefficient,
				   					count_from=lambda pkt:(pkt.Encoder_Rank*1))]



bind_layers(Ether, P4RLNC_OUT, type=0x0809)
bind_layers(P4RLNC_OUT, P4RLNC_IN)
bind_layers(P4RLNC_IN, CoefficientVector)
bind_layers(CoefficientVector, SymbolVector)
