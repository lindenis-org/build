#!/bin/bash -e

source build/prev-fw.sh

img_name=${_TARGET_PLATFORM}-${_TARGET_OS}-${_TARGET_BOARD}.img

function do_pack()
{
	echo "imagename = $img_name" >> $pack_out_dir/image.cfg
	echo "" >> $pack_out_dir/image.cfg

	echo 'generating allwinner format image...'
	pushd $pack_out_dir > /dev/null
	dragon image.cfg sys_partition.fex
	if [ $? -eq 0 -a -e  $img_name ] ; then
		mv $img_name ../
		echo '-------- image is at --------'
		echo -e '\033[0;31;1m'
		echo ${OUT_DIR}/${_TARGET_PLATFORM}/${_TARGET_BOARD}/${img_name}
		echo -e '\033[0m'
	fi
	popd > /dev/null
}

do_prepare
do_pack
