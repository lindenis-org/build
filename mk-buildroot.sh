#!/bin/bash -e

[ -z $_TARGET_PLATFORM ] && echo 'source build/envsetup.sh firstly' && exit -1
[ -z $_TARGET_BOARD ] && echo 'source build/envsetup.sh firstly' && exit -1

source build/setting.mk

platform_dir=$DEVICE_DIR/$_TARGET_PLATFORM
board_dir=$platform_dir/boards/$_TARGET_BOARD
out_dir=$OUT_DIR/$_TARGET_PLATFORM/$_TARGET_BOARD
br_out_dir=$out_dir/buildroot

[ -d $out_dir ] || mkdir -p $out_dir
rm -rf $out_dir/rootfs_overlay

if [ -d $platform_dir/rootfs_overlay ] ; then
	cp -r $platform_dir/rootfs_overlay $out_dir
fi

if [ -d $board_dir/rootfs_overlay ] ; then
	cp -r $board_dir/rootfs_overlay $out_dir
fi

if [ -f $board_dir/module.install ] ; then
	cp $board_dir/module.install $out_dir
fi

eval $(sed -n '/^config/p' $DEVICE_DIR/$_TARGET_PLATFORM/boards/$_TARGET_BOARD/buildroot.config)
[ ! -f $BR_DIR/configs/$config ] && echo "No config exist ($config)" && exit -1
[ ! -f $br_out_dir/.config ] && make -C $BR_DIR O=$br_out_dir $config

make -C $BR_DIR O=$br_out_dir
