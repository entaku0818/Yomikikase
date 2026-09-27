#!/bin/bash
#
# VOICEVOX 中継サーバーを Cloud Run（東京）にデプロイする。
#
#   voicevox-server/scripts/deploy.sh setup    # 初回だけ: Artifact Registry・サービスアカウント・Secret を用意
#   voicevox-server/scripts/deploy.sh deploy   # gateway をビルドしてサービスを更新
#
# gcloud のアクティブアカウントが別プロジェクト用のことがあるので、
# 実行するアカウントは VOICEVOX_GCLOUD_ACCOUNT で渡す（既定: entaku19890818@gmail.com）。
#
set -euo pipefail

PROJECT=voiceyourtext
REGION=asia-northeast1
SERVICE=voicevox-tts
SA=voicevox-gateway@${PROJECT}.iam.gserviceaccount.com
SECRET=voicevox-revenuecat-secret-key
export CLOUDSDK_CORE_PROJECT=$PROJECT
export CLOUDSDK_CORE_ACCOUNT=${VOICEVOX_GCLOUD_ACCOUNT:-entaku19890818@gmail.com}

DIR="$(cd "$(dirname "$0")/.." && pwd)"

cmd_setup() {
    # 自前のイメージ置き場
    gcloud artifacts repositories describe voicevox --location=$REGION >/dev/null 2>&1 ||
        gcloud artifacts repositories create voicevox --location=$REGION --repository-format=docker \
            --description="VOICEVOX gateway"
    # VOICEVOX 公式イメージ（4GB超）を手元からアップロードせずに使うため、Docker Hub を中継するリモートリポジトリを置く
    gcloud artifacts repositories describe dockerhub --location=$REGION >/dev/null 2>&1 ||
        gcloud artifacts repositories create dockerhub --location=$REGION --repository-format=docker \
            --mode=remote-repository --remote-docker-repo=DOCKER-HUB \
            --description="Docker Hub proxy (VOICEVOX engine)"

    gcloud iam service-accounts describe $SA >/dev/null 2>&1 ||
        gcloud iam service-accounts create voicevox-gateway --display-name="VOICEVOX gateway"
    # 月の文字数を Firestore に書く
    gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" \
        --role=roles/datastore.user --condition=None >/dev/null

    # RevenueCat のシークレットキーは標準入力から受け取り、コマンド履歴に残さない
    if ! gcloud secrets describe $SECRET >/dev/null 2>&1; then
        echo "RevenueCat のシークレットキーを標準入力で渡してください" >&2
        gcloud secrets create $SECRET --replication-policy=automatic --data-file=-
    fi
    gcloud secrets add-iam-policy-binding $SECRET --member="serviceAccount:$SA" \
        --role=roles/secretmanager.secretAccessor >/dev/null
    echo "setup 完了"
}

cmd_deploy() {
    tag="$(git -C "$DIR" rev-parse --short HEAD)"
    if [ -n "$(git -C "$DIR" status --porcelain -- .)" ]; then
        tag="${tag}-dirty"
    fi
    image="${REGION}-docker.pkg.dev/${PROJECT}/voicevox/gateway:${tag}"

    gcloud builds submit "$DIR" --tag "$image" --region=$REGION
    digest="$(gcloud artifacts docker images describe "$image" --format='value(image_summary.digest)')"

    rendered="$(mktemp)"
    trap 'rm -f "$rendered"' EXIT
    GATEWAY_IMAGE="${image%:*}@${digest}" envsubst '${GATEWAY_IMAGE}' < "$DIR/deploy/service.yaml" > "$rendered"
    gcloud run services replace "$rendered" --region=$REGION

    # 認証は App Check で行うので、Cloud Run の IAM は誰でも呼べるようにする
    gcloud run services add-iam-policy-binding $SERVICE --region=$REGION \
        --member=allUsers --role=roles/run.invoker >/dev/null
    gcloud run services describe $SERVICE --region=$REGION --format='value(status.url)'
}

case "${1:-}" in
    setup) cmd_setup ;;
    deploy) cmd_deploy ;;
    *)
        echo "usage: $0 {setup|deploy}" >&2
        exit 64
        ;;
esac
