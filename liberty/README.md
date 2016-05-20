
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

    $ uvt-kvm create compute release=trusty \
              --bridge br0 --cpu 2 --memory 8096 --disk 100 \
              --user-data ./init-04-compute.cfg

### on Host 02

    $ uvt-kvm create compute release=trusty \
              --bridge br0 --cpu 2 --memory 8096 --disk 100 \
              --user-data ./init-05-compute.cfg
