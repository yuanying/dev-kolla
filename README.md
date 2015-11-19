# dev-kolla
Install scripts and manual for kolla.

## Setup Host

Create bridge for target nodes.

    $ sudo su -
    # apt-get update
    # apt-get remove network-manager
    # apt-get install bridge-utils

Configure /etc/network/interfaces

    auto lo
    iface lo inet loopback

    auto em1
    iface em1 inet manual

    auto br0
    iface br0 inet static
      address 192.168.200.1
      netmask 255.255.0.0
      gateway 192.168.11.1
      dns-nameservers 8.8.8.8
      bridge_ports em1
      bridge_stp off
      bridge_fd 0
      bridge_maxwait 0

And reboot machine.

### Setup uvtool

    $ sudo apt-get install uvtool
    $ # Maybe needs re-login
    $ uvt-simplestreams-libvirt sync release=trusty arch=amd64

### Start Kolla Nodes

    $ uvt-kvm create operator release=trusty \
              --bridge br0 --cpu 1 --memory 4048 --disk 40 \
              --user-data ./init-01-operator.cfg

    $ uvt-kvm create control release=trusty \
              --bridge br0 --cpu 2 --memory 8096 --disk 80 \
              --user-data ./init-02-control.cfg

    $ uvt-kvm create network release=trusty \
              --bridge br0 --cpu 1 --memory 4048 --disk 40 \
              --user-data ./init-03-network.cfg

    $ uvt-kvm create compute release=trusty \
              --bridge br0 --cpu 2 --memory 8096 --disk 100 \
              --user-data ./init-04-compute.cfg
