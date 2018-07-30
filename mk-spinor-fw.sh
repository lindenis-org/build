#!/bin/bash -e

if [ ! $_TARGET_CHIP ] ; then
	echo "source build/envsetup.sh firstly"
	exit -1
fi

img_name=${_TARGET_PLATFORM}-${_TARGET_OS}-${_TARGET_BOARD}-spinor.img

source build/setting.mk

pack_dir=${TOOLS_DIR}/pack
pack_tools_dir=${pack_dir}/pctools/linux
board_out_dir=${OUT_DIR}/${_TARGET_PLATFORM}/${_TARGET_BOARD}
pack_out_dir=${board_out_dir}/pack
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
bootloader/boot_logo.fex:${pack_out_dir}/boot_logo.fex
)

function do_prepare()
{
	rm -rf $pack_out_dir
	mkdir -p $pack_out_dir

	printf "copying tools file\n"
	for file in ${tools_file_list[@]} ; do
		cp -f $pack_dir/$file $pack_out_dir > /dev/null
	done

	printf "copying configs file\n"
	for file in ${configs_file_list[@]} ; do
		cp -f $pack_dir/$file $pack_out_dir > /dev/null
	done
	cp -rf $plat_dir/configs/* $pack_out_dir

	printf "copying bootloader\n"
	for file in ${boot_file_list[@]} ; do
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

	printf "update nor bootloader\n"
	update_boot0 boot0_spinor.fex sys_config.bin SDMMC_CARD > /dev/null
	update_uboot u-boot-spinor.fex sys_config.bin > /dev/null

	printf "update nand and sdcard bootloader\n"
	update_boot0 boot0_nand.fex sys_config.bin NAND > /dev/null
	update_boot0 boot0_sdcard.fex sys_config.bin SDMMC_CARD > /dev/null
	update_uboot u-boot.fex sys_config.bin > /dev/null
	update_fes1 fes1.fex sys_config.bin > /dev/null

	# Uncomment if using FAT filesystem at boot resource partition
	printf "generating boot-res.fex\n"
	fsbuild boot-res.ini split_xxxx.fex > /dev/null

	printf "generating env.fex\n"
	u_boot_env_gen env.cfg env.fex > /dev/null

	ln -sf ${board_out_dir}/kernel/uImage kernel.fex
	ln -sf ${board_out_dir}/rootfs.squashfs rootfs.fex

	printf "parsing sys_partition_spinor.fex\n"
	busybox unix2dos sys_partition_spinor.fex
	script sys_partition_spinor.fex > /dev/null

	printf "generating sunxi-mbr for spinor\n"
	cp sys_partition_spinor.bin sys_partition.bin
	update_mbr sys_partition.bin 1 > /dev/null

	printf "generating full_img.fex\n"
	merge_package full_img.fex \
		boot0_spinor.fex \
		u-boot-spinor.fex \
		sunxi_mbr.fex \
		sys_partition.bin > /dev/null

	ln -sf ${board_out_dir}/kernel/vmlinux.tar.bz2 vmlinux.fex

	popd > /dev/null
}

function do_pack()
{
	echo "imagename = $img_name" >> $pack_out_dir/image_spinor.cfg
	echo "" >> $pack_out_dir/image_spinor.cfg

	pushd $pack_out_dir > /dev/null
	dragon image_spinor.cfg sys_partition_spinor.fex
	if [ $? -eq 0 -a -e  $img_name ] ; then
		mv $img_name ../
		echo '-------- image is at --------'
		echo -e '\033[0;31;1m'
		echo ${board_out_dir}/${img_name}
		echo -e '\033[0m'
	fi
	popd > /dev/null
}

do_prepare
do_pack
