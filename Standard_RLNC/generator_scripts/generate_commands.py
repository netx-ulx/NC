#!/usr/bin/env python
from pyfinite import ffield

ports = 1

def set_tables(j, gen_size, c_flag, template, f):
	for line in template:
		if "N" in line and "M" in line:
			newLine = line.replace("N", str(j))
			newLine2 = newLine.replace("M", str(gen_size*ports))
			f.write(newLine2)
		elif "C" in line:
			newLine = line.replace("C", str(c_flag))
			f.write(newLine)
		else:
			f.write(line)

def set_coding_multicast(j, gen_size, f):
	if j == 1:
		node = 0
		port = 2
		for p in range(0, ports):
			for i in range(0, gen_size):
				f.write("mc_node_create " + str(node) + " " + str(port) + "\n")
				node += 1
			port += 1
	else:
		for i in range(0, gen_size):
			f.write("mc_node_create " + str(i) + " 1\n")

	for i in range(0, gen_size*ports):
		f.write("mc_node_associate " + str(1) +  " " + str(i) + "\n")

def set_multicast(j, f):
	if j == 1:
		port = 2
		for i in range(0, ports):
			f.write("mc_node_create " + str(i) + " " + str(port) + "\n")
			port += 1
	else:
		for i in range(0, ports):
			f.write("mc_node_create " + str(i) + " 1\n")

	for i in range(0, ports):
		f.write("mc_node_associate " + str(1) +  " " + str(i) + "\n")

def set_lookup_tables(mul, field_size, f):
	if mul == 1:
		if field_size == 8:
				g = 3
				F = ffield.FField(8,gen=0x11b, useLUT=0)
				Exp = []
				t = 1
				for i in range(0, 255):
					Exp.append(t)
					t = F.Multiply(g, t)

				for i in range(0, 255):
					f.write("register_write GF256_invlog " + str(i) + " " + str(Exp[i]) +"\n")

				for i in range(0, 255):
					f.write("register_write GF256_log " + str(Exp[i]) + " " + str(i) + "\n")

		elif field_size == 16:
				g = 3
				F = ffield.FField(16)
				Exp = []
				t = 1
				for i in range(0, 65535):
					Exp.append(t)
					t = F.Multiply(g, t)

				for i in range(0, 65535):
					f.write("register_write GF256_invlog " + str(i) + " " + str(Exp[i]) +"\n")

				for i in range(0, 65535):
					f.write("register_write GF256_log " + str(Exp[i]) + " " + str(i) + "\n")


def generateCommands(gen_size, s, field_size, mul, c_flag):
	for j in range(1, s+1):
			template = open("p4_templates/commands_template.txt", "r")
			f = open("commands"+str(j)+".txt", "w+")
			set_tables(j, gen_size, c_flag, template, f)
			if c_flag == 1:
				set_coding_multicast(j, gen_size, f)
				set_lookup_tables(mul, field_size, f)
			else:
				set_multicast(j, f)
