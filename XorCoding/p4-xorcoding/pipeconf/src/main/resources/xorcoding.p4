/*
 * Copyright 2017-present Open Networking Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <core.p4>
#include <v1model.p4>

#define MAX_PORTS 255

typedef bit<9> port_t;
const port_t CPU_PORT = 255;

//The size of each payload in each packet, in this case 1 byte. Simple for testing
#define PAYLOAD_SIZE 8
//The size of register which contains and stores the payloads
#define BUFFER_SIZE 4
const bit<16>  TYPE_CODING = 0x1234;

typedef bit<PAYLOAD_SIZE> payload_t;
//------------------------------------------------------------------------------
// HEADERS
//------------------------------------------------------------------------------

header ethernet_t {
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ether_type;
}

header coding_hdr_t {
    bit<8>     type; //1 if not coded, 2 if coded
    bit<8>     gen; //The number of the generation
    bit<8>     gen_size; //The size of the generation
    //These 3 fields are merely for debugging purposes
    bit<8>     starting_index;
    bit<8>     current_index;
    bit<8>     number_of_packets;
    //The payload of the packet
    payload_t  payload;
}

// Metadata to dictate which actions each switch does: Coding, Decoding or Storing payloads
struct coding_metadata_t {
    bit<8>  do_coding;
    bit<8>  do_decoding;
    bit<8>  store_flag;
}

struct metadata {
    coding_metadata_t coding_metadata;
}

// Packet-in header. Prepended to packets sent to the controller and used to
// carry the original ingress port where the packet was received.
@controller_header("packet_in")
header packet_in_header_t {
    bit<9> ingress_port;
}

// Packet-out header. Prepended to packets received by the controller and used
// to tell the switch on which port this packet should be forwarded.
@controller_header("packet_out")
header packet_out_header_t {
    bit<9> egress_port;
}

// For convenience we collect all headers under the same struct.
struct headers_t {
    ethernet_t   ethernet;
    coding_hdr_t coding;
    packet_out_header_t packet_out;
    packet_in_header_t packet_in;
}

struct metadata_t {
    coding_metadata_t coding_metadata;
}


//------------------------------------------------------------------------------
// PARSER
//------------------------------------------------------------------------------

parser c_parser(packet_in packet,
                  out headers_t hdr,
                  inout metadata_t meta,
                  inout standard_metadata_t standard_metadata) {

    // A P4 parser is described as a state machine, with initial state "start"
    // and final one "accept". Each intermediate state can specify the next
    // state by using a select statement over the header fields extracted.
    state start {
        transition select(standard_metadata.ingress_port) {
            CPU_PORT: parse_packet_out;
            default: parse_ethernet;
        }
    }

    state parse_packet_out {
        packet.extract(hdr.packet_out);
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            TYPE_CODING: parse_coding;
            default: accept;
        }
    }

    state parse_coding {
        packet.extract(hdr.coding);
        transition accept;
    }

}

//------------------------------------------------------------------------------
// INGRESS PIPELINE
//------------------------------------------------------------------------------

control c_ingress(inout headers_t hdr,
                    inout metadata_t meta,
                    inout standard_metadata_t standard_metadata) {

    // We use these counters to count packets/bytes received/sent on each port.
    // For each counter we instantiate a number of cells equal to MAX_PORTS.
    counter(MAX_PORTS, CounterType.packets_and_bytes) tx_port_counter;
    counter(MAX_PORTS, CounterType.packets_and_bytes) rx_port_counter;

    //Stores the payloads of every generation
    register<payload_t>(BUFFER_SIZE) payload_buffer;

    //Stores and Dictates the index in which a payload from a specific generation should be stored to in the payload_buffer register
    register<bit<32>>(4) generationOffsetBuffer;

    //Buffers the starting index of each generation in the payload_buffer register
    register<bit<32>>(4) starting_index_of_generation_buffer;

    //Dictates if there is enough space for the generation to be buffered in the payload_buffer register
    register<bit<32>>(BUFFER_SIZE) freedSpace;

    //Keeps track of the number of packets received
    register<bit<32>>(1) numberOfStoredPackets;


    action send_to_cpu() {
        standard_metadata.egress_spec = CPU_PORT;
        // Packets sent to the controller needs to be prepended with the
        // packet-in header. By setting it valid we make sure it will be
        // deparsed on the wire (see c_deparser).
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = standard_metadata.ingress_port;
    }


    action set_out_port(port_t port) {
        standard_metadata.egress_spec = port;
    }

    action action_multicast(bit<16> group) {
        standard_metadata.mcast_grp = group;
    }

    action coding_action(bit<8> coding_flag) {
        meta.coding_metadata.do_coding = coding_flag;
        hdr.coding.type = 2;
    }

    action action_decoding(bit<8> decoding_flag) {
        meta.coding_metadata.do_decoding = decoding_flag;
    }

    action store_action(bit<8> store_flag) {
        meta.coding_metadata.store_flag = store_flag;
    }
    action _drop() {
        mark_to_drop();
    }

    // Table counter used to count packets and bytes matched by each entry of
    // t_l2_fwd table.
    direct_counter(CounterType.packets_and_bytes) l2_fwd_counter;

    table t_l2_fwd {
        key = {
            standard_metadata.ingress_port  : ternary;
            hdr.ethernet.dst_addr           : ternary;
            hdr.ethernet.src_addr           : ternary;
            hdr.ethernet.ether_type         : ternary;
        }
        actions = {
            set_out_port;
            send_to_cpu;
            _drop;
            NoAction;
        }
        default_action = NoAction();
        counters = l2_fwd_counter;
    }

    table t_unicast {
        key = {
            standard_metadata.ingress_port: exact;
        }
        actions = {
            set_out_port;
        }
        size = 1024;
    }

    table table_multicast{
        key = {
            standard_metadata.ingress_port : exact;
         }
         actions = {
            action_multicast;
         }
         size = 1024;
    }

    //The next 3 following tables are meant to manipulate the metadata fields,
    //so that the switch takes different actions depending on the metadata values
    table do_coding_table {
        key = {
            meta.coding_metadata.do_coding: exact;
        }
        actions = {
            coding_action;
        }
        size = 1024;
    }

    table do_decoding_table {
        key = {
            standard_metadata.ingress_port: exact;
            hdr.coding.type: exact;
        }
        actions = {
            action_decoding;
        }
        size = 1024;
    }

    table store_table {
        key = {
              standard_metadata.ingress_port: exact;
        }
        actions = {
            store_action;
        }
        size = 1024;
    }
    // Defines the processing applied by this control block. You can see this as
    // the main function applied to every packet received by the switch.
    apply {
        if (standard_metadata.ingress_port == CPU_PORT) {
            // Packet received from CPU_PORT, this is a packet-out sent by the
            // controller. Skip table processing, set the egress port as
            // requested by the controller (packet_out header) and remove the
            // packet_out header.
            standard_metadata.egress_spec = hdr.packet_out.egress_port;
            hdr.packet_out.setInvalid();
        } else {
            // Packet received from data plane port.
            // Applies table t_l2_fwd to the packet.
            if (t_l2_fwd.apply().hit) {
                // Packet hit an entry in t_l2_fwd table. A forwarding action
                // has already been taken. No need to apply other tables, exit
                // this control block.
                return;
            }

            if(hdr.coding.isValid()) {
                //Apply all 3 tables to allocate the proper metadata values
                do_coding_table.apply();
                do_decoding_table.apply();
                store_table.apply();

                //Instantiation of variables that will be needed
                bit<32> gen_index = 0;
                bit<32> starting_index_of_generation = 0;
                bit<32> fetch_index = 0;
                bit<32> gen_size = (bit<32>) hdr.coding.gen_size;
                bit<32> gen = (bit<32>)hdr.coding.gen;
                bit<32> free_space = 0;
                bit<32> number_of_packets = 0;
                bit<32> highest_index_used = 0;

                //The code here branches to different paths, depending if the switch has to Store, Code or Decode a packet.
                //This is decided through the values of the metadata fields. A switch can Store and Code, Store and Decode,
                //Or just simply forward the packet

                //This if block is responsible for buffering the payloads
                if(meta.coding_metadata.store_flag == 1) {
                    generationOffsetBuffer.read(gen_index, gen);
                    numberOfStoredPackets.read(number_of_packets, 0);
                    //This if condition tells us that it's the first time seeing a particular generation
                    //So the index in which to store the packet is decided by the result of the number of packets modulo the size of the buffer
                    //This is done to implement a circular buffer so that the space can be reused.
                    //Then the starting index of the current generation being treated is updated
                    if(gen_index == 0) {
                        starting_index_of_generation = number_of_packets % BUFFER_SIZE;
                        freedSpace.read(free_space, starting_index_of_generation);
                        //Checks if there is space for the current generation starting from the given starting index
                        //Can only happen after the buffer has completed at least one cycle
                        //If there isn't space, stop the execution
                        if(free_space < gen_size && number_of_packets > BUFFER_SIZE) {
                            return;
                        }
                        gen_index = starting_index_of_generation;
                        starting_index_of_generation_buffer.write(gen, starting_index_of_generation);
                        numberOfStoredPackets.write(0, number_of_packets + gen_size);
                    }

                    //If the generation has already been seen, then the index used is the
                    //one stored in the generationOffsetBuffer, which is incremented everytime a packet arrives
                    payload_buffer.write(gen_index, hdr.coding.payload);
                    generationOffsetBuffer.write(gen, gen_index+1);
                }
                //This is block is responsible for coding or xoring two packets together
                if(meta.coding_metadata.do_coding == 1) {
                    generationOffsetBuffer.read(gen_index, gen);
                    starting_index_of_generation_buffer.read(starting_index_of_generation, gen);

                    //The following if condition dictates when the condition to perform an XOR is met
                    //Only when two packets from the same generation arrive, can the switch perform an XOR over them
                    if(gen_index-starting_index_of_generation >= 2) {
                        hdr.coding.starting_index = (bit<8>)starting_index_of_generation;
                        hdr.coding.current_index = (bit<8>) gen_index;
                        hdr.coding.number_of_packets = (bit<8>)number_of_packets;
                        payload_t payload1;
                        payload_t payload2;

                        //Fetching two packets to code them together
                        fetch_index = gen_index - 2;
                        payload_buffer.read(payload1, fetch_index);
                        payload_buffer.read(payload2, fetch_index+1);
                        hdr.coding.payload = (payload1 ^ payload2);

                        //Clearing some space in the buffer
                        payload_buffer.write(fetch_index, 0);
                        payload_buffer.write(fetch_index+1, 0);
                        //If this condition is met, then the generation has been fully coded
                        //So we write on a register how much free space is avaliable starting
                        //from the current generation starting index
                        if(gen_index >= gen_size+1) {
                            freedSpace.write(starting_index_of_generation, gen_size);
                        }

                        hdr.coding.type = 2;
                        t_unicast.apply();
                    }
                }
                //This is block is responsible for decoding
                else if(meta.coding_metadata.do_decoding == 1) {
                    generationOffsetBuffer.read(gen_index, gen);
                    starting_index_of_generation_buffer.read(starting_index_of_generation, gen);
                    if(gen_index >= starting_index_of_generation)   {
                        payload_t payload1;
                        fetch_index = gen_index - 1;
                        payload_buffer.read(payload1, fetch_index);
                        hdr.coding.payload = hdr.coding.payload ^ payload1;
                    }
                    t_unicast.apply();
                }
                else
                {
                    table_multicast.apply();
                    t_unicast.apply();
                }

            }
            // Update port counters at index = ingress or egress port.
            if (standard_metadata.egress_spec < MAX_PORTS) {
                tx_port_counter.count((bit<32>) standard_metadata.egress_spec);
            }
            if (standard_metadata.ingress_port < MAX_PORTS) {
                rx_port_counter.count((bit<32>) standard_metadata.ingress_port);
            }
        }
    }
}

//------------------------------------------------------------------------------
// EGRESS PIPELINE
//------------------------------------------------------------------------------

control c_egress(inout headers_t hdr,
                 inout metadata_t meta,
                 inout standard_metadata_t standard_metadata) {
    apply {
        // Nothing to do on the egress pipeline.
    }
}

//------------------------------------------------------------------------------
// CHECKSUM HANDLING
//------------------------------------------------------------------------------

control c_verify_checksum(inout headers_t hdr, inout metadata_t meta) {
    apply {
        // Nothing to do here, we assume checksum is always correct.
    }
}

control c_compute_checksum(inout headers_t hdr, inout metadata_t meta) {
    apply {
        // No need to compute checksum as we do not modify packet headers.
    }
}

//------------------------------------------------------------------------------
// DEPARSER
//------------------------------------------------------------------------------

control c_deparser(packet_out packet, in headers_t hdr) {
    apply {
        // Emit headers on the wire in the following order.
        // Only valid headers are emitted.
        packet.emit(hdr.packet_in);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.coding);
    }
}

//------------------------------------------------------------------------------
// SWITCH INSTANTIATION
//------------------------------------------------------------------------------

V1Switch(c_parser(),
         c_verify_checksum(),
         c_ingress(),
         c_egress(),
         c_compute_checksum(),
         c_deparser()) main;
