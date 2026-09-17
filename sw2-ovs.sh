#!/bin/sh

# Access ports
ovs-vsctl set port eth1 tag=20  # AWSVG: VLAN 20
ovs-vsctl set port eth2 tag=20  # NAS: VLAN 20
ovs-vsctl set port eth3 tag=20  # DB1: VLAN 20
ovs-vsctl set port eth4 tag=20  # APP1: VLAN 20

# Trunk port
ovs-vsctl set port eth0 vlan_mode=trunk
ovs-vsctl set port eth0 trunks=10,20,30  # uplink to SW1

# Verify
ovs-vsctl show