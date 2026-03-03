#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./colmap_fa.sh [--name NAME] [--input DIR] [--out DIR] [options]

Purpose:
  Run COLMAP on images under assets/scene (by default) and generate a COLMAP-style
  dataset layout under data/ that 3DGRUT can load (dataset.type=colmap).

Default behavior:
  - Input images:  ./assets/scene
  - Output dataset: ./data/scene_colmap
  - Pipeline: feature_extractor -> matcher -> mapper -> image_undistorter

Options:
  --name NAME           Dataset folder name under --out (default: scene_colmap)
  --input DIR           Input images directory (default: ./assets/scene)
  --out DIR             Output base directory (default: ./data)
  --single-camera 0|1   Treat all images as one camera (default: 1)
  --camera-model MODEL  COLMAP camera model for feature extraction (default: PINHOLE)
  --matcher TYPE        exhaustive|sequential (default: exhaustive)
  --use-gpu 0|1         Use GPU for SIFT when available (default: 1)
  --max-image-size N    Max image size for undistorter (some COLMAP builds forbid 0; default: 8192)
  --force               Remove existing output dataset directory
  --keep-work           Keep intermediate .colmap_work directory
  -h, --help            Show this help

Notes:
  - 3DGRUT 的 ColmapDataset 只支援 (undistorted) 相機模型：
    SIMPLE_PINHOLE, PINHOLE, OPENCV_FISHEYE
    所以這個 script 會跑 image_undistorter 產生 undistorted images + sparse model。

Example:
  ./colmap_fa.sh --name my_scene
  python train.py --config-name apps/colmap_3dgrt.yaml path=data/my_scene out_dir=runs experiment_name=my_scene
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"

name="scene_colmap"
input_dir="$repo_root/assets/scene"
out_base="$repo_root/data"

single_camera="1"
camera_model="PINHOLE"
matcher_type="exhaustive"
use_gpu="1"
max_image_size="8192"
force="0"
keep_work="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      name="$2"; shift 2 ;;
    --input)
      input_dir="$2"; shift 2 ;;
    --out)
      out_base="$2"; shift 2 ;;
    --single-camera)
      single_camera="$2"; shift 2 ;;
    --camera-model)
      camera_model="$2"; shift 2 ;;
    --matcher)
      matcher_type="$2"; shift 2 ;;
    --use-gpu)
      use_gpu="$2"; shift 2 ;;
    --max-image-size)
      max_image_size="$2"; shift 2 ;;
    --force)
      force="1"; shift 1 ;;
    --keep-work)
      keep_work="1"; shift 1 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if ! command -v colmap >/dev/null 2>&1; then
  echo "ERROR: 'colmap' not found in PATH." >&2
  echo "Hint (NixOS): try 'nix shell nixpkgs#colmap' then rerun." >&2
  exit 1
fi

abspath() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p"
  elif command -v readlink >/dev/null 2>&1; then
    readlink -f "$p"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$p"
  else
    echo "$p"
  fi
}

# Normalize paths to avoid broken relative symlinks under .colmap_work/.
input_dir="$(abspath "$input_dir")"
out_base="$(abspath "$out_base")"

if [[ ! -d "$input_dir" ]]; then
  echo "ERROR: input_dir not found: $input_dir" >&2
  exit 1
fi

# Some COLMAP builds abort if max_image_size == 0.
if [[ "$max_image_size" == "0" ]]; then
  echo "WARN: --max-image-size 0 is not supported by this COLMAP build; using 8192 instead" >&2
  max_image_size="8192"
fi

shopt -s nullglob
images=(
  "$input_dir"/*.jpg "$input_dir"/*.JPG
  "$input_dir"/*.jpeg "$input_dir"/*.JPEG
  "$input_dir"/*.png "$input_dir"/*.PNG
)
shopt -u nullglob

if [[ ${#images[@]} -eq 0 ]]; then
  echo "ERROR: no images found in: $input_dir" >&2
  exit 1
fi

out_dir="$out_base/$name"
work_dir="$out_dir/.colmap_work"

if [[ -e "$out_dir" ]]; then
  if [[ "$force" == "1" ]]; then
    rm -rf "$out_dir"
  else
    echo "ERROR: output already exists: $out_dir" >&2
    echo "Pass --force to overwrite." >&2
    exit 1
  fi
fi

mkdir -p "$work_dir"

# Use a symlink so COLMAP sees a normal image directory.
# NOTE: input_dir is normalized to an absolute path above, to avoid broken relative links.
ln -sfn "$input_dir" "$work_dir/images"

warn() {
  echo "WARN: $*" >&2
}

supports_colmap_option() {
  local subcmd="$1"
  local needle="$2"

  if colmap "$subcmd" --help 2>&1 | grep -qF "$needle"; then
    return 0
  fi

  # Some builds expose help via `colmap help <subcmd>`.
  if colmap help "$subcmd" 2>&1 | grep -qF "$needle"; then
    return 0
  fi

  return 1
}

feature_cmd=(
  colmap feature_extractor
  --database_path "$work_dir/database.db"
  --image_path "$work_dir/images"
  --ImageReader.single_camera "$single_camera"
  --ImageReader.camera_model "$camera_model"
)

# COLMAP builds differ; add GPU flags only if supported.
if supports_colmap_option feature_extractor "SiftExtraction.use_gpu"; then
  feature_cmd+=(--SiftExtraction.use_gpu "$use_gpu")
else
  warn "COLMAP does not support SiftExtraction.use_gpu; running without it"
fi

matcher_cmd=()
case "$matcher_type" in
  exhaustive)
    matcher_cmd=(colmap exhaustive_matcher --database_path "$work_dir/database.db")
    if supports_colmap_option exhaustive_matcher "SiftMatching.use_gpu"; then
      matcher_cmd+=(--SiftMatching.use_gpu "$use_gpu")
    else
      warn "COLMAP does not support SiftMatching.use_gpu; running without it"
    fi
    ;;
  sequential)
    matcher_cmd=(colmap sequential_matcher --database_path "$work_dir/database.db")
    if supports_colmap_option sequential_matcher "SiftMatching.use_gpu"; then
      matcher_cmd+=(--SiftMatching.use_gpu "$use_gpu")
    else
      warn "COLMAP does not support SiftMatching.use_gpu; running without it"
    fi
    ;;
  *)
    echo "ERROR: unknown --matcher: $matcher_type (use exhaustive|sequential)" >&2
    exit 2
    ;;
esac

set -x

"${feature_cmd[@]}"
"${matcher_cmd[@]}"

mkdir -p "$work_dir/sparse"

colmap mapper \
  --database_path "$work_dir/database.db" \
  --image_path "$work_dir/images" \
  --output_path "$work_dir/sparse"

# Generate undistorted images + sparse model.
# This is important because 3DGRUT's ColmapDataset only supports undistorted camera models.
colmap image_undistorter \
  --image_path "$work_dir/images" \
  --input_path "$work_dir/sparse/0" \
  --output_path "$out_dir" \
  --output_type COLMAP \
  --max_image_size "$max_image_size"

# 3DGRUT expects COLMAP model under sparse/0/.
if [[ -d "$out_dir/sparse" && ! -d "$out_dir/sparse/0" ]]; then
  mkdir -p "$out_dir/sparse/0"
fi

# Some COLMAP versions output cameras/images/points directly under sparse/.
# Move them into sparse/0/ if needed.
if [[ -d "$out_dir/sparse" ]]; then
  shopt -s nullglob
  to_move=("$out_dir/sparse"/*.bin "$out_dir/sparse"/*.txt)
  shopt -u nullglob

  if [[ ${#to_move[@]} -gt 0 ]]; then
    for f in "${to_move[@]}"; do
      mv "$f" "$out_dir/sparse/0/"
    done
  fi
fi

set +x

echo ""
echo "Done. 3DGRUT dataset generated:" 
echo "  $out_dir"
echo ""
echo "Try training:" 
echo "  python train.py --config-name apps/colmap_3dgrt.yaml path=data/$name out_dir=runs experiment_name=$name"

echo ""
echo "Contents check (expected):" 
echo "  $out_dir/images/"
echo "  $out_dir/sparse/0/cameras.bin (or .txt)"
echo "  $out_dir/sparse/0/images.bin  (or .txt)"
echo "  $out_dir/sparse/0/points3D.bin (or .txt)"

if [[ "$keep_work" != "1" ]]; then
  rm -rf "$work_dir"
fi
