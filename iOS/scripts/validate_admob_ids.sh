#!/bin/sh
#
#  validate_admob_ids.sh
#  VoiceYourText
#
#  Releaseビルドに AdMob のテスト用広告ユニットID／空IDが混入したまま
#  出荷されるのを防ぐビルド時ガード。
#
#  背景: config/*.xcconfig は .gitignore 対象なので、xcconfig が無い環境で
#  Releaseビルドすると ADMOB_* が空文字に解決される。Releaseでは
#  assertionFailure が無効化されるため、広告が一切ロードされないまま
#  気付かず出荷され、広告収益がゼロになる（同系統の事故が別アプリで実際に発生）。
#
#  このスクリプトは Xcode の Run Script ビルドフェーズから実行され、
#  CONFIGURATION=Release のときに問題を検出するとビルドを失敗させる。
#

set -u

# Google公式のテスト用パブリッシャーID。このプレフィックスで始まるIDは本番出荷禁止。
TEST_PUBLISHER_ID="ca-app-pub-3940256099942544"

# Releaseで必須のキー（未設定・空もエラー）
REQUIRED_KEYS="ADMOB_BANNER_ID ADMOB_APP_OPEN_ID"

# 存在すれば検証するキー（未設定は許容。app_open / rewarded を追加したら
# 自動的にこのガードの対象になる）
OPTIONAL_KEYS="ADMOB_INTERSTITIAL_ID ADMOB_REWARDED_ID"

RELEASE_XCCONFIG_PATH="iOS/VoiceYourText/config/Release.xcconfig"
CI_SCRIPT_PATH="iOS/ci_scripts/ci_post_clone.sh"

# 検出した問題を蓄積する
problems=""

add_problem() {
    problems="${problems}$1
"
}

value_of() {
    # 環境変数（= ビルド設定）を間接参照する
    eval "printf '%s' \"\${$1:-}\""
}

check_key() {
    key="$1"
    required="$2"
    value="$(value_of "$key")"

    if [ -z "$value" ]; then
        if [ "$required" = "required" ]; then
            add_problem "  • ${key}: 未設定（空）です。"
        fi
        return 0
    fi

    case "$value" in
        "${TEST_PUBLISHER_ID}"*)
            add_problem "  • ${key}: Googleのテスト用IDのままです（${value}）"
            return 0
            ;;
    esac

    # 書式チェック。サンプルのプレースホルダ（ca-app-pub-XXXX.../XXXX...）や
    # コピペ時の欠けをここで落とす。
    if ! printf '%s' "$value" | grep -Eq '^ca-app-pub-[0-9]{16}/[0-9]{10}$'; then
        add_problem "  • ${key}: 広告ユニットIDの書式ではありません（${value}）"
    fi
}

# --- Info.plist にハードコードされている GADApplicationIdentifier も検証 ---
check_gad_application_identifier() {
    plist="${SRCROOT:-.}/${INFOPLIST_FILE:-VoiceYourText/Info.plist}"
    [ -f "$plist" ] || return 0

    app_id="$(/usr/libexec/PlistBuddy -c 'Print :GADApplicationIdentifier' "$plist" 2>/dev/null || true)"
    [ -n "$app_id" ] || return 0

    case "$app_id" in
        "${TEST_PUBLISHER_ID}"*)
            add_problem "  • GADApplicationIdentifier: Googleのテスト用アプリIDのままです（${app_id}）"
            ;;
    esac
}

# ---------------------------------------------------------------------------

for key in $REQUIRED_KEYS; do
    check_key "$key" required
done

for key in $OPTIONAL_KEYS; do
    check_key "$key" optional
done

check_gad_application_identifier

if [ -z "$problems" ]; then
    echo "AdMob ID validation: OK (configuration=${CONFIGURATION:-unknown})"
    exit 0
fi

# Debug等では情報ログのみ。テストIDはDebugでは「正しい」状態なので
# warning: を出すとIssueナビゲータを汚して本物の警告が埋もれる。
if [ "${CONFIGURATION:-}" != "Release" ]; then
    echo "AdMob ID validation: ${CONFIGURATION:-unknown} ビルドなので許容（Releaseではビルドを失敗させます）"
    printf '%s' "$problems" | while IFS= read -r line; do
        [ -n "$line" ] && echo "note:${line#  •}"
    done
    exit 0
fi

# --- Releaseビルド: ここで落とす ---
cat >&2 << MESSAGE
error: Releaseビルドに本番のAdMob広告ユニットIDが設定されていません。このままでは広告収益がゼロになるため、ビルドを中止しました。

テストIDのまま／未設定の項目:
${problems}
本番IDの書き込み先:
  1) ローカルビルド:
     ${RELEASE_XCCONFIG_PATH}
     （.gitignore 対象。無ければ ${RELEASE_XCCONFIG_PATH}.sample をコピーして作成）
     例: ADMOB_BANNER_ID = ca-app-pub-3484697221349891/XXXXXXXXXX

  2) Xcode Cloud:
     ビルドワークフローの環境変数に同名のキー（例: ADMOB_BANNER_ID）を設定する。
     ${CI_SCRIPT_PATH} が環境変数から Release.xcconfig を生成します。

  3) GADApplicationIdentifier の場合:
     iOS/VoiceYourText/Info.plist の GADApplicationIdentifier を本番のAdMobアプリID
     （ca-app-pub-3484697221349891~7968499014）に戻してください。

本番IDは AdMob 管理画面 > アプリ > 広告ユニット から取得できます。
MESSAGE

exit 1
