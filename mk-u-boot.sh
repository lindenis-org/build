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

prepare_toolchain

make -C $UBOOT_DIR ${_TARGET_CHIP}_config
make -C $UBOOT_DIR -j$PARALLEL_JOBS
