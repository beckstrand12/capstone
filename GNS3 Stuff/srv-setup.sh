#!/bin/sh
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null << 'EOF'
network:
  version: 2
  ethernets:
    ens3:
      addresses:
        - 10.10.30.102/24
      routes:
        - to: default
          via: 10.10.30.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 1.1.1.1
EOF
sudo netplan apply