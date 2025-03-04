#!/bin/bash
RDIR="$(pwd)"
export KBUILD_BUILD_USER="@ravindu644"
export MODEL=$1

#build directory
rm -rf ${RDIR}/build && mkdir -p ${RDIR}/build

# Device configuration
declare -A DEVICES=(
    [beyond2]="exynos9820-beyond2_defconfig 9820 SRPRI17C014KU"
    [beyond1]="exynos9820-beyond1_defconfig 9820 SRPRI28B014KU"
    [beyond0]="exynos9820-beyond0_defconfig 9820 SRPRI28A014KU"
    [beyondxks]="exynos9820-beyondxks_defconfig 9820 SRPSC04B011KU"
)

# Set device-specific variables
if [[ -v DEVICES[$MODEL] ]]; then
    read KERNEL_DEFCONFIG SOC BOARD <<< "${DEVICES[$MODEL]}"
else
    echo "Unknown device: $MODEL, setting to beyondxks"
    export MODEL="beyondxks"
    read KERNEL_DEFCONFIG SOC BOARD <<< "${DEVICES[beyondxks]}"
fi

#kernelversion
if [ -z "$BUILD_KERNEL_VERSION" ]; then
    export BUILD_KERNEL_VERSION="dev"
fi

#setting up localversion
echo -e "CONFIG_LOCALVERSION_AUTO=n\nCONFIG_LOCALVERSION=\"-ravindu644-${BUILD_KERNEL_VERSION}\"\n" > "${RDIR}/arch/arm64/configs/version.config"

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
build_kernel(){
    make ${ARGS} "${KERNEL_DEFCONFIG}" common.config version.config
    make ${ARGS} menuconfig || true
    make ${ARGS} || exit 1
}

#build boot.img
build_boot() {    
    rm -f ${RDIR}/AIK-Linux/split_img/boot.img-kernel ${RDIR}/AIK-Linux/boot.img
    cp "${RDIR}/arch/arm64/boot/Image" ${RDIR}/AIK-Linux/split_img/boot.img-kernel
    echo $BOARD > ${RDIR}/AIK-Linux/split_img/boot.img-board
    mkdir -p ${RDIR}/AIK-Linux/ramdisk
    cd ${RDIR}/AIK-Linux && ./repackimg.sh --nosudo && mv image-new.img ${RDIR}/build/boot.img
}

#build odin flashable tar
build_tar(){
    cp ${RDIR}/prebuilt-images/* ${RDIR}/build && cd ${RDIR}/build
    tar -cvf "Kernel-${MODEL}-${BUILD_KERNEL_VERSION}-stock-One-UI.tar" boot.img dt.img.lz4 && rm boot.img dt.img.lz4
    echo -e "\n[i] Build Finished..!\n" && cd ${RDIR}
}

clear

echo -e "[!] Building kernel...\n"
build_kernel
build_boot
build_tar
