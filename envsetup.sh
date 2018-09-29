#!/bin/bash -e

parent_dir=`dirname ${BASH_SOURCE[0]}`
if [ x$parent_dir != "xbuild" ] ; then
	echo "Run \"source build/envsetup.sh\" at top directory of the SDK"
	return -1
fi

source build/setting.mk

unset _TARGET_CHIP
unset _TARGET_ARCH
unset _TARGET_PLATFORM
unset _TARGET_OS
unset _TARGET_BOARD

function select_platform()
{
	local cnt=0
	local choice
	local platform=""

	printf "All available platforms:\n"
	for platform in ${platforms[@]} ; do
		printf "%4d. %s\n" $cnt `echo $platform | awk -F':' '{ print $1 "(" $2 ")" }'`
		((cnt+=1))
	done

	while true ; do
		read -p "Choice: " choice
		if [ -z "${choice}" ] ; then
			continue
		fi

		if [ -z "${choice//[0-9]/}" ] ; then
			if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
				_TARGET_CHIP=`echo ${platforms[$choice]} | awk -F':' '{ print $2 }' | awk -F',' '{ print $2 }'`
				_TARGET_ARCH=`echo ${platforms[$choice]} | awk -F':' '{ print $2 }' | awk -F',' '{ print $3 }'`
				_TARGET_PLATFORM=`echo ${platforms[$choice]} | awk -F':' '{ print $1 }'`
				break
			fi
		fi
		printf "Invalid input...\n"
	done
}

function select_os()
{
	local cnt=0
	local choice
	local os=""

	printf "All available OS:\n"
	for os in ${OSS[@]} ; do
		printf "%4d. %s\n" $cnt $os
		((cnt+=1))
	done

	while true ; do
		read -p "Choice: " choice
		if [ -z "${choice}" ] ; then
			continue
		fi

		if [ -z "${choice//[0-9]/}" ] ; then
			if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
				_TARGET_OS="${OSS[$choice]}"
				break
			fi
		fi
		printf "Invalid input...\n"
	done
}

function select_board()
{
	local cnt=0
	local choice
	local boarddir
	local boards

	printf "All available boards:\n"
	for boarddir in device/$_TARGET_PLATFORM/boards/* ; do
		boards[$cnt]=`basename $boarddir`
		[ -d $boarddir ] || continue
		printf "%4d. %s\n" $cnt ${boards[$cnt]}
		((cnt+=1))
	done

	while true ; do
		read -p "Choice: " choice
		if [ -z "${choice}" ] ; then
			continue
		fi

		if [ -z "${choice//[0-9]/}" ] ; then
			if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
				_TARGET_BOARD="${boards[$choice]}"
				break
			fi
		fi
		printf "Invalid input...\n"
	done
}

function prepare_toolchain()
{
	local toolchain_archive=""
	local toolchain_dir=""
	
	if [ "x$_TARGET_CHIP" != "xsun8iw8p1" -a "x$_TARGET_CHIP" != "xsun8iw15p1" ] ; then
		toolchain_archive="${TOOLS_DIR}/build/toolchain/gcc-linaro-5.3.1-2016.05-x86_64_arm-linux-gnueabi.tar.xz"
		toolchain_dir="${OUT_DIR}/external-toolchain/gcc-linaro-5.3.1-arm"
	else
		toolchain_archive="${TOOLS_DIR}/build/toolchain/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz "
		toolchain_dir="${OUT_DIR}/external-toolchain/gcc-linaro-6.3.1-arm"
	fi

	if [ ! -d ${toolchain_dir} ] ; then
		mkdir -p ${toolchain_dir}
	fi

	if [ ! -f ${toolchain_dir}/.stamp_extracted ] ; then
		printf "\nPrepare toolchain..."
		tar --strip-components=1 -xf ${toolchain_archive} -C ${toolchain_dir}
		touch ${toolchain_dir}/.stamp_extracted
		printf "\nDone.\n"
	fi

	if ! echo $PATH | grep -q "${toolchain_dir}" ; then
		export PATH=${toolchain_dir}/bin:$PATH
	fi
}

function mk()
{
	local br_out_dir=$OUT_DIR/$_TARGET_PLATFORM/$_TARGET_BOARD/buildroot
	if [ ! -f $br_out_dir/.config ] ; then
		echo "mk-rootfs firstly"
		return
	fi

	if [ "$#" -gt 1 ] ; then
		echo "Usage:"
		echo "    $ mk <package>"
		return
	elif [ "$#" -eq 1 ] ; then
		pkg=$1
	else
		cur=`pwd`
		pkg=`basename $cur`
	fi

	(
	pushd $br_out_dir > /dev/null
	make $pkg-rebuild
	popd > /dev/null
	)
}

function mk-kernel()
{
	(
	pushd $TOP_DIR > /dev/null
	./build/mk-kernel.sh
	popd > /dev/null
	)
}

function mk-rootfs()
{
	(
	pushd $TOP_DIR > /dev/null
	if [ "x$_TARGET_OS" = "xdebian" ] ; then
		./build/mk-debian.sh
	elif [ "x$_TARGET_OS" = "xbuildroot" ] ; then
		./build/mk-buildroot.sh
	else
		echo "Unknown OS"
	fi
	popd > /dev/null
	)
}

function mk-all()
{
	(
	pushd $TOP_DIR > /dev/null
	./build.sh
	popd > /dev/null
	)
}

function mk-pack()
{
	(
	pushd $TOP_DIR > /dev/null
	./build/mk-fw.sh
	popd > /dev/null
	)
}

function mk-installclean()
{
	[ "x$_TARGET_OS" = "xbuildroot" ] || return
	local br_out_dir=$OUT_DIR/$_TARGET_PLATFORM/$_TARGET_BOARD/buildroot

	(
	pushd $br_out_dir > /dev/null
	find build -name .stamp_target_installed -exec rm {} \;
	rm -rf .config target
	popd > /dev/null
	)
}

function cout()
{
	cd $OUT_DIR/$_TARGET_PLATFORM/$_TARGET_BOARD
}

function croot()
{
	cd $TOP_DIR
}

select_platform
select_os
select_board

export _TARGET_CHIP
export _TARGET_ARCH
export _TARGET_PLATFORM
export _TARGET_OS
export _TARGET_BOARD

prepare_toolchain
