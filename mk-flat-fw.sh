#!/bin/bash -e

source build/prev-fw.sh

dev_out_dir=${OUT_DIR}/${_TARGET_PLATFORM}/${_TARGET_BOARD}
flat_fw_file=${dev_out_dir}/${_TARGET_PLATFORM}-${_TARGET_OS}-${_TARGET_BOARD}-flat.img
flat_fw_zipf=${dev_out_dir}/${_TARGET_PLATFORM}-${_TARGET_OS}-${_TARGET_BOARD}-flat.zip
bootloader_size=0
sunxi_mbr_size=32768

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

rm -f $flat_fw_file $flat_fw_zipf

bootloader_size=$(expr $sunxi_mbr_start + $sunxi_mbr_size)
dd if=/dev/zero of=$flat_fw_file bs=512 count=0 seek=$bootloader_size > /dev/null 2>&1

printf "writing in boot0, offset: $boot0_start, size: $(expr `wc -c < ${pack_out_dir}/boot0_sdcard.fex` / 512)\n"
dd if=${pack_out_dir}/boot0_sdcard.fex of=$flat_fw_file bs=512 seek=$boot0_start conv=notrunc > /dev/null 2>&1

if [ "x$_TARGET_CHIP" != "xsun8iw8p1" ] ; then
	uboot=boot_package.fex
else
	uboot=u-boot.fex
fi
printf "writing in u-boot, offset: $uboot_start, size: $(expr `wc -c < ${pack_out_dir}/${uboot}` / 512)\n"
dd if=${pack_out_dir}/${uboot} of=$flat_fw_file bs=512 seek=$uboot_start conv=notrunc > /dev/null 2>&1

printf "writing in sunxi-mbr, offset: $sunxi_mbr_start, size: $(expr `wc -c < ${pack_out_dir}/sunxi_mbr.fex` / 512)\n"
dd if=${pack_out_dir}/sunxi_mbr.fex of=$flat_fw_file bs=512 seek=$sunxi_mbr_start conv=notrunc > /dev/null 2>&1

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
boot_res_start=$offset
boot_res_size=
for part in ${partitions[@]} ; do
	eval $(echo $part | awk -F',' '{ print $1, $2, $3}')
	if [ "$boot_res_size" = "" ] ; then
		boot_res_size=$(expr $size \/ 2 \/ 1024)
	fi

	if [ -n "$downloadfile" ] ; then
		printf "writing in $name offset: $offset, size: $(expr `wc -c < ${pack_out_dir}/$downloadfile` / 512)\n"
		dd if=${pack_out_dir}/$downloadfile of=$flat_fw_file bs=512 seek=$offset conv=notrunc > /dev/null 2>&1
	fi
	if [ "x$name" != "xUDISK" ] ; then
		offset=$(expr $offset + $size)
	fi

	unset name
	unset size
	unset downloadfile
done
rootfs_start=$offset

printf "generating disk information ...\n"
fdisk $flat_fw_file > /dev/null 2>&1 <<EOF
n
p
1
${rootfs_start}

t
83
n
p
2
${boot_res_start}
+${boot_res_size}M
t
2
e
a
2
p
w
EOF


if [ $? -eq 0 -a -e $flat_fw_file ] ; then
	printf "compressing firmware ...\n"
	zip -jq $flat_fw_zipf $flat_fw_file
	echo '-------- firmware is at --------'
	echo -e '\033[0;31;1m'
	echo $flat_fw_zipf
	echo -e '\033[0m'
fi
