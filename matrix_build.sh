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

# Compiling process
for device in beyond0 beyond1 beyond2 beyondx; do
	./build.sh $device
done

# Module building
cd ${MODULE_DIR} && \
	rm -rf *.zip && \
	zip -r -9 "../../../build/NH-Kernel-Exy9820-OneUI4.1-${BUILD_KERNEL_VERSION}-$(date +%Y%m%d).zip" . && \
	cd $RDIR && \
	echo "Done !"

# Chroot module building
build_chroot(){

	set -e

	cd ${RDIR}/build && \
		rm -rf chroot_module && \
		git clone https://github.com/ravindu644/samsung_exynos9820_stock.git -b magisk_module --depth=1 chroot_module && \
		cd chroot_module

	# Array of URL and version pairs
	declare -A downloads=(
		["https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-nano-arm64.tar.xz"]="minimal"
		["https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-full-arm64.tar.xz"]="full"
	)

	for link in "${!downloads[@]}"; do
		version="${downloads[$link]}"
		local file="$(basename $link)"

		if [ ! -f "kalifs-${version}-arm64.tar.xz" ]; then
			rm -rf *.xz
			aria2c "$link"
			mv -f "$file" "kalifs-${version}-arm64.tar.xz"
		fi

		rm -rf .git*

		local zip_name="kali-nethunter-generic-exynos9820-${version}-$(date +%Y%m%d).zip"
		local zip_path="../${zip_name}"
		
		# Create the initial compressed zip file
		zip -r -9 "$zip_path" . && \
			echo -e "\n[INFO] Chroot module for ${version} created.\n"

		# Check if this is the full version (likely to be large) and re-zip as split
		if [ "$version" = "full" ]; then
			local split_zip_name="splitted-${zip_name}"
			local split_zip_path="../${split_zip_name}"
			
			echo -e "[INFO] Creating split zip for full version (1950M chunks)..."
			cd ..
			zip -0 -s 1950M "$split_zip_name" "$zip_name" && \
				rm -f "$zip_name" && \
				echo -e "\n[INFO] Split chroot module for ${version} created (nested zip structure).\n"
			cd chroot_module
		fi

	done

	rm -rf ../chroot_module && \
		cd $RDIR && \
		echo -e "\n[INFO] All chroot modules are ready.\n"

	set +e

}

if [ ! -z $BUILD_CHROOT ]; then
	build_chroot
fi
