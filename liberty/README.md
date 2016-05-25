
## System configuration

-   Host 01: 192.168.11.204
    -   Operator Node: 192.168.200.11, Mem 4048MB, Disk 40GB
    -   Control Node: 192.168.200.21, Mem 8096MB, Disk 80GB
    -   Network Node: 192.168.200.31, Mem 2024MB, Disk 40GB
    -   Compute Node 01: 192.168.200.41, Mem 8096MB, Disk 100GB
-   Host 02: 192.168.200.3
    -   Compute Node 02: 192.168.200.42, Mem 8096MB, Disk 100GB

## Start nodes

### on Host 01

    $ uvt-kvm create operator release=trusty \
              --bridge br0 --cpu 1 --memory 4048 --disk 40 \
              --user-data ./init-01-operator.cfg

    $ uvt-kvm create control release=trusty \
              --bridge br0 --cpu 2 --memory 8096 --disk 80 \
              --user-data ./init-02-control.cfg

    $ uvt-kvm create network release=trusty \
              --bridge br0 --cpu 1 --memory 2024 --disk 40 \
              --user-data ./init-03-network.cfg

    $ uvt-kvm create compute01 release=trusty \
              --bridge br0 --cpu 2 --memory 8096 --disk 100 \
              --user-data ./init-04-compute.cfg

### on Host 02

    $ uvt-kvm create compute02 release=trusty \
              --bridge br0 --cpu 2 --memory 8096 --disk 100 \
              --user-data ./init-05-compute.cfg

### on each Host

#### Add NIC

Add below interface using virsh edit command.

    <interface type='bridge'>
      <source bridge='br0'/>
      <model type='virtio'/>
    </interface>

And re-define.

    for domain in control network compute01 compute02; do
      virsh shutdown $domain
      virsh define /etc/libvirt/qemu/$domain.xml
      virsh start $domain
    done

Modify /etc/network/interfaces.d/eth1.cfg. Add below.

    cat > /etc/network/interfaces.d/eth1.cfg << 'END'
    # The public network interface
    auto eth1
    iface  eth1 inet manual
    up ip link set dev $IFACE up
    down ip link set dev $IFACE down
    END

## On Target Node

### Clone dev-kolla

    $ git clone https://github.com/yuanying/dev-kolla.git

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

    $ sudo bash -c 'echo "192.168.200.11 operator.local" >> /etc/hosts'
    $ sudo bash dev-kolla/liberty/node/ubuntu-bootstrap.sh

## On Operator Node

### Clone dev-kolla

    $ git clone https://github.com/yuanying/dev-kolla.git

### Install docker and dependencies

Run conf hosts ubuntu-target-bootstrap.sh

    $ sudo bash -c 'echo "192.168.200.11 operator.local" >> /etc/hosts'
    $ sudo bash dev-kolla/liberty/node/ubuntu-bootstrap.sh

### Install operator node specific dependencies

Run operator/ubuntu-bootstrap.sh

    $ git clone https://git.openstack.org/openstack/kolla
    $ sudo bash dev-kolla/liberty/operator/ubuntu-bootstrap.sh kolla/
    $ sed -i -r "s,^[# ]*kolla_internal_vip_address:.+$,kolla_internal_vip_address: \"192.168.200.101\"," /etc/kolla/globals.yml
