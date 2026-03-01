set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Project-local venv for lightweight utilities (e.g., kagglehub).
VENV_DIR := ".venv"
PY := VENV_DIR + "/bin/python"
PIP := VENV_DIR + "/bin/pip"

_default:
  @just --list

# ---------- Formatting ----------

fmt:
  black . --target-version=py311 --line-length=120 --exclude=thirdparty/tiny-cuda-nn
  isort . --skip=thirdparty/tiny-cuda-nn --profile=black

fmt-check:
  black . --check --target-version=py311 --line-length=120 --exclude=thirdparty/tiny-cuda-nn
  isort . --check-only --skip=thirdparty/tiny-cuda-nn --profile=black

# ---------- Smoke tests ----------

smoke:
  python train.py --help

import-smoke:
  python -c "import threedgrut; print('ok')"

# ---------- Conda environment ----------

# Creates/updates the conda env following upstream script.
# Examples:
#   just conda-env
#   just conda-env 3dgrut WITH_GCC11
#   CUDA_VERSION=12.8.1 just conda-env 3dgrut_cuda12 WITH_GCC11
conda-env ENV="3dgrut" FLAG="":
  ./install_env.sh {{ENV}} {{FLAG}}

# ---------- Docker workflow ----------

DOCKER_IMAGE := "3dgrut"

# Upstream README flow (from outside the repo):
#   git clone --recursive https://github.com/nv-tlabs/3dgrut.git
#   cd 3dgrut
#   just docker-build
#
docker-build IMAGE=DOCKER_IMAGE CUDA_VERSION="11.8.0":
  docker build . -t {{IMAGE}} --build-arg CUDA_VERSION={{CUDA_VERSION}} --progress=plain

docker-build-no-cache IMAGE=DOCKER_IMAGE CUDA_VERSION="11.8.0":
  docker build --no-cache . -t {{IMAGE}} --build-arg CUDA_VERSION={{CUDA_VERSION}} --progress=plain

docker-smoke IMAGE=DOCKER_IMAGE:
  docker run --rm -it {{IMAGE}} bash -lc "conda run -n 3dgrut python -c 'import rich, hydra, omegaconf; print(\"deps ok\")' && conda run -n 3dgrut python train.py --help"

# If you want X11 windows (Polyscope GUI) on Wayland, you generally need XWayland.
# Host-side setup (once per session):
#   xhost +SI:localuser:root
#
# IMPORTANT: Do NOT mount the full repo into /workspace.
# The image contains submodules and build-time deps; mounting the repo often hides them.
# Instead, mount only mutable dirs (data/runs/outputs).
#
docker-run IMAGE=DOCKER_IMAGE DATA_DIR="data" RUNS_DIR="runs" OUTPUTS_DIR="outputs":
  mkdir -p "{{DATA_DIR}}" "{{RUNS_DIR}}" "{{OUTPUTS_DIR}}"
  docker run --rm -it \
    --device nvidia.com/gpu=all \
    --net=host --ipc=host \
    -e DISPLAY="${DISPLAY:-}" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
    -e XDG_RUNTIME_DIR="/run/user/${UID}" \
    -v "/run/user/${UID}:/run/user/${UID}" \
    -v "$PWD/{{DATA_DIR}}:/workspace/{{DATA_DIR}}" \
    -v "$PWD/{{RUNS_DIR}}:/workspace/{{RUNS_DIR}}" \
    -v "$PWD/{{OUTPUTS_DIR}}:/workspace/{{OUTPUTS_DIR}}" \
    {{IMAGE}}

# ---------- Sample data via KaggleHub ----------

# Create a small local venv and install kagglehub.
# This is independent of the CUDA-heavy conda environment.
venv:
  python -m venv {{VENV_DIR}}
  {{PIP}} install -U pip
  {{PIP}} install kagglehub

# Download a Kaggle dataset using kagglehub.
# Auth: set KAGGLE_USERNAME/KAGGLE_KEY or provide ~/.kaggle/kaggle.json.
# Example:
#   just kaggle-download "zynicide/wine-reviews" data/kaggle/wine
kaggle-download dataset out_dir="data/kaggle": venv
  {{PY}} -c "from pathlib import Path; import shutil; import kagglehub; dataset='{{dataset}}'; out_dir=Path('{{out_dir}}'); downloaded_path=Path(kagglehub.dataset_download(dataset)); print(f'Downloaded to: {downloaded_path}'); out_dir.mkdir(parents=True, exist_ok=True); shutil.copytree(downloaded_path, out_dir, dirs_exist_ok=True); print(f'Copied into: {out_dir.resolve()}')"
