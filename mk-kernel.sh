#!/bin/bash -e

if [ ! $_TARGET_CHIP ] ; then
	echo "source build/envsetup.sh firstly"
	exit -1
fi

source build/setting.mk

dev_out_dir=${OUT_DIR}/${_TARGET_PLATFORM}/${_TARGET_BOARD}
kern_out_dir=${dev_out_dir}/kernel
kern_ver=`make -s kernelversion -C $KERN_DIR`
kern_defconf=${_TARGET_CHIP}smp_defconfig
modules_dir=${kern_out_dir}/lib/modules/${kern_ver}

function build_kernel()
{
	rm -rf $kern_out_dir
	mkdir -p $kern_out_dir

	if [ ! -f ${KERN_DIR}/.config ] ; then
		make ARCH=$_TARGET_ARCH -C $KERN_DIR $kern_defconf
	fi

	make ARCH=$_TARGET_ARCH -C $KERN_DIR -j$PARALLEL_JOBS uImage dtbs modules

	if [ -f ${KERN_DIR}/arch/${_TARGET_ARCH}/boot/Image ] ; then
		cp -f ${KERN_DIR}/arch/${_TARGET_ARCH}/boot/Image ${kern_out_dir}/bImage
	fi

	if [ -f ${KERN_DIR}/arch/${_TARGET_ARCH}/boot/zImage ] ||
		[ -f ${KERN_DIR}/arch/${_TARGET_ARCH}/boot/uImage ] ; then
		cp -f ${KERN_DIR}/arch/${_TARGET_ARCH}/boot/[zu]Image ${kern_out_dir}
	fi

	if [ -f ${KERN_DIR}/arch/${_TARGET_ARCH}/boot/Image.gz ] ; then
		cp -f ${KERN_DIR}/arch/${_TARGET_ARCH}/boot/Image.gz ${kern_out_dir}
	fi

	cp ${KERN_DIR}/.config ${kern_out_dir}

	kern_ver=`cat ${KERN_DIR}/include/generated/utsrelease.h | awk -F\" '{print $2}'`
	modules_dir=${kern_out_dir}/lib/modules/${kern_ver}
	mkdir -p $modules_dir

	pushd $KERN_DIR > /dev/null
	tar -jcf ${kern_out_dir}/vmlinux.tar.bz2 vmlinux
    for file in $(find drivers sound crypto block fs security net -name "*.ko") ; do
        cp $file ${modules_dir}
	done
	popd > /dev/null

    cp -f ${KERN_DIR}/Module.symvers ${modules_dir}
	cp -f ${KERN_DIR}/modules.builtin ${modules_dir}
	cp -f ${KERN_DIR}/modules.order ${modules_dir}

	eval $(echo $kern_ver | awk -F'.' '{print "version="$1, "patchlevel="$2}')
	[ $version -lt 4 ] && [ $patchlevel -lt 10 ] && return 0

	local dtb=""
	dtb=${KERN_DIR}/arch/${_TARGET_ARCH}/boot/dts/${_TARGET_CHIP}-soc.dtb
	if [ -f $dtb ] ; then
		cp $dtb $kern_out_dir/sunxi.dtb
	fi

	# Used for dtb debug
	if [ "x$_TARGET_CHIP" != "xsun8iw15p1" ] ; then
		${KERN_DIR}/scripts/dtc/dtc -I dtb -O dts -o ${kern_out_dir}/.sunxi.dts ${kern_out_dir}/sunxi.dtb
	else
		${KERN_DIR}/scripts/dtc/dtc -I dtb -O dts -o ${kern_out_dir}/.sunxi.dts ${kern_out_dir}/sunxi.dtb -W no-unit_address_vs_reg
	fi
}

function build_module()
{
	local nand_dir=${KERN_DIR}/modules/nand

	make ARCH=$_TARGET_ARCH LICHEE_MOD_DIR=$modules_dir LICHEE_KDIR=$KERN_DIR \
		-C $nand_dir install

	local gpu_type=`sed -n '/CONFIG_SUNXI_GPU_TYPE/p' $KERN_DIR/.config | cut -d \" -f 2`
	if [ "x$gpu_type" = "x" -o "x$gpu_type" = "xNone" ] ; then
		echo 'No GPU'
		return
	fi

	local gpu_dir=${KERN_DIR}/modules/gpu
	make LICHEE_PLATFORM="linux" LICHEE_MOD_DIR=$modules_dir LICHEE_KDIR=$KERN_DIR \
		-C $gpu_dir
}

function build_ramfs()
{
	echo "Do nothing right now"
}

if [ "x$_TARGET_CHIP" != "xsun8iw8p1" -a "x$_TARGET_CHIP" != "xsun8iw15p1" ] ; then
	export CROSS_COMPILE=arm-linux-gnueabi-
else
	export CROSS_COMPILE=arm-linux-gnueabihf-
fi

build_kernel
build_module
