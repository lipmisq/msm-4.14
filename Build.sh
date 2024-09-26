#!/usr/bin/env bash
#
# Copyright (C) 2023 Edwiin Kusuma Jaya (ryuzenn)
#
# Simple Local Kernel Build Script
#
# Configured for Redmi Note 8 / ginkgo custom kernel source
#
# Setup build env with akhilnarang/scripts repo
#
# Use this script on root of kernel directory

export TZ=Asia/Jakarta
SECONDS=0 # builtin bash timer
TC_DIR="$HOME/toolchain/linux-x86"
GCC_64_DIR="$HOME/toolchain/aarch64-linux-android-4.9"
GCC_32_DIR="$HOME/toolchain/arm-linux-androideabi-4.9"
AK3_DIR="$HOME/android/AnyKernel3"
DEFCONFIG="surya_defconfig"

export PATH="$TC_DIR/bin:$PATH"
export KBUILD_BUILD_USER="JeelsBoobz"
export KBUILD_BUILD_HOST="MiHomo"
export KBUILD_BUILD_VERSION="1"

if ! [ -d $TC_DIR ]; then
  echo "Clang not found! Cloning to ${TC_DIR}..."
  wget "$(curl -s https://raw.githubusercontent.com/XSans0/WeebX-Clang/main/main/link.txt)" -O "weebx-clang.tar.gz"
  mkdir $HOME/toolchain && mkdir $TC_DIR && tar -xvf weebx-clang.tar.gz -C $TC_DIR && rm -rf weebx-clang.tar.gz
  exit 1

fi

if ! [ -d "${GCC_64_DIR}" ]; then
  echo "gcc not found! Cloning to ${GCC_64_DIR}..."
  if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${GCC_64_DIR}; then
    echo "Cloning failed! Aborting..."
    exit 1
  fi
fi

if ! [ -d "${GCC_32_DIR}" ]; then
  echo "gcc_32 not found! Cloning to ${GCC_32_DIR}..."
  if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${GCC_32_DIR}; then
    echo "Cloning failed! Aborting..."
    exit 1
  fi
fi

# Setup and apply patch KernelSU in root dir
if [ "${KSU}" = "true" ]; then
  if ! [ -d "$KERNEL_DIR"/KernelSU ]; then
    curl -LSs "https://raw.githubusercontent.com/kutemeikito/KernelSU/main/kernel/setup.sh" | bash -s main
  else
    echo -e "Setup KernelSU failed, stopped build now..."
    exit 1
  fi
fi

if [ "${KSU}" = "true" ]; then
  ZIPNAME="MiHomo-KSU-$(date +"%Y%m%d").zip"
  sed -i "s|CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"-MiHomo-KSU\"|g" arch/arm64/configs/$DEFCONFIG
else
  ZIPNAME="MiHomo-STD-$(date +"%Y%m%d").zip"
  sed -i "s|CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"-MiHomo\"|g" arch/arm64/configs/$DEFCONFIG
  sed -i "s|CONFIG_KSU=.*|# CONFIG_KSU is not set |g" arch/arm64/configs/$DEFCONFIG
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
  make O=out ARCH=arm64 $DEFCONFIG savedefconfig
  cp out/defconfig arch/arm64/configs/$DEFCONFIG
  exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
  rm -rf out
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=$GCC_64_DIR/bin/aarch64-linux-android- CROSS_COMPILE_ARM32=$GCC_32_DIR/bin/arm-linux-androideabi- CLANG_TRIPLE=aarch64-linux-gnu- Image.gz-dtb dtb.img dtbo.img

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
  echo -e "\nKernel compiled succesfully! Zipping up...\n"
  if [ -d "$AK3_DIR" ]; then
    cp -r $AK3_DIR AnyKernel3
  elif ! git clone -q https://github.com/kutemeikito/AnyKernel3; then
    echo -e "\nAnyKernel3 repo not found locally and cloning failed! Aborting..."
    exit 1
  fi
  cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
  cp out/arch/arm64/boot/dtbo.img AnyKernel3
  cp out/arch/arm64/boot/dtb.img AnyKernel3
  rm -f *zip
  cd AnyKernel3
  git checkout master &> /dev/null
  sed -i "s|kernel.string=.*|kernel.string=MiHomo Kernel|g" ./anykernel.sh
  zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
  cd ..
  rm -rf AnyKernel3
  rm -rf out/arch/arm64/boot
  echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
  echo "Zip: $ZIPNAME"
else
  echo -e "\nCompilation failed!"
  exit 1
fi
