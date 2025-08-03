#!/bin/bash
RDIR="$(pwd)"
export KBUILD_BUILD_USER="@ravindu644"
export MODEL=$1

#init ksu next
git submodule init && git submodule update

# Install requirements
if [ ! -f ".requirements" ]; then
    sudo apt update && sudo apt install -y git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
        default-jdk git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
        python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev python-is-python3 libc6-dev libtinfo6 \
        make repo cpio kmod openssl libelf-dev pahole libssl-dev --fix-missing && wget http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb && sudo dpkg -i libtinfo5_6.3-2ubuntu0.1_amd64.deb && touch .requirements
fi

#build dir
if [ ! -d "${RDIR}/build" ]; then
    mkdir -p "${RDIR}/build"
else
    rm -rf "${RDIR}/build" && mkdir -p "${RDIR}/build"
fi

# Device configuration
declare -A DEVICES=(
    [beyond2]="exynos9820-beyond2_defconfig 9820 SRPRI17C014KU S"
    [beyond1]="exynos9820-beyond1_defconfig 9820 SRPRI28B014KU S"
    [beyond0]="exynos9820-beyond0_defconfig 9820 SRPRI28A014KU S"
    [beyondxks]="exynos9820-beyondxks_defconfig 9820 SRPSC04B011KU S"
)

# Set device-specific variables
if [[ -v DEVICES[$MODEL] ]]; then
    read KERNEL_DEFCONFIG SOC BOARD PHONE <<< "${DEVICES[$MODEL]}"
    echo -e "[!] Building a KernelSU enabled kernel for ${MODEL}...\n"
else
    echo "Unknown device: $MODEL, setting to beyondxks"
    export MODEL="beyondxks"
    read KERNEL_DEFCONFIG SOC BOARD PHONE <<< "${DEVICES[beyondxks]}"
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

# init clang-r383902b
if [ ! -d "${HOME}/toolchains/clang-r383902b" ]; then
    echo -e "\n[INFO] Cloning clang-r383902b...\n"
    mkdir -p "${HOME}/toolchains/clang-r383902b" && cd "${HOME}/toolchains/clang-r383902b"
    curl -LO "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/0e9e7035bf8ad42437c6156e5950eab13655b26c/clang-r383902b.tar.gz"
    tar -xf clang-r383902b.tar.gz && rm clang-r383902b.tar.gz
    cd "${RDIR}"
fi

# init arm gnu toolchain
if [ ! -d "${HOME}/toolchains/gcc" ]; then
    echo -e "\n[INFO] Cloning ARM GNU Toolchain\n"
    mkdir -p "${HOME}/toolchains/gcc" && cd "${HOME}/toolchains/gcc"
    curl -LO "https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz"
    tar -xf arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
    cd "${RDIR}"
fi

# Export toolchain paths
export PATH="${HOME}/toolchains/clang-r383902b/bin:${PATH}"
export LD_LIBRARY_PATH="${HOME}/clang-r383902b/lib:${HOME}/clang-r383902b/lib64:${LD_LIBRARY_PATH}"

# Set cross-compile environment variables
export BUILD_CROSS_COMPILE="${HOME}/toolchains/gcc/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"
export BUILD_CC="${HOME}/toolchains/clang-r383902b/bin/clang"

# Build options for the kernel
export BUILD_OPTIONS="
HOSTLDLIBS="-lyaml" \
-j$(nproc) \
ARCH=arm64 \
CROSS_COMPILE=${BUILD_CROSS_COMPILE} \
CC=${BUILD_CC} \
CLANG_TRIPLE=aarch64-linux-gnu- \
"

#building function
build_ksu(){
    make ${ARGS} "${KERNEL_DEFCONFIG}" common.config ksu.config version.config

    if [ ! "$MAKE_MENUCONFIG" = "0" ]; then
        make ${BUILD_OPTIONS} menuconfig || true
    fi

    make ${BUILD_OPTIONS} || exit 1
}

#build boot.img
build_boot() {    
    rm -f ${RDIR}/AIK-Linux/split_img/boot.img-kernel ${RDIR}/AIK-Linux/boot.img
    cp "${RDIR}/arch/arm64/boot/Image" ${RDIR}/AIK-Linux/split_img/boot.img-kernel
    echo $BOARD > ${RDIR}/AIK-Linux/split_img/boot.img-board
    mkdir -p ${RDIR}/AIK-Linux/ramdisk
    cd ${RDIR}/AIK-Linux && ./repackimg.sh --nosudo && mv image-new.img ${RDIR}/build/boot.img
}

#build dtb.img
build_dtb() {
    ${RDIR}/bin/mkdtimg cfg_create "${RDIR}/build/dt.img" "${RDIR}/bin/exynos${SOC}.cfg" -d "${RDIR}/arch/arm64/boot/dts/exynos"

}

#build odin flashable tar
build_tar(){
    cd ${RDIR}/build
    tar -cvf "KernelSU-Next-UI5.1-${MODEL}-${BUILD_KERNEL_VERSION}.tar" boot.img dt.img && rm boot.img dt.img
    echo -e "\n[i] Build Finished..!\n" && cd ${RDIR}
}

build_ksu
build_boot
build_dtb
build_tar
