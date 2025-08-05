#!/bin/bash
export RDIR="$(pwd)"
export BUILD_KERNEL_VERSION=$BUILD_KERNEL_VERSION
export MAKE_MENUCONFIG=0

rm -rf ${RDIR}/build/*

for device in beyond0 beyond1 beyond2 beyondxks; do
	./build.sh $device
done

