#!/bin/bash -e

if [ ! $_TARGET_CHIP ] ; then
	echo "source build/envsetup.sh firstly"
	exit -1
fi

source build/setting.mk

pack_dir=${TOOLS_DIR}/pack
pack_tools_dir=${pack_dir}/pctools/linux
dev_out_dir=${OUT_DIR}/${_TARGET_PLATFORM}/${_TARGET_BOARD}
pack_out_dir=${dev_out_dir}/pack
plat_dir=$DEVICE_DIR/$_TARGET_PLATFORM

export PATH=${pack_tools_dir}/mod_update:${pack_tools_dir}/openssl:${pack_tools_dir}/eDragonEx:${pack_tools_dir}/fsbuild200:${pack_tools_dir}/android:$PATH

tools_file_list=(
common/tools/split_xxxx.fex
common/tools/usbtool_test.fex
common/tools/cardscript.fex
common/tools/cardscript_secure.fex
common/tools/cardtool.fex
common/tools/usbtool.fex
common/tools/aultls32.fex
common/tools/aultools.fex
)

configs_file_list=(
common/toc/toc1.fex
common/toc/toc0.fex
common/toc/boot_package.fex
common/dtb/sunxi.fex
common/hdcp/esm.fex
)

boot_file_list=(
bootloader/boot0_nand.bin:${pack_out_dir}/boot0_nand.fex
bootloader/boot0_sdcard.bin:${pack_out_dir}/boot0_sdcard.fex
bootloader/boot0_spinor.bin:${pack_out_dir}/boot0_spinor.fex
bootloader/fes1.bin:${pack_out_dir}/fes1.fex
bootloader/u-boot.bin:${pack_out_dir}/u-boot.fex
bootloader/u-boot-spinor.bin:${pack_out_dir}/u-boot-spinor.fex
bootloader/cpus_pm_binary.code:${pack_out_dir}/cpus_pm_binary.code
bootloader/scp.bin:${pack_out_dir}/scp.fex
bootloader/sboot.bin:${pack_out_dir}/sboot.fex
)

function do_prepare()
{
	rm -rf $pack_out_dir
	mkdir -p $pack_out_dir

	printf "copying tools file\n"
	for file in ${tools_file_list[@]} ; do
		[ -f $pack_dir/$file ] && \
			cp -f $pack_dir/$file $pack_out_dir > /dev/null
	done

	printf "copying configs file\n"
	for file in ${configs_file_list[@]} ; do
		[ -f $pack_dir/$file ] && \
			cp -f $pack_dir/$file $pack_out_dir > /dev/null
	done
	cp -rf $plat_dir/configs/* $pack_out_dir

	printf "copying bootloader\n"
	for file in ${boot_file_list[@]} ; do
		[ -f $plat_dir/`echo $file | awk -F':' '{print $1}'` ] && \
			cp -f $plat_dir/`echo $file | awk -F':' '{print $1}'` \
				`echo $file | awk -F':' '{print $2}'`
	done
	cp -rf $plat_dir/bootloader/boot-res $pack_out_dir
	cp -rf $plat_dir/bootloader/boot-res.ini $pack_out_dir

	cp -rf $plat_dir/boards/$_TARGET_BOARD/configs/* $pack_out_dir

	pushd $pack_out_dir > /dev/null

	printf "parsing sys_config.fex\n"
	busybox unix2dos sys_config.fex
	script sys_config.fex > /dev/null
	cp -f sys_config.bin config.fex

	printf "parsing sys_partition.fex\n"
	busybox unix2dos sys_partition.fex
	script sys_partition.fex > /dev/null

	printf "parsing dts\n"
	local dtc_compiler=${KERN_DIR}/scripts/dtc/dtc
	local dtc_dep_file=${KERN_DIR}/arch/${_TARGET_ARCH}/boot/dts/.${_TARGET_CHIP}-soc.dtb.d.dtc.tmp
	local dtc_src_path=${KERN_DIR}/arch/${_TARGET_ARCH}/boot/dts
	local dtc_src_file=${KERN_DIR}/arch/${_TARGET_ARCH}/boot/dts/.${_TARGET_CHIP}-soc.dtb.dts.tmp
	local dtc_ini_file=${pack_out_dir}/sys_config2.fex

	cp ${pack_out_dir}/sys_config.fex ${dtc_ini_file}
	sed -i "s/\(\[dram\)_para\(\]\)/\1\2/g" $dtc_ini_file
	sed -i "s/\(\[nand[0-9]\)_para\(\]\)/\1\2/g" $dtc_ini_file

	$dtc_compiler -O dtb -o ${pack_out_dir}/sunxi.fex \
		-b 0 \
		-i $dtc_src_path \
		-F $dtc_ini_file \
		-d $dtc_dep_file $dtc_src_file > /dev/null

	update_dtb sunxi.fex 4096
	update_scp scp.fex sunxi.fex > /dev/null

	printf "update bootloader\n"
	update_boot0 boot0_nand.fex sys_config.bin NAND > /dev/null
	update_boot0 boot0_sdcard.fex sys_config.bin SDMMC_CARD > /dev/null
	update_uboot -no_merge u-boot.fex sys_config.bin > /dev/null
	update_fes1 fes1.fex sys_config.bin > /dev/null
	busybox unix2dos boot_package.cfg
	dragonsecboot -pack boot_package.cfg

	# Uncomment if using FAT filesystem at boot resource partition
	printf "generating boot-res.fex\n"
	fsbuild boot-res.ini split_xxxx.fex > /dev/null

	printf "generating env.fex\n"
	u_boot_env_gen env.cfg env.fex > /dev/null

	ln -sf ${dev_out_dir}/kernel/uImage kernel.fex
	ln -sf ${dev_out_dir}/rootfs.ext4 rootfs.fex

	ln -sf ${dev_out_dir}/kernel/vmlinux.tar.bz2 vmlinux.fex

	printf "generating sunxi-mbr\n"
	update_mbr sys_partition.bin 4 > /dev/null

	popd > /dev/null
}
do_prepare
