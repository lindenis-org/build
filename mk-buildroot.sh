#!/bin/bash -e

[ -z $_TARGET_PLATFORM ] && echo 'source build/envsetup.sh firstly' && exit -1
[ -z $_TARGET_BOARD ] && echo 'source build/envsetup.sh firstly' && exit -1

source build/setting.mk

br_out_dir=$OUT_DIR/$_TARGET_PLATFORM/$_TARGET_BOARD/buildroot

eval $(sed -n '/^config/p' $DEVICE_DIR/$_TARGET_PLATFORM/boards/$_TARGET_BOARD/buildroot.config)
[ ! -f $BR_DIR/configs/$config ] && echo "No config exist ($config)" && exit -1
[ ! -f $br_out_dir/.config ] && make -C $BR_DIR O=$br_out_dir $config

make -C $BR_DIR O=$br_out_dir
