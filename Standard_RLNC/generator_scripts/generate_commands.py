#!/usr/bin/env python
from pyfinite import ffield

def generateCommands(gen_size, s):
	for j in range(1, s+1):
		g = 3
		F = ffield.FField(8,gen=0x11b, useLUT=0)
		Exp = []
		t = 1
		for i in range(0, 255):
			Exp.append(t)
			t = F.Multiply(g, t)
			i += 1


		f = open("commands"+str(j)+".txt", "w+")
		f.write("table_add table_clone action_clone "+str(j)+" => 1\n")
		f.write('''table_add table_forwarding_behaviour my_drop 1 1
//table_add table_forwarding_behaviour action_forward 1 1 => 1

mc_mgrp_create 1
''')

		if j == 1:
			for i in range(0, gen_size):
				f.write("mc_node_create " + str(i) + " 2\n")
		else:
			for i in range(0, gen_size):
				f.write("mc_node_create " + str(i) + " 1\n")

		for i in range(0, gen_size):
			f.write("mc_node_associate 1 " + str(i) + "\n")

		i = 0
		for i in range(0, 255):
			f.write("register_write GF256_invlog " + str(i) + " " + str(Exp[i]) +"\n")

		for i in range(255, 509):
			f.write("register_write GF256_invlog " + str(i) + " " + str(Exp[i%255]) + "\n")

		Log = []
		for i in range(0, 255):
			Log.insert(Exp[i], i)
			f.write("register_write GF256_log " + str(Exp[i]) + " " + str(i) + "\n")
