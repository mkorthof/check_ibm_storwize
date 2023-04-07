Example Output V3700

```
# Array
ARRAY CRITICAL - NOK:3/OK:0/Total:3 - MDisk-00(Degraded,Degraded,online) MDisk-01(Degraded,Degraded,online) MDisk-02(Degraded,Degraded,online)|nok=3;;;; ok=0;;;; total=3;;;;

# ArrayBasedOnDiskDrive
WARN: missing argument "-c crit", using default value '0'
WARN: missing argument "-w warn", using default value '0'
ARRAY SPARE COVERAGE OK - NOK:0/OK:22/Total:22 |nok=0;;;; ok=22;;;; total=22;;;;

# BackendVolume
BE VOLUME CRITICAL - NOK:3/OK:0/Total:3 - MDisk-00(Degraded,Degraded) MDisk-01(Degraded,Degraded) MDisk-02(Degraded,Degraded)|nok=3;;;; ok=0;;;; total=3;;;;

# Cluster
CLUSTER OK - NOK:0/OK:1/Total:1 |nok=0;;;; ok=1;;;; total=1;;;;

# ConcreteStoragePool
WARN: missing argument "-c crit", using default value '80'
WARN: missing argument "-w warn", using default value '90'
STORAGE POOL CRITICAL - NOK:1/OK:0/Total:1 - Pool-00(Degraded,Degraded,Used:100%)|Pool-00=100%;;;; used=12TiB;;;; total=12TiB;;;; mdisks=3;;;; vols=2;;;;

# DiskDrive
DISK DRIVE CRITICAL - NOK:24/OK:0/Total:24 - DiskDrive-0,Enc:1,Slot:6(degraded) DiskDrive-1,Enc:1,Slot:19(degraded) DiskDrive-2,Enc:1,Slot:7(degraded) DiskDrive-3,Enc:1,Slot:18(degraded) DiskDrive-4,Enc:1,Slot:8(degraded) DiskDrive-5,Enc:1,Slot:3(degraded) DiskDrive-6,Enc:1,Slot:10(degraded) DiskDrive-7,Enc:1,Slot:15(degraded) DiskDrive-8,Enc:1,Slot:20(degraded) DiskDrive-9,Enc:1,Slot:24(degraded) DiskDrive-10,Enc:1,Slot:4(degraded) DiskDrive-11,Enc:1,Slot:13(degraded) DiskDrive-12,Enc:1,Slot:22(degraded) DiskDrive-13,Enc:1,Slot:23(degraded) DiskDrive-14,Enc:1,Slot:9(degraded) DiskDrive-15,Enc:1,Slot:1(degraded) DiskDrive-16,Enc:1,Slot:12(degraded) DiskDrive-18,Enc:1,Slot:21(degraded) DiskDrive-19,Enc:1,Slot:5(degraded) DiskDrive-20,Enc:1,Slot:2(degraded) DiskDrive-21,Enc:1,Slot:14(degraded) DiskDrive-22,Enc:1,Slot:17(degraded) DiskDrive-23,Enc:1,Slot:16(degraded) DiskDrive-24,Enc:1,Slot:11(degraded)|nok=24;;;; ok=0;;;; total=24;;;;

# Enclosure
ENCLOSURE CRITICAL - NOK:1/OK:0/Total:1 - Enc_1,SN:7654321(degraded,Canister:2/2,PSU:2/2)|nok=1;;;; ok=0;;;; total=1;;;;

# EthernetPort
ETHERNET PORT OK - NOK:0/OK:2/Total:2 |nok=0;;;; ok=2;;;; total=2;;;;

# FCPort
FC PORT OK - NOK:0/OK:4/Stopped:4/Total:8 - 54321543210EB346(unconf_inactive) 543215432112B346(unconf_inactive) 54321543210EB347(unconf_inactive) 543215432112B347(unconf_inactive)|nok=0;;;; ok=4;;;; Stopped=4;;;; total=8;;;;

# IOGroup
I/O GROUP OK - NOK:0/OK:16/Total:16 |num_hosts_io_grp0=2;;;; num_nodes_io_grp0=2;;;; num_vol_io_grp0=2;;;; mem_fc_io_grp0=20971520;;;0;20971520 mem_mirr_io_grp0=20971520;;;0;20971520 mem_raid_io_grp0=35033088;;;0;41943040 mem_rc_io_grp0=20971520;;;0;20971520 num_hosts_io_grp1=0;;;; num_nodes_io_grp1=0;;;; num_vol_io_grp1=0;;;; mem_fc_io_grp1=20971520;;;0;20971520 mem_mirr_io_grp1=20971520;;;0;20971520 mem_raid_io_grp1=41943040;;;0;41943040 mem_rc_io_grp1=20971520;;;0;20971520 num_hosts_io_grp2=0;;;; num_nodes_io_grp2=0;;;; num_vol_io_grp2=0;;;; mem_fc_io_grp2=20971520;;;0;20971520 mem_mirr_io_grp2=20971520;;;0;20971520 mem_raid_io_grp2=41943040;;;0;41943040 mem_rc_io_grp2=20971520;;;0;20971520 num_hosts_io_grp3=0;;;; num_nodes_io_grp3=0;;;; num_vol_io_grp3=0;;;; mem_fc_io_grp3=20971520;;;0;20971520 mem_mirr_io_grp3=20971520;;;0;20971520 mem_raid_io_grp3=41943040;;;0;41943040 mem_rc_io_grp3=20971520;;;0;20971520 num_hosts_recovery_io_grp=0;;;; num_nodes_recovery_io_grp=0;;;; num_vol_recovery_io_grp=0;;;; mem_fc_recovery_io_grp=0;;;0;0 mem_mirr_recovery_io_grp=0;;;0;0 mem_raid_recovery_io_grp=0;;;0;0 mem_rc_recovery_io_grp=0;;;0;0

# NetworkPort
NETWORK PORT OK - |nok=0;;;; ok=0;;;; total=0;;;;

# IsSpare
HOT SPARES OK - NOK:0/OK:2/Total:2 |nok=0;;;; ok=2;;;; total=2;;;;

# MasterConsole
MANAGEMENT GUI OK - NOK:0/OK:1/Total:1 |nok=0;;;; ok=1;;;; total=1;;;;

# MirrorExtent
VDISK MIRRORS OK - NOK:0/OK:2/Total:2 |nok=0;;;; ok=2;;;; total=2;;;;

# Node
NODE CRITICAL - NOK:1/OK:1/Total:2 - node2(Offline,Lost Communication)|nok=1;;;; ok=1;;;; total=2;;;;

# QuorumDisk
QUORUM DISK CRITICAL - NOK:3/OK:0/Total:3 - Quorum_0(degraded) Quorum_1(degraded) Quorum_2(degraded) - Active quorum on "Quorum_0"|nok=3;;;; ok=0;;;; total=3;;;;

# StorageVolume
WARN: missing argument "-c crit", using default value '95'
WARN: missing argument "-w warn", using default value '85'
STORAGE VOLUME CRITICAL - NOK:2/OK:0/Total:2 - VOL-00(Empty,Degraded,Degraded,0%) VOL-01(Empty,Degraded,Degraded,0%)|VOL-00=0%;;;; used=0;;;; total=4GiB;;;; VOL-01=0%;;;; used=0;;;; total=12TiB;;;;
```
