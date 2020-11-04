#!/bin/bash
export ARCH=arm64
target=tiffany_defconfig
make ${target}
cp .config arch/${ARCH}/configs/${target}
