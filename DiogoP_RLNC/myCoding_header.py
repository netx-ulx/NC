
from scapy.all import *
import sys, os

TYPE_MYTUNNEL = 0x1212
TYPE_IPV4 = 0x0800

class P4RLNC(Packet):
    name = "P4RLNC"
    fields_desc = [ByteField("Type", 2),
                   ByteField("Generation", 0),
                   ByteField("rng1", 0),
                   ByteField("rng2", 0),
                   ByteField("rng3", 0),
                   ByteField("invlog_value", 0)]


class Coefficient(Packet):
   fields_desc = [ByteField("coefficient", 1)]
   def extract_padding(self, p):
                return "", p

class SymbolVector(Packet):
   fields_desc = [ByteField("symbol1", 1),
                  ByteField("symbol2", 1)]
   

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