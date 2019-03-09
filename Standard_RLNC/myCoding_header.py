
from scapy.all import *
import sys, os

# The RLNC Header, holds the type of the packet.
# A value of 2 means it's a DATA packet or a coded packet
# A value of 3 means it's an ACK packet
class P4RLNC_OUT(Packet):
    name = "P4RLNC_OUT"
    fields_desc = [ByteField("Gen_ID", 1),
                   ByteField("Gen_Size", 4),
                   ByteField("Symbol_Size", 8),
                   BitField("Field_Size", 8, 16)]


class P4RLNC_IN(Packet):
    name = "P4RLNC_IN"
    fields_desc = [BitField("Type", 1, 2),
                   BitField("Symbols", 2,6),
                   ByteField("Encoder_Rank", 0)]

# The coefficients necessary for performing the linear combinations
class Coefficient(Packet):
   fields_desc = [ByteField("coefficient", 1)]
   def extract_padding(self, p):
                return "", p

# The symbols to be coded
class SymbolVector(Packet):
   fields_desc = [ByteField("symbol1", 1),
                  ByteField("symbol2", 1)]

# The symbols to be coded
class CoefficientVector(Packet):
   fields_desc = [ByteField("coef1", 1),
                  ByteField("coef2", 1),
                  ByteField("coef3", 1),
                  ByteField("coef4", 1)]
