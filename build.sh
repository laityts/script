#!/bin/bash
#
# Copyright (C) 2020 azrim.
# All rights reserved.

export KBUILD_BUILD_USER=eytan
export KBUILD_BUILD_HOST=Ubuntu

# Init
KERNEL_DIR="${PWD}"
KERN_IMG="${KERNEL_DIR}"/out/arch/arm64/boot/Image.gz
KERN_DTB_NONTB="${KERNEL_DIR}"/out/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-tiffany-nontreble.dtb
KERN_DTB_TB="${KERNEL_DIR}"/out/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-tiffany-treble.dtb
ANYKERNEL="${HOME}"/anykernel

# Repo URL
CLANG_REPO="https://github.com/kdrag0n/proton-clang.git"
ANYKERNEL_REPO="https://github.com/laityts/AnyKernel3.git"
ANYKERNEL_BRANCH="tiffany"

# Compiler
CLANG_DIR="$HOME/proton-clang"
if ! [ -d "${CLANG_DIR}" ]; then
    git clone "$CLANG_REPO" --depth=1 "$CLANG_DIR"
fi

# Defconfig
DEFCONFIG="tiffany_defconfig"
REGENERATE_DEFCONFIG="" # unset if don't want to regenerate defconfig

# Costumize
KERNEL="Eytan"
DEVICE="Tiffany"
KERNELTYPE="CAF"
KERNELNAME="${KERNEL}-${DEVICE}-${KERNELTYPE}-$(TZ=Asia/Jakarta date +%y%m%d-%H%M)"
TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
ZIPNAME="${KERNELNAME}.zip"

# Telegram
#CHATID="" # Group/channel chatid (use rose/userbot to get it)
#TELEGRAM_TOKEN="" # Get from botfather

#文件路径
tg_upload() {
  curl -s https://api.telegram.org/bot"${TELEGRAM_TOKEN}"/sendDocument -F document=@"${*}" -F chat_id="${CHATID}"
}

#发送消息
tg_cast() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${CHATID}" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=HTML" \
    -d text="${*}"
}

# Regenerating Defconfig
regenerate() {
    cp out/.config arch/arm64/configs/"${DEFCONFIG}"
    git add arch/arm64/configs/"${DEFCONFIG}"
    git commit -m "defconfig: Regenerate"
}

# Building
makekernel() {
    export PATH="$HOME/proton-clang/bin:$PATH"
    rm -rf "${KERNEL_DIR}"/out/arch/arm64/boot # clean previous compilation
    mkdir -p out 
    make O=out ARCH=arm64 ${DEFCONFIG}
    if [[ "${REGENERATE_DEFCONFIG}" =~ "true" ]]; then
         regenerate
    fi
    make -j$(nproc --all) CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- O=out ARCH=arm64 2>&1 | tee build.log

# Check If compilation is success
    if ! [ -f "${KERN_IMG}" ]; then
	    END=$(date +"%s")
	    DIFF=$(( END - START ))
	    echo -e "Kernel compilation failed, See buildlog to fix errors"exit
	    tg_cast "build for ${DEVICE} <b>failed</b> in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! Check Instance for errors @Eytan_tan"
            tg_upload build.log
            rm build.log
            rm -rf out
	    exit 1
    fi
}

# Packing kranul
packingkernel() {
    # Copy compiled kernel
    if [ -d "${ANYKERNEL}" ]; then
        rm -rf "${ANYKERNEL}"
    fi
    git clone "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" "${ANYKERNEL}"
    	mkdir "${ANYKERNEL}"/kernel/
        cp "${KERN_IMG}" "${ANYKERNEL}"/kernel/Image.gz
        mkdir "${ANYKERNEL}"/dtb-nontreble/
        cp "${KERN_DTB_NONTB}" "${ANYKERNEL}"/dtb-nontreble/msm8953-qrd-sku3-tiffany-nontreble.dtb
	    mkdir "${ANYKERNEL}"/dtb-treble/
        cp "${KERN_DTB_TB}" "${ANYKERNEL}"/dtb-treble/msm8953-qrd-sku3-tiffany-treble.dtb

    # Zip the kernel, or fail
    cd "${ANYKERNEL}" || exit
    zip -r9 "${TEMPZIPNAME}" ./*

    # Sign the zip before sending it to Telegram
    curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel2/master/zipsigner-3.0.jar
    java -jar zipsigner-3.0.jar "${TEMPZIPNAME}" "${ZIPNAME}"

    # Ship it to the CI channel
    tg_upload ${ZIPNAME}
}

# Starting
tg_cast "$(cat <<EOF
<b>• STARTING KERNEL BUILD</b>

• Device: ${DEVICE}

• Kernel: <code>${KERNEL}, ${KERNELTYPE}</code>

• Linux Version: <code>$(make kernelversion)</code>
EOF
)"
START=$(date +"%s")
makekernel
packingkernel
END=$(date +"%s")
DIFF=$(( END - START ))
tg_cast "Build for ${DEVICE} with ${COMPILER_STRING} <b>succeed</b> took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! @Eytan_Tan"
