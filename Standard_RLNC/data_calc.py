#!/usr/bin/env python

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import math

def calculate_standard_deviation(xs):
    mean = sum(xs) / len(xs)   # mean
    var  = sum(pow(x-mean,2) for x in xs) / len(xs)  # variance
    std  = math.sqrt(var)  # standard deviation
    return std


list_pkt_rate = []
with open("packet_rate.txt", 'r') as f:
    for line in f:
        list_pkt_rate.append(float(line))
avg_pkt_rate = round(reduce(lambda x, y: x + y, list_pkt_rate) / len(list_pkt_rate))
print "AVG = " + str(avg_pkt_rate)
print "Standard Deviation = " + str(round(calculate_standard_deviation(list_pkt_rate),2))

cpu_usage = []
with open("cpu_usage.txt", 'r') as f:
    for line in f:
        cpu_usage.append(float(line))
avg_cpu_usage = round(reduce(lambda x, y: x + y, cpu_usage) / len(cpu_usage))
print "CPU = " + str(avg_cpu_usage)
