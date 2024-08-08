# largely based on https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools

set -xe

function clone() {
	repo="$1"
	dest="$2"
	branch="$3"
	if ! [ -e "$dest" ]
	then
		git clone --depth=1 "$repo" -b "$branch" "$dest"
	fi
}

SCRIPT_DIR=$(realpath $(dirname "$0"))
cd "$SCRIPT_DIR"

CLANG_PATH="$PWD/clang_prebuilts"
LOS_BOOTIMG_TOOLS_PATH="$PWD/los_bootimg_tools"
GCC_AARCH64_PATH="$PWD/gcc_aarch64_prebuilds"
GCC_ARM_PATH="$PWD/gcc_arm_prebuilds"
DEF_CONFIG=lineage_oneplus5_defconfig
KBUILD_PATH="$PWD/kbuild"
KERNEL_PATH="$KBUILD_PATH/arch/arm64/boot/Image.gz-dtb"

clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 "$CLANG_PATH" master-kernel-build-2022
clone https://github.com/LineageOS/android_system_tools_mkbootimg.git "$LOS_BOOTIMG_TOOLS_PATH" lineage-21.0
clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 "$GCC_AARCH64_PATH" pie-gsi
clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 "$GCC_ARM_PATH" pie-gsi

export CC=clang
export PATH="$CLANG_PATH/clang-r450784e/bin:$GCC_AARCH64_PATH/bin:$GCC_ARM_PATH/bin:${PATH}"
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-
export ARCH=arm64
export LLVM=1
export LLVM_IAS=1

ln -sf /usr/bin/python3.11 /usr/bin/python

cd ../

make O="$KBUILD_PATH" lineage_oneplus5_defconfig
make O="$KBUILD_PATH" -j$(nproc)

cd "$SCRIPT_DIR"
ORIG_BOOTIMG="$PWD/orig_boot.img"

if ! [ -e "$ORIG_BOOTIMG" ]
then
	echo "$ORIG_BOOTIMG" not found, abort
	exit 1
fi

mkdir -p orig_boot_split
cd orig_boot_split
ORIG_KERNEL="$PWD/out/kernel"
ORIG_RAMDISK="$PWD/out/ramdisk"

ORIG_ARGS=$(python "$LOS_BOOTIMG_TOOLS_PATH"/unpack_bootimg.py --boot_img "$ORIG_BOOTIMG" --format=mkbootimg)
cd ..

NEW_ARGS=$(echo "$ORIG_ARGS" | sed -e "s#--kernel out/kernel#--kernel $KERNEL_PATH#g" | sed -e "s#--ramdisk out/ramdisk#--ramdisk $ORIG_RAMDISK#g" | sed -Ee "s#--cmdline '[^']*'##g" | sed -Ee "s#--board '[^']*'##g")
KERNEL_CMDLINE=$(echo "$ORIG_ARGS" | sed -Ee "s#.*--cmdline '([^']*)'.*#\1#g")
BOARD=$(echo "$ORIG_ARGS" | sed -Ee "s#.*--board '([^']*)'.*#\1#g")

python "$LOS_BOOTIMG_TOOLS_PATH"/mkbootimg.py $NEW_ARGS --cmdline "$KERNEL_CMDLINE" --board "$BOARD" -o new_boot.img
