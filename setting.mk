TOP_DIR=`pwd`
BR_DIR=${TOP_DIR}/buildroot
DEBIAN_DIR=${TOP_DIR}/debian
DEVICE_DIR=${TOP_DIR}/device
KERN_DIR=${TOP_DIR}/kernel
OUT_DIR=${TOP_DIR}/out
TOOLS_DIR=${TOP_DIR}/tools
UBOOT_DIR=${TOP_DIR}/u-boot
PARALLEL_JOBS=$((`getconf _NPROCESSORS_ONLN` - 1))

# <platform name>:<SoC>,<chip>,<arch>
platforms=(
"eagle:Allwinner-V5,sun8iw12p1,arm"
"petrel:Allwinner-H3,sun8iw7p1,arm"
"cuckoo:Allwinner-V3,sun8iw8p1,arm"
)

OSS=(
"buildroot"
"debian"
)
