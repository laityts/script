#!/usr/bin/env bash
# Rom build script
#

# Init
FOLDER="${PWD}"
OUT="${FOLDER}/out/target/product/tiffany"

# ROM
ROMNAME="ArrowOS" # This is for filename
ROM="arrow" # This is for build
DEVICE="tiffany"
TARGET="userdebug"
VERSIONING="CUSTOM_BUILD_TYPE"
VERSION="UNOFFICIAL"
MAINTAINER="Eytan"
CLEANING="" # set "clean" for make clean, "clobber" for make clean && make clobber, don't set for dirty build
MANIFEST="https://github.com/${ROMNAME}/android_manifest.git"
BRANCH=eleven
LOC_MANIFEST="https://github.com/laityts/local_manifests.git"
LOC_BRANCH=arrow-11.0
PROTON_CLANG="true"

# TELEGRAM
#CHATID="" # Group/channel chatid (use rose/userbot to get it)
#TELEGRAM_TOKEN="" # Get from botfather

# Logo
BANNER_LINK="https://raw.githubusercontent.com/ArrowOS/documentation/master/misc/logo.png"
if ! [ -d "$HOME/logo" ]; then
    mkdir "$HOME/logo"
fi
BANNER="$HOME/logo/arrow.png"
if ! [ -f "${BANNER}" ]; then
    wget $BANNER_LINK -O $BANNER
fi

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

# sync
sync() {
# Check if already init before
if ! [ -f "$FOLDER"/.repo/manifest.xml ]; then
    repo init -u "$MANIFEST" -b "$BRANCH" --depth=1
fi

if [ -d "$FOLDER/device/xiaomi" ]; then
   echo "device trees existing"
   if [ -f "$FOLDER"/.repo/local_manifests/tiffany.xml ]; then
    rm -rf "$FOLDER"/.repo/local_manifests
   fi
else
   echo "cloning local manifest.."
   cd "$FOLDER"/.repo
   git clone "$LOC_MANIFEST" -b "$LOC_BRANCH"
   cd "$FOLDER"
fi

if [[ "${PROTON_CLANG}" =~ "true" ]]; then
    if ! [ -d "$FOLDER"/prebuilts/clang/host/linux-x86/clang-proton ]; then
       echo "proton-clang existing"
       git clone https://github.com/kdrag0n/proton-clang.git "$FOLDER"/prebuilts/clang/host/linux-x86/clang-proton --depth=1
    fi
fi

# Finnaly start syncing
SYNC_START=$(date +"%s")

if [ -f "$FOLDER"/Makefile ]; then
    rm -rf "$FOLDER"/Makefile
fi

tg_cast "$(cat <<EOF
<b>Syncing $ROM</b>

<b>Start Time: </b><i>$(date +"%Y-%m-%d"-%H%M)</i>
EOF
)"

repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

if ! [ -f "$FOLDER"/Makefile ]; then
    tg_cast "Failed sync $ROM"
    exit 1
fi

SYNC_END=$(date +"%s")
DIFF=$(($SYNC_END - $SYNC_START))

tg_cast "$(cat <<EOF
<b>Sync Finished</b>

<b>Time:</b> <i>$(($DIFF / 60)) minutes and $(($DIFF % 60)) seconds</i>
Ready to cook
EOF
)"

}

# cleaning env
cleanup() {
    if [ -f "$OUT"/*.zip ]; then
        rm "$OUT"/*.zip
    fi
    if [ -f gd-up.txt ]; then
        rm gd-up.txt
    fi
    if [ -f gd-info.txt ]; then
        rm gd-info.txt
    fi
	if [ -f log.txt ]; then
		rm log.txt
	fi
	if [[ "${CLEANING}" =~ "clean" ]]; then
        make clean
	use_ccache
    elif [[ "${CLEANING}" =~ "clobber" ]]; then
        make clean && make clobber
	use_ccache
    else
        rm -rf out/target/product/*
        use_ccache
    fi
    build
}

# ccache
use_ccache() {
    tg_cast "CCACHE is enabled for this build"
    export USE_CCACHE=1
    export CCACHE_DIR=/root/.ccache/"${ROM}"/
    ccache -M 50G
    ccache -s
}

# Build
build() {
    export "${VERSIONING}"="${VERSION}"
    source build/envsetup.sh
    lunch "${ROM}"_"${DEVICE}"-"${TARGET}"
    make bacon -j$(nproc --all) 2>&1 | tee log.txt
}

# Checker
check() {
    if ! [ -f "$OUT"/*$VERSION*.zip ]; then
        END=$(date +"%s")
        DIFF=$(( END - START ))
        tg_cast "${ROMNAME} Build for ${DEVICE} <b>failed</b> in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)!"
        tg_upload log.txt
	self_destruct
    else
        sourceforge
        Gdrive
    fi
}

# Self destruct
self_destruct() {
    tg_cast "I will shutdown myself in 30m, catch me if you can :P+"
   # sleep 30m
   # sudo shutdown -h now
}

# Gdrive
Gdrive() {
    FILENAME=$(find $OUT -name "*$VERSION*.zip")
    gdrive upload ${FILENAME} | tee -a gd-up.txt
    FILEID=$(cat gd-up.txt | tail -n 1 | awk '{ print $2 }')
    gdrive share "$FILEID"
    gdrive info "$FILEID" | tee -a gd-info.txt
    MD5SUM=$(cat gd-info.txt | grep 'Md5sum' | awk '{ print $2 }')
    NAME=$(cat gd-info.txt | grep 'Name' | awk '{ print $2 }')
    SIZE=$(cat gd-info.txt | grep 'Size' | awk '{ print $2 }')
    DLURL=$(cat gd-info.txt | grep 'DownloadUrl' | awk '{ print $2 }')
    LINKBUTTON="[Download](${DLURL})"
    success
}

# sourceforge
sourceforge() {
    sshpass -p "${PASSWD}" scp "$OUT"/*$VERSION*.zip laityts@frs.sourceforge.net:/home/frs/project/tiffany-project/"$ROMNAME"
}

# done
success() {
END=$(date +"%s")
DIFF=$(( END - START ))
tg_cast "$(cat <<EOF
×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×
<b>${ROMNAME} - ${VERSION} - Update</b>
×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×

<b>• Build Date: </b><code><i>${BUILD_DATE}</i></code>

<b>• Device: </b><code><i>${DEVICE}</i></code>

<b>• SIZE: </b><code><i>${SIZE}</i></code>

<b>• MD5: </b><code><i>${MD5SUM}</i></code>

<b>• Link: </b><code><i><a href="${LINKBUTTON}">Download</a></i></code>
EOF
)"
    tg_upload log.txt
    self_destruct
}

# Let's start
BUILD_DATE="$(date)"
START=$(date +"%s")
tg_cast "$(cat <<EOF
<b>STARTING ${ROMNAME} BUILD</b>

<b>• ROM: </b><code><i>${ROMNAME}</i></code>

<b>• Device: </b><code><i>${DEVICE}</i></code>

<b>• Version: </b><code><i>${VERSION}</i></code>

<b>• Build Start: </b><code><i>${BUILD_DATE}</i></code>
EOF
)"
sync
cleanup
check
