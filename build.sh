#!/bin/bash
RDIR="$(pwd)"

mkdir -p ${RDIR}/build
export KSU=$1
export KBUILD_BUILD_USER="@ravindu644"

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

#symlinking python2
if [ ! -f "$HOME/python" ]; then
    ln -s /usr/bin/python2.7 "$HOME/python"
    export PATH=$HOME:$PATH
fi 

#building function
build(){
    export KSU_STATUS="non-ksu"
    make ${ARGS} exynos9820-beyondxks_defconfig beyondx.config > /dev/null 2>&1
    make ${ARGS} menuconfig
    make ${ARGS}
}

build_ksu(){
    export KSU_STATUS="ksu"
    make ${ARGS} exynos9820-beyondxks_defconfig beyondx.config ksu.config > /dev/null 2>&1
    make ${ARGS} menuconfig
    make ${ARGS}
}

ak3(){
    cp "${RDIR}/arch/arm64/boot/Image" "${RDIR}/AnyKernel3"
    cd "${RDIR}/AnyKernel3"
    zip -r "Kernel-SM-G977N-${KSU_STATUS}.zip" * ; mv "Kernel-SM-G977N-${KSU_STATUS}.zip" "${RDIR}/build"
    echo -e "\n[i] Build Finished..!\n"
}

clear

if [ "$KSU" = "1" ]; then
    echo -e "[!] Building a KernelSU enabled kernel...\n"
    build_ksu
    ak3
else
    echo -e "[!] Building non-KSU kernel...\n"
    build
    ak3
fi