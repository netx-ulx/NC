from pyfinite import ffield

g = 3
F = ffield.FField(8,gen=0x11b, useLUT=0)
Exp = []
t = 1
for i in range(0, 510):
	Exp.append(t)
	t = F.Multiply(g, t)
	i += 1


f = open("myfile.txt", "w+")
i = 0
for i in range(0, 510):
	f.write("register_write GF256_invlog " + str(i) + " " + str(Exp[i]) +"\n")

for i in range(510, 1025):
	f.write("register_write GF256_invlog " + str(i) + " " + str(0) + "\n")

Log = []
for i in range(0, 255):
	Log.insert(Exp[i], i)
	f.write("register_write GF256_log " + str(Exp[i]) + " " + str(i) + "\n")
