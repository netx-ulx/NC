#!/usr/bin/env python
from pyfinite import ffield

def generateCommands(gen_size, s, field_size, mul):
	for j in range(1, s+1):
			template = open("p4_templates/commands_template.txt", "r")
			f = open("commands"+str(j)+".txt", "w+")
			for line in template:
				if "N" in line:
					newLine = line.replace("N", str(j))
					f.write(newLine)
				else:
					f.write(line)
			if j == 1:
				for i in range(0, gen_size):
					f.write("mc_node_create " + str(i) + " 2\n")
			else:
				for i in range(0, gen_size):
					f.write("mc_node_create " + str(i) + " 1\n")

			for i in range(0, gen_size):
				f.write("mc_node_associate 1 " + str(i) + "\n")

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

						for i in range(255, 509):
							f.write("register_write GF256_invlog " + str(i) + " " + str(Exp[i%255]) + "\n")

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

						for i in range(65535, 131069):
							f.write("register_write GF256_invlog " + str(i) + " " + str(Exp[i%65535]) + "\n")

						for i in range(0, 65535):
							f.write("register_write GF256_log " + str(Exp[i]) + " " + str(i) + "\n")
