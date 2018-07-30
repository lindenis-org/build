#!/bin/bash -e

info()
{
	echo -e "\033[47;34m$*\033[0m"
}

usage()
{
	echo "Usage:"
	echo "    $ ./build.sh           # build the source code"
	echo "    $ ./build.sh flat-fw   # generate sdcard image"
	echo "    $ ./build.sh pack      # generate sunxi image"
}

# build firmware
if [ "x$1" = "xflat-fw" ] ; then
	./build/mk-flat-fw.sh
	exit $?
elif [ "x$1" = "xpack" ] ; then
	./build/mk-fw.sh
	exit $?
elif [ -n "$1" ] ; then
	usage
	exit -1
fi

# build kernel
info "Start to build kernel"
./build/mk-kernel.sh

# build rootfs
info "Start to build rootfs"
if [ "x$_TARGET_OS" = "xdebian" ] ; then
	./build/mk-debian.sh
elif [ "x$_TARGET_OS" = "xbuildroot" ] ; then
	./build/mk-buildroot.sh
else
	echo "Unknown OS"
fi
