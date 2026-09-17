#!/bin/sh

# Access ports
ovs-vsctl set port eth1 tag=30  # PC1: VLAN 30
ovs-vsctl set port eth2 tag=30  # PC2: VLAN 30

# Trunk ports
ovs-vsctl set port eth0 vlan_mode=trunk
ovs-vsctl set port eth0 trunks=10,20,30  # uplink to R1

ovs-vsctl set port eth3 vlan_mode=trunk
ovs-vsctl set port eth3 trunks=10,20,30  # uplink to SW2

# Verify
# ovs-vsctl show