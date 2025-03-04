#!/bin/bash
RDIR="$(pwd)"
export KBUILD_BUILD_USER="@ravindu644"

#init ksu next
git submodule init && git submodule update

#build dir
if [ ! -d "${RDIR}/build" ]; then
    mkdir -p "${RDIR}/build"
else
    rm -rf "${RDIR}/build" && mkdir -p "${RDIR}/build"
fi

#kernelversion
if [ -z "$BUILD_KERNEL_VERSION" ]; then
    export BUILD_KERNEL_VERSION="dev"
fi

#setting up localversion
echo -e "CONFIG_LOCALVERSION_AUTO=n\nCONFIG_LOCALVERSION=\"-nh@ravindu644-${BUILD_KERNEL_VERSION}\"\n" > "${RDIR}/arch/arm64/configs/version.config"

#OEM variabls
export ARCH=arm64
export PLATFORM_VERSION=12
export ANDROID_MAJOR_VERSION=s

#main variables
export ARGS="
-j$(nproc)
ARCH=arm64
CLANG_TRIPLE=${RDIR}/toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/bin/aarch64-linux-gnu-
CROSS_COMPILE=${RDIR}/toolchain/gcc-cfp/gcc-cfp-jopp-only/aarch64-linux-android-4.9/bin/aarch64-linux-android-
CC=${RDIR}/toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/bin/clang
"

#building function
build_ksu(){
    make ${ARGS} exynos9820-beyond2lte_defconfig common.config ksu.config version.config nethunter.config
    make ${ARGS} menuconfig || true
    make ${ARGS} || exit 1
}

#build boot.img
build_boot() {    
    rm -f ${RDIR}/AIK-Linux/split_img/boot.img-kernel ${RDIR}/AIK-Linux/boot.img
    cp "${RDIR}/arch/arm64/boot/Image" ${RDIR}/AIK-Linux/split_img/boot.img-kernel
    mkdir -p ${RDIR}/AIK-Linux/ramdisk
    cd ${RDIR}/AIK-Linux && ./repackimg.sh --nosudo && mv image-new.img ${RDIR}/build/boot.img
}

#build odin flashable tar
build_tar(){
    cp ${RDIR}/prebuilt-images/* ${RDIR}/build && cd ${RDIR}/build
    tar -cvf "KernelSU-Next-SM-G977N-${BUILD_KERNEL_VERSION}.tar" boot.img dt.img.lz4 dtbo.img.lz4 && rm boot.img dt.img.lz4 dtbo.img.lz4 
    echo -e "\n[i] Build Finished..!\n" && cd ${RDIR}
}

clear

echo -e "[!] Building a KernelSU enabled kernel...\n"
build_ksu
build_boot
build_tar
