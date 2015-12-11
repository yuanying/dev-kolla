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

## On Target Nodes (control/network/compute/storage)

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

Modify `/etc/network/interfaces.d/eth1.cfg`. Add below.

    # The public network interface
    auto eth1
    iface  eth1 inet manual
    up ip link set dev $IFACE up
    down ip link set dev $IFACE down

## On Target Nodes (storage)

### Create volume group

* cf: http://docs.openstack.org/developer/kolla/cinder-guide.html
* cf: http://docs.openstack.org/developer/kolla/ceph-guide.html

Creating partition which named KOLLA_CEPH_OSD_BOOTSTRAP in OS installation.

## On Operator Node

### Install Kolla

    $ sudo git clone https://github.com/openstack/kolla.git /usr/local/share/kolla

### Configure kolla

    $ sudo cp -r /usr/local/share/kolla/etc/kolla /etc/

Modify /etc/kolla/globals.yml

    $ sudo cp ~/dev-kolla/conf/01-operator/etc/kolla/globals.yml /etc/kolla/globals.yml

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
    $ sudo kolla-build --base ubuntu --type source --registry operator.local:4000 --push

### Deploy OpenStack

    $ sudo kolla-ansible deploy -i ~/dev-kolla/conf/01-operator/inventory

### Configure OpenStack Client

    $ cat > ~/openrc << END
    export OS_PROJECT_DOMAIN_ID=default
    export OS_USER_DOMAIN_ID=default
    export OS_PROJECT_NAME=admin
    export OS_USERNAME=admin
    export OS_PASSWORD=password
    export OS_AUTH_URL=http://192.168.201.100:5000
    END
    $ source ~/openrc
    $ IMAGE_URL=http://download.cirros-cloud.net/0.3.4/
    $ IMAGE=cirros-0.3.4-x86_64-disk.img
    $ curl -L -o ./$IMAGE $IMAGE_URL/$IMAGE
    $ glance image-create --name cirros --progress \
                          --disk-format qcow2 --container-format bare \
                          --progress --file ./$IMAGE
    $ neutron net-create public --router:external --shared \
                                --provider:physical_network physnet1 \
                                --provider:network_type flat
    $ neutron subnet-create --name public-subnet --disable-dhcp \
                            --allocation-pool start=192.168.202.1,end=192.168.202.254 \
                            --dns-nameserver 8.8.8.8 \
                            --gateway 192.168.11.1 \
                            public 192.168.0.0/16
    $ neutron net-create private --provider:network_type vxlan
    $ neutron subnet-create private 10.0.0.0/24 --name private-subnet \
                            --gateway 10.0.0.1 --dns-nameservers list=true 8.8.8.8
    $ neutron router-create private-router
    $ neutron router-interface-add private-router private-subnet
    $ neutron router-gateway-set private-router public
    $ neutron security-group-rule-create default \
                                         --direction ingress --ethertype IPv4 \
                                         --protocol icmp \
                                         --remote-ip-prefix 0.0.0.0/0
    $ neutron security-group-rule-create default \
                                         --direction ingress --ethertype IPv4 \
                                         --protocol tcp \
                                         --port-range-min 22 \
                                         --port-range-max 22 \
                                         --remote-ip-prefix 0.0.0.0/0
    $ neutron security-group-rule-create default \
                                         --direction ingress --ethertype IPv4 \
                                         --protocol tcp \
                                         --port-range-min 8000 \
                                         --port-range-max 8000 \
                                         --remote-ip-prefix 0.0.0.0/0
    $ neutron security-group-rule-create default \
                                         --direction ingress --ethertype IPv4 \
                                         --protocol tcp \
                                         --port-range-min 8080 \
                                         --port-range-max 8080 \
                                         --remote-ip-prefix 0.0.0.0/0
    $ nova keypair-add --pub-key ~/.ssh/id_rsa.pub default
    $ curl -O http://uec-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
    $ openstack image create --container-format bare \
                             --disk-format qcow2 \
                             --public \
                             --file ubuntu-14.04-server-cloudimg-amd64-disk1.img \
                             ubuntu-14.04-server

## Cleanup

    $ docker stop $(docker ps -a -q)
    $ docker rm $(docker ps -a -q)

## Etc...

    scp -rp ~/.ssh system@192.168.200.3:~/kollakeys

    sudo adduser kolla
    chmod 600 ~/kollakeys/kolla
    sudo cp -p ~/kollakeys/kolla /etc/sudoers.d/kolla
    sudo chown -R root:root /etc/sudoers.d/kolla
    sudo cp -rp kollakeys ~kolla/.ssh
    sudo chown -R kolla:kolla ~kolla/.ssh/

    sudo rm -rf ~root/.ssh
    sudo cp -rp ~kolla/.ssh ~root/.ssh
    sudo chown -R root:root ~root/.ssh/
