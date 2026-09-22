#!/bin/sh

# Access ports
ovs-vsctl set port eth2 tag=20  # ProdPC1: VLAN 20
ovs-vsctl set port eth3 tag=20  # ProdPC2: VLAN 20

ovs-vsctl set port eth4 tag=10  # ITPC1: VLAN 10
ovs-vsctl set port eth5 tag=10  # ITPC2: VLAN 10

# Trunk ports
ovs-vsctl set port eth0 vlan_mode=trunk
ovs-vsctl set port eth0 trunks=10,20,30  # uplink to R1

ovs-vsctl set port eth1 vlan_mode=trunk
ovs-vsctl set port eth1 trunks=10,20,30  # uplink to SW2

# Verify
# ovs-vsctl show