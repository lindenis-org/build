#!/bin/bash -e

source build/setting.mk

export OUT_DIR
export DEVICE_DIR

if [ -d ./debian ] ; then
	pushd ./debian > /dev/null
	./mk-rootfs.sh
	./mk-image.sh
	popd > /dev/null
fi
