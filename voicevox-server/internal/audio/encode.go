// Package audio は VOICEVOX の WAV をアプリに返す形式へ変換する。
package audio

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// Encoder は WAV を別形式にする。
type Encoder interface {
	Encode(ctx context.Context, wav []byte) (data []byte, format string, err error)
}

// FFmpegAAC は WAV を AAC（m4a コンテナ）にする。
// WAV（24kHz/16bit モノラル）は約 48KB/秒あり、1回18分の読み上げで約52MBになるため、
// 64kbps AAC（約 8KB/秒）に落としてモバイル回線の通信量と端末の保存容量を抑える。
type FFmpegAAC struct {
	Path    string
	Bitrate string
}

// Encode は ffmpeg を標準入出力で呼ぶ。
func (e FFmpegAAC) Encode(ctx context.Context, wav []byte) ([]byte, string, error) {
	path := e.Path
	if path == "" {
		path = "ffmpeg"
	}
	bitrate := e.Bitrate
	if bitrate == "" {
		bitrate = "64k"
	}
	// m4a は moov atom を末尾に書くため seek できない pipe には出せない。
	// 一時ファイルに書き、+faststart で moov を先頭に移した通常の m4a にする。
	dir, err := os.MkdirTemp("", "voicevox-aac-")
	if err != nil {
		return nil, "", err
	}
	defer os.RemoveAll(dir)
	out := filepath.Join(dir, "out.m4a")

	cmd := exec.CommandContext(ctx, path,
		"-hide_banner", "-loglevel", "error",
		"-f", "wav", "-i", "pipe:0",
		"-c:a", "aac", "-b:a", bitrate,
		"-movflags", "+faststart",
		"-y", out,
	)
	cmd.Stdin = bytes.NewReader(wav)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, "", fmt.Errorf("ffmpeg: %w: %s", err, stderr.String())
	}
	data, err := os.ReadFile(out)
	if err != nil {
		return nil, "", err
	}
	return data, "m4a", nil
}

// Passthrough は WAV をそのまま返す（ローカル開発・テスト用）。
type Passthrough struct{}

// Encode は入力をそのまま返す。
func (Passthrough) Encode(_ context.Context, wav []byte) ([]byte, string, error) {
	return wav, "wav", nil
}
