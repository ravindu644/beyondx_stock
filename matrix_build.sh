#!/bin/bash
export RDIR="$(pwd)"
export MODULE_DIR="${RDIR}/nethunter-exynos9820/exynos9820/module"
export MAKE_MENUCONFIG=0

#kernelversion
if [ -z "$BUILD_KERNEL_VERSION" ]; then
    export BUILD_KERNEL_VERSION="dev"
fi


set -e

rm -rf ${RDIR}/build/*

for device in beyond0 beyond1 beyond2 beyondx; do
	./build.sh $device
done

cd ${MODULE_DIR} && \
	rm -rf *.zip && \
	zip -r -9 "../../../build/NH-Kernel-Exy9820-OneUI4.1-${BUILD_KERNEL_VERSION}-$(date +%Y%m%d).zip" . && \
	echo "Done !"
