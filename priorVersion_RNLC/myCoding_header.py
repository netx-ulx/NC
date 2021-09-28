
from scapy.all import *
import sys, os

# The RLNC Header, holds the type of the packet.
# A value of 2 means it's a DATA packet or a coded packet
# A value of 3 means it's an ACK packet
class P4RLNC(Packet):
    name = "P4RLNC"
    fields_desc = [ByteField("Type", 2),
                   ByteField("Generation", 0)]

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
	fields_desc = [ByteField("count", 1),
				   PacketListField("coefficients",
				   					[],
				   					Coefficient,
				   					count_from=lambda pkt:(pkt.count*1))]
  


bind_layers(Ether, P4RLNC, type=0x1234)
bind_layers(P4RLNC, CoefficientVector)
bind_layers(CoefficientVector, SymbolVector)
bind_layers(SymbolVector, Raw)