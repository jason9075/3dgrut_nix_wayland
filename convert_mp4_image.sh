#!/usr/bin/env bash

# 使用方式範例：
# 1. 預設模式：./extract.sh
# 2. 自定義：  ./extract.sh input.mp4 ./output 5

INPUT="${1:-assets/desk2.mp4}"
OUTPUT="${2:-assets/$(basename "$INPUT" .mp4)}" # 自動從檔名取出目錄名
FPS="${3:-2}"

mkdir -p "$OUTPUT"
ffmpeg -i "$INPUT" -qscale:v 2 -vf "fps=$FPS" "$OUTPUT/frame_%04d.jpg"

