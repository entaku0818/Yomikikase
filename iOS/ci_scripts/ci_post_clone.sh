#!/bin/sh

#  ci_post_clone.sh
#  VoiLog
#
#  Created by 遠藤拓弥 on 2024/03/30.
#

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# xcconfig ファイルが存在しない場合（Xcode Cloud など）に生成する
CONFIG_DIR="${CI_WORKSPACE}/iOS/VoiceYourText/config"

REVENUECAT_KEY="${REVENUECAT_API_KEY:-REVENUECAT_API_KEY_NOT_SET}"
CLOUDRUN_KEY="${CLOUDRUN_API_KEY:-CLOUDRUN_API_KEY_NOT_SET}"

if [ ! -f "${CONFIG_DIR}/Debug.xcconfig" ]; then
  cat > "${CONFIG_DIR}/Debug.xcconfig" << EOF
REVENUECAT_API_KEY = ${REVENUECAT_KEY}
ADMOB_BANNER_ID = ca-app-pub-3940256099942544/2435281174
AUDIO_API_BASE_URL = https:\$()/\$()/voiceyourtext-tts-990821915106.asia-northeast1.run.app
CLOUDRUN_API_KEY = ${CLOUDRUN_KEY}
EOF
  echo "Debug.xcconfig を生成しました"
fi

if [ ! -f "${CONFIG_DIR}/Release.xcconfig" ]; then
  ADMOB_PROD="${ADMOB_BANNER_ID:-ADMOB_BANNER_ID_NOT_SET}"
  cat > "${CONFIG_DIR}/Release.xcconfig" << EOF
REVENUECAT_API_KEY = ${REVENUECAT_KEY}
ADMOB_BANNER_ID = ${ADMOB_PROD}
AUDIO_API_BASE_URL = https:\$()/\$()/voiceyourtext-tts-990821915106.asia-northeast1.run.app
CLOUDRUN_API_KEY = ${CLOUDRUN_KEY}
EOF
  echo "Release.xcconfig を生成しました"
fi
