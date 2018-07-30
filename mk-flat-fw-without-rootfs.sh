#!/bin/bash

source build/prev-fw.sh

dev_out_dir=${OUT_DIR}/${_TARGET_PLATFORM}/${_TARGET_BOARD}
flat_fw_file=${dev_out_dir}/${_TARGET_PLATFORM}-${_TARGET_OS}-${_TARGET_BOARD}-flat.img
flat_fw_without_rootfs=${dev_out_dir}/${_TARGET_PLATFORM}-${_TARGET_OS}-${_TARGET_BOARD}-flat-without-rootfs.img
bootloader_size=0
sunxi_mbr_size=32768

if [ ! -f $flat_fw_file ] ; then
	echo "Need to run ./build.sh flat-fw or ./build/mk-flat-fw.sh firstly"
	exit -1
fi

# Prepare for image
do_prepare

# Get boot0, u-boot, sunxi-mbr offset
eval $(awk -F'=' 'BEGIN { section = ""; } {
	gsub(/\s/, "", $0);
	if ($0 == "[boot_0_0]") {
		section="boot0"
	}
	if ($0 == "[boot_1_0]") {
		section="uboot"
	}
	if ($0 == "[card_boot]") {
		section="sunxi_mbr"
	}
	gsub(/\s/, "", $1);
	if ($1 == "start") {
		gsub(/\s/, "", $2);
		printf "%s_start=%s\n", section, $2
	}
}' ${pack_out_dir}/cardscript.fex)

bootloader_size=$(expr $sunxi_mbr_start + $sunxi_mbr_size)
dd if=$flat_fw_file of=$flat_fw_without_rootfs bs=512 count=$bootloader_size > /dev/null 2>&1

printf "writing in boot0, offset: $boot0_start, size: $(expr `wc -c < ${pack_out_dir}/boot0_sdcard.fex` / 512)\n"
dd if=${pack_out_dir}/boot0_sdcard.fex of=$flat_fw_without_rootfs bs=512 seek=$boot0_start conv=notrunc > /dev/null 2>&1

printf "writing in u-boot, offset: $uboot_start, size: $(expr `wc -c < ${pack_out_dir}/boot_package.fex` / 512)\n"
dd if=${pack_out_dir}/boot_package.fex of=$flat_fw_without_rootfs bs=512 seek=$uboot_start conv=notrunc > /dev/null 2>&1

printf "writing in sunxi-mbr, offset: $sunxi_mbr_start, size: $(expr `wc -c < ${pack_out_dir}/sunxi_mbr.fex` / 512)\n"
dd if=${pack_out_dir}/sunxi_mbr.fex of=$flat_fw_without_rootfs bs=512 seek=$sunxi_mbr_start conv=notrunc > /dev/null 2>&1

# Get partitions
eval $(awk -F'=' 'BEGIN { i = 0; print "partitions=(" } {
	gsub(/\s/, "", $0);
	if ($0 == "[partition]") {
		i++
	}
	if (i > 0) {
		gsub(/\s/, "", $1);
		gsub(/\s/, "", $2);
		if ($1 == "name") {
			printf "%s=%s,", $1, $2
			if ($2 == "UDISK") {
				printf "size=,"
			}
		}
		if ($1 == "size") {
			printf "%s=%s,", $1, $2
		}
		if ($1 == "downloadfile" ) {
			gsub(/"/, "", $2);
			printf "%s=%s\n", $1, $2
		}
	}
} END { print ")" }' ${pack_out_dir}/sys_partition.fex)

offset=$bootloader_size
for part in ${partitions[@]} ; do
	eval $(echo $part | awk -F',' '{ print $1, $2, $3}')

	if [ x$name == "xrootfs" ] ; then
		break
	fi

	if [ -n "$downloadfile" ] ; then
		printf "writing in $name offset: $offset, size: $(expr `wc -c < ${pack_out_dir}/$downloadfile` / 512)\n"
		dd if=${pack_out_dir}/$downloadfile of=$flat_fw_without_rootfs bs=512 seek=$offset conv=notrunc > /dev/null 2>&1
	fi
	if [ -n "$size" ] ; then
		offset=$(expr $offset + $size)
	fi

	unset name
	unset size
	unset downloadfile
done

if [ $? -eq 0 -a -e $flat_fw_without_rootfs ] ; then
	echo '-------- firmware is at --------'
	echo -e '\033[0;31;1m'
	echo $flat_fw_without_rootfs
	echo -e '\033[0m'
fi
