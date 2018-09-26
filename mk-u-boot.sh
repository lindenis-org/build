#!/bin/bash -e

if [ ! $_TARGET_CHIP ] ; then
	echo "source build/envsetup.sh firstly"
	exit -1
fi

source build/setting.mk

toolchain_dir="${OUT_DIR}/external-toolchain/gcc-linaro"

function prepare_toolchain()
{
	local toolchain_archive=""
	
	toolchain_archive="${TOOLS_DIR}/build/toolchain/gcc-linaro-arm.tar.xz"

	if [ ! -d ${toolchain_dir} ] ; then
		mkdir -p ${toolchain_dir}
	fi

	if [ ! -f ${toolchain_dir}/.stamp_extracted ] ; then
		printf "Prepare toolchain..."
		tar --strip-components=1 -xf ${toolchain_archive} -C ${toolchain_dir}
		touch ${toolchain_dir}/.stamp_extracted
		printf "\nDone.\n"
	fi

	export CROSS_COMPILE=${toolchain_dir}/bin/arm-linux-gnueabi-
}

function usage()
{
	echo "Usage:"
	echo "    $ ./build/mk-u-boot.sh"
	echo "    $ ./build/mk-u-boot.sh nor"
	echo "    $ ./build/mk-u-boot.sh spl"
	echo "    $ ./build/mk-u-boot.sh fes"
}

prepare_toolchain

if [ "x$1" = "xnor" ] ; then
	make -C $UBOOT_DIR distclean
	make -C $UBOOT_DIR ${_TARGET_CHIP}_nor_config
	make -C $UBOOT_DIR -j$PARALLEL_JOBS
	exit $?
elif [ "x$1" = "xspl" ] ; then
	make -C $UBOOT_DIR distclean
	make -C $UBOOT_DIR ${_TARGET_CHIP}_config
	make -C $UBOOT_DIR -j$PARALLEL_JOBS spl
	exit $?
elif [ "x$1" = "xfes" ] ; then
	make -C $UBOOT_DIR distclean
	make -C $UBOOT_DIR ${_TARGET_CHIP}_config
	make -C $UBOOT_DIR -j$PARALLEL_JOBS fes
	exit $?
elif [ -n "$1" ] ; then
	usage
	exit -1
fi

make -C $UBOOT_DIR distclean
make -C $UBOOT_DIR ${_TARGET_CHIP}_config
make -C $UBOOT_DIR -j$PARALLEL_JOBS
