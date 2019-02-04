
from scapy.all import *
import sys, os

TYPE_MYTUNNEL = 0x1212
TYPE_IPV4 = 0x0800

class P4FFCALC(Packet):
    name = "P4_FF_CALC"
    fields_desc = [ByteField("a", 0),
                   ByteField("b", 0),
                   ByteField("result", 0)]


bind_layers(Ether, P4FFCALC, type=0x1234)