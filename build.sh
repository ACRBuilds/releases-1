#!/bin/bash

export outdir="${ROM_DIR}/out/target/product/${device}"
BUILD_START=$(date +"%s")
echo "Build started for ${device}"
if [ "${jenkins}" == "true" ]; then
    telegram -M "Build ${BUILD_DISPLAY_NAME} started for ${device}: [See Progress](${BUILD_URL}console)"
else
    telegram -M "Build started for ${device}"
fi
source build/envsetup.sh
source "${my_dir}/config.sh"
if [ "${official}" == "true" ]; then
    export CUSTOM_BUILD_TYPE="OFFICIAL"
fi
if [ -z "${buildtype}" ]; then
    export buildtype="userdebug"
fi
if [ "${ccache}" == "true" ] && [ -n "${ccache_size}" ]; then
    export USE_CCACHE=1
    ccache -M "${ccache_size}G"
elif [ "${ccache}" == "true" ] && [ -z "${ccache_size}" ]; then
    echo "Please set the ccache_size variable in your config."
    exit 1
fi
lunch "${rom_vendor_name}_${device}-${buildtype}"
rm "${outdir}"/*$(date +%Y)*.zip*
if [ "${clean}" == "clean" ]; then
    make clean
    make clobber
elif [ "${clean}" == "installclean" ]; then
    make installclean
fi
brunch "${device}" "${buildtype}"
BUILD_END=$(date +"%s")
BUILD_DIFF=$((BUILD_END - BUILD_START))

if [ "${generate_incremental}" == "true" ]; then
    if [ -e "${ROM_DIR}"/*target_files*.zip ]; then
        export old_target_files_exists=true
        export old_target_files_path=$(ls "${ROM_DIR}"/*target_files*.zip | tail -n -1)
    else
        echo "Old target-files package not found, generating incremental package on next build"
    fi
    export new_target_files_path=$(ls "${outdir}"/obj/PACKAGING/target_files_intermediates/*target_files*.zip | tail -n -1)
    if [ "${old_target_files_exists}" == "true" ]; then
        ota_from_target_files -i "${old_target_files_path}" "${new_target_files_path}" "${outdir}"/incremental_ota_update.zip
        export incremental_zip_path=$(ls "${outdir}"/incremental_ota_update.zip | tail -n -1)
    fi
    cp "${new_target_files_path}" "${ROM_DIR}"
fi
export finalzip_path=$(ls "${outdir}"/*$(date +%Y)*.zip | tail -n -1)
if [ "${upload_recovery}" == "true" ]; then
    export img_path=$(ls "${outdir}"/recovery.img | tail -n -1)
fi
export zip_name=$(echo "${finalzip_path}" | sed "s|${outdir}/||")
export tag=$( echo "${zip_name}-$(date +%H%M)" | sed 's|.zip||')
if [ -e "${finalzip_path}" ]; then
    echo "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
    curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAACAgUAAxkBAAEKizNg1iGp3Ab536Qz86F_Esy7chQvHAACOwEAAnBI8ReBayrk9vj3ciAE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker


    echo "Uploading"
    gdrive upload "${zip_name}"
    github-release "${release_repo}" "${tag}" "master" "${ROM} for ${device}

Date: $(env TZ="${timezone}" date)" "${finalzip_path}"
    if [ "${generate_incremental}" == "true" ]; then
        if [ -e "${incremental_zip_path}" ] && [ "${old_target_files_exists}" == "true" ]; then
            github-release "${release_repo}" "${tag}" "master" "${ROM} for ${device}

Date: $(env TZ="${timezone}" date)" "${incremental_zip_path}"
        elif [ ! -e "${incremental_zip_path}" ] && [ "${old_target_files_exists}" == "true" ]; then
            echo "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
            telegram -N -M "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
            curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker
            exit 1
        fi
    fi
    if [ "${upload_recovery}" == "true" ]; then
        if [ -e "${img_path}" ]; then
            github-release "${release_repo}" "${tag}" "master" "${ROM} for ${device}

Date: $(env TZ="${timezone}" date)" "${img_path}"
        else
            echo "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
            telegram -N -M "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
            curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker
            exit 1
        fi
    fi
    echo "Uploaded"

    if [ "${upload_recovery}" == "true" ]; then
        if [ "${old_target_files_exists}" == "true" ]; then
            telegram -M "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds

Download ROM: ["${zip_name}"]("https://github.com/${release_repo}/releases/download/${tag}/${zip_name}")
Download incremental update: ["incremental_ota_update.zip"]("https://github.com/${release_repo}/releases/download/${tag}/incremental_ota_update.zip")
Download recovery: ["recovery.img"]("https://github.com/${release_repo}/releases/download/${tag}/recovery.img")"
        else
            telegram -M "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds

Download ROM: ["${zip_name}"]("https://github.com/${release_repo}/releases/download/${tag}/${zip_name}")
Download recovery: ["recovery.img"]("https://github.com/${release_repo}/releases/download/${tag}/recovery.img")"
        fi
    else
        if [ "${old_target_files_exists}" == "true" ]; then
            telegram -M "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds

Download: ["${zip_name}"]("https://github.com/${release_repo}/releases/download/${tag}/${zip_name}")
Download incremental update: ["incremental_ota_update.zip"]("https://github.com/${release_repo}/releases/download/${tag}/incremental_ota_update.zip")"
        else
            telegram -M "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds

Download: ["${zip_name}"]("https://github.com/${release_repo}/releases/download/${tag}/${zip_name}")

Download from my Website: ["${zip_name}"]("https://dl.ayokaacr.de/2:/${zip_name}")"
        fi
    fi
curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker

else
    echo "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
    telegram -N -M "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
    curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker
    exit 1
fi
