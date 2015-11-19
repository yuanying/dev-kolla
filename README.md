# dev-kolla
Install scripts and manual for kolla.

    $ git clone https://github.com/yuanying/dev-kolla.git

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

## On Target Nodes (control/network/compute)

### Update kernel

    echo "Kernel version $(uname -r)"
    if [[ $(uname -r) != *"3.19"* ]]; then
        echo "Going to update kernel image"
        apt-get update
        apt-get install -y linux-image-generic-lts-vivid
        # VM needs to be rebooted for docker to pickup the changes
        echo "Rebooting for kernel changes"
        echo "After reboot re-run vagrant provision to finish provising the box"
        reboot
        # Sleep for a bit to let vagrant exit properly
        sleep 3
    fi

### Install docker and dependencies

Run conf hosts ubuntu-target-bootstrap.sh

    $ sudo bash -c 'echo "192.168.201.1 operator.local" >> /etc/hosts'
    $ sudo bash dev-kolla/conf/hosts/ubuntu-target-bootstrap.sh

### Add NIC

Add below interface using `virsh edit` command.

    <interface type='bridge'>
      <source bridge='br0'/>
      <model type='virtio'/>
    </interface>

## On Operator Node

### Install Kolla

    $ sudo git clone https://github.com/openstack/kolla.git /usr/local/share/kolla

### Run bootstrap script

    $ sudo sed -i -r "s/^(127\.0\.0\.1\s+)(.*)/\1 \2 operator.local/" /etc/hosts
    $ sudo mkdir -p /data/host/registry-storage
    $ sudo bash /usr/local/share/kolla/dev/vagrant/ubuntu-bootstrap.sh \
           operator multinode /usr/local/share/kolla

### Build Kolla images

    $ sudo cp -r /usr/local/share/kolla/etc/kolla /etc/
    $ cd /usr/local/share/kolla
    $ sudo python setup.py develop
    $ sudo pip install tox
    $ sudo tox -evenv -- echo Done
    $ sudo source .tox/venv/bin/activate
    $ sudo kolla-build --base ubuntu --type source

## On Target Nodes
