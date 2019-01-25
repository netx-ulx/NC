P4-RLNC Coding Switch
=====
This project consists of a network where Random Linear Network Coding is performed over the packets.

## The Topology
![Image](images/rlncTopo.png "rlnc")

## Overview

The project consists in a P4 program  ```diogo_rlnc.p4``` and a couple of Python scripts.
The picture above describes the network scenario. Host ```h1``` sends the original data, the ```s1``` switch codes data and the ```s2``` switch recodes the data. Finally the ```h2```  host decodes the data.

## sender.py, receiver.py and decoder.py
There are three python scripts that make use of the Scapy package with the purpose to generate, send, receive packets and decode them.
They work as follows:

 * ```send.py```, executes by entering the command prompt ```./sender.py  ```, the host will send two packets with the respective indicated payloads
 * ```receiver.py```, works by entering the command prompt ```./receiver.py "deviceName" "port"```, the device specified will sniff packets on the provided port.
 * ```decoder.py```, uses the command prompt ```./decoder.py ```, the host will receive and decode the  data.

## ffield.py, genericmatrix.py, _init_.py, rs_code.py, file_ecc.py
These four scripts are used to perform finite field arithmetics and they were used in the  ```./decoder.py``` script to decode the encoded data. 
So that the original sent data could be obtained.

These scripts are not originally from this project. The original repository, from where they come from, can be found in the following link:

*https://github.com/emin63/pyfinite

