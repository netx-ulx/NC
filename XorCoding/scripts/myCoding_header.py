
from scapy.all import *
import sys, os

TYPE_MYTUNNEL = 0x1212
TYPE_IPV4 = 0x0800

class P4code(Packet):
    name = "P4coding"
    fields_desc = [ByteField("Type", 1),
                   ByteField("Generation", 0),
                   ByteField("Generation_Size",2),
                   ByteField("Starting_Index", 0),
                   ByteField("Current_Index", 0),
                   ByteField("NumPack", 0)]


bind_layers(Ether, P4code, type=0x1234)
