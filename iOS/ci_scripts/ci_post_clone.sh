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
ADMOB_APP_OPEN_ID = ca-app-pub-3940256099942544/5575463023
AUDIO_API_BASE_URL = https:\$()/\$()/voiceyourtext-tts-990821915106.asia-northeast1.run.app
CLOUDRUN_API_KEY = ${CLOUDRUN_KEY}
EOF
  echo "Debug.xcconfig を生成しました"
fi

if [ ! -f "${CONFIG_DIR}/Release.xcconfig" ]; then
  ADMOB_PROD="${ADMOB_BANNER_ID:-ADMOB_BANNER_ID_NOT_SET}"
  ADMOB_APP_OPEN_PROD="${ADMOB_APP_OPEN_ID:-ADMOB_APP_OPEN_ID_NOT_SET}"

  # Releaseビルドでは必須キーが未設定の場合はビルドを中断する
  if [ "${REVENUECAT_KEY}" = "REVENUECAT_API_KEY_NOT_SET" ]; then
    echo "ERROR: REVENUECAT_API_KEY が設定されていません。Xcode Cloud の環境変数を確認してください。" >&2
    exit 1
  fi
  if [ "${ADMOB_PROD}" = "ADMOB_BANNER_ID_NOT_SET" ]; then
    echo "ERROR: ADMOB_BANNER_ID が設定されていません。Xcode Cloud の環境変数を確認してください。" >&2
    exit 1
  fi
  if [ "${ADMOB_APP_OPEN_PROD}" = "ADMOB_APP_OPEN_ID_NOT_SET" ]; then
    echo "ERROR: ADMOB_APP_OPEN_ID が設定されていません。Xcode Cloud の環境変数を確認してください。" >&2
    exit 1
  fi
  # Googleのテスト用パブリッシャーIDが本番ビルドに混入するのを防ぐ。
  # （テストIDで本番バイナリを焼くと広告収益がゼロになる）
  for admob_key_value in "ADMOB_BANNER_ID=${ADMOB_PROD}" "ADMOB_APP_OPEN_ID=${ADMOB_APP_OPEN_PROD}"; do
    admob_key="${admob_key_value%%=*}"
    admob_value="${admob_key_value#*=}"
    case "${admob_value}" in
      ca-app-pub-3940256099942544*)
        echo "ERROR: ${admob_key} が Google のテスト用ID (${admob_value}) です。" >&2
        echo "       Xcode Cloud の環境変数 ${admob_key} に本番の広告ユニットIDを設定してください。" >&2
        exit 1
        ;;
    esac
  done

  cat > "${CONFIG_DIR}/Release.xcconfig" << EOF
REVENUECAT_API_KEY = ${REVENUECAT_KEY}
ADMOB_BANNER_ID = ${ADMOB_PROD}
ADMOB_APP_OPEN_ID = ${ADMOB_APP_OPEN_PROD}
AUDIO_API_BASE_URL = https:\$()/\$()/voiceyourtext-tts-990821915106.asia-northeast1.run.app
CLOUDRUN_API_KEY = ${CLOUDRUN_KEY}
EOF
  echo "Release.xcconfig を生成しました"
fi
