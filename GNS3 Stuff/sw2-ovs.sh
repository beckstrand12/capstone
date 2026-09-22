#!/bin/sh

# Access ports
ovs-vsctl set port eth1 tag=30  # NAS: VLAN 20
ovs-vsctl set port eth2 tag=30  # SRV1: VLAN 20
ovs-vsctl set port eth3 tag=10  # ITPC2: VLAN 10

# Trunk port
ovs-vsctl set port eth0 vlan_mode=trunk
ovs-vsctl set port eth0 trunks=10,20,30  # uplink to SW1

# Verify
#ovs-vsctl show