# BonusCloud-DiskManager
This script is suitable for the use of virtual and physical machines based on ARMv8 architecture devices and x86 platforms, and is used to implement functions such as opening mirrored multi-disk functions and VG volume management.

The script comes with environment detection function. If it is detected that the system does not support the multi-disk function, it can be turned on automatically. Support SATA, SCSI and NVMe disks.

Currently tested and passed version:
ARMv8: ChainedBox, N1
x86-x64: Physical Machine, ESXi, Hyper-V, PVE

----------------------------------------------------------------------------------------------------------------------

此脚本适用于基于ARMv8架构设备及x86平台的虚拟机和物理机使用，用于实现打开镜像多盘功能以及进行VG卷管理等功能。

脚本自带环境检测功能。如果检测到系统未支持多盘功能可自动打开。支持SATA、SCSI及NVMe磁盘。

目前测试通过版本：
ARMv8：我家云/粒子云、N1
x86-x64：物理机、ESXi、Hyper-V、PVE
