# 中継サーバー（gateway）のイメージ。VOICEVOX エンジンは公式イメージをそのままサイドカーで動かす。
FROM golang:1.26-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /gateway ./cmd/gateway

# WAV → AAC の変換に ffmpeg を使う
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /gateway /gateway
USER nobody
ENTRYPOINT ["/gateway"]
