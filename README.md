<p align="center">
  <img height="100" src="assets/3dgrut_logo.png">
</p>

---

<p align="center">
  <img width="100%" src="assets/nvidia-hq-playground.gif">
</p>

# 3dgrut_nix_wayland (fork)

This repository is a fork of NVIDIA `nv-tlabs/3dgrut`, tuned for a **NixOS + Wayland + Docker** workflow.

Key differences from upstream:

- Prefer Docker-first execution (avoid managing CUDA/conda toolchains on the host).
- Use **NVIDIA CDI** for GPUs (`--device nvidia.com/gpu=all`) instead of relying on `--gpus=all` / `--runtime=nvidia`.
- Provide a `Justfile` with common commands.
- Provide a `flake.nix` devShell with tooling (`just`, `black`, `isort`, `xhost`, etc.).
- Include `kagglehub` and `viser` in `requirements.txt` for convenience.

Upstream research context:

- 3DGRT: https://research.nvidia.com/labs/toronto-ai/3DGRT
- 3DGUT: https://research.nvidia.com/labs/toronto-ai/3DGUT

---

## Quickstart (recommended: Docker + CDI)

### 1) Host prerequisites (NixOS)

- NVIDIA driver installed.
- Docker daemon configured with NVIDIA CDI.

Typical NixOS configuration snippet (adjust to your setup):

```nix
{
  virtualisation.docker.enable = true;

  # Expose NVIDIA GPUs via CDI (nvidia.com/gpu=all)
  hardware.nvidia-container-toolkit.enable = true;
}
```

Verify CDI is available:

```bash
docker info | rg -n "cdi: nvidia.com/gpu=all" || true
```

### 2) Enter dev shell (optional)

If you want `just`, `xhost`, and formatting tools available:

```bash
nix develop path:.
```

### 3) Build the Docker image

```bash
just docker-build
```

For CUDA 12.8.1 (e.g. Blackwell support):

```bash
just docker-build 3dgrut 12.8.1
```

Notes:
- `docker-build` vendors the repo (including submodules) into the image.
- The image build runs `./install_env.sh` to create the conda env inside the container.

### 4) Run the container (default: do not mount the repo)

```bash
just docker-run
```

This:
- Mounts GPUs via CDI: `--device nvidia.com/gpu=all`
- Uses `--net=host --ipc=host`
- Does **not** mount the full repo into `/workspace` (prevents hiding submodules in the image)
- Only mounts mutable dirs: `data/`, `runs/`, `outputs/`

Inside the container, run training:

```bash
conda run -n 3dgrut python train.py \
  --config-name apps/nerf_synthetic_3dgut.yaml \
  path=data/nerf_synthetic/lego \
  out_dir=runs experiment_name=lego_3dgut
```

---

## Sample data (KaggleHub)

This fork includes `kagglehub` in `requirements.txt`, and also provides a host-side helper in `Justfile`.
The recommended flow is:

1) Download datasets on the host into `data/`.
2) Run the container with `just docker-run` (which mounts `data/` into the container).

Auth:
- Set `KAGGLE_USERNAME` / `KAGGLE_KEY`, or
- Provide `~/.kaggle/kaggle.json`.

Example:

```bash
just kaggle-download "nguyenhung1903/nerf-synthetic-dataset" data/kaggle/nerf
```

Then in the container, point configs at paths under `data/kaggle/...`.

---

## GUI on Wayland

There are two practical GUI options.

### A) Polyscope GUI (X11 window via XWayland)

If you use `with_gui=True`, you need XWayland and you typically must allow the container to connect to your X server.

On the host (once per session):

```bash
xhost +SI:localuser:root
```

Run the container:

```bash
just docker-run
```

Inside the container:

```bash
conda run -n 3dgrut python train.py \
  --config-name apps/nerf_synthetic_3dgut.yaml \
  path=data/nerf_synthetic/lego \
  out_dir=runs experiment_name=lego_3dgut \
  with_gui=True
```
```bash
python train.py   --config-name apps/nerf_synthetic_3dgut.yaml   path=data/kaggle/nerf/nerf_synthetic/lego/   out_dir=runs experiment_name=lego_3dgut   with_viser_gui=True export_usdz.enabled=true
```

Note: the window may start black; adjust the camera/view.

### B) Viser GUI (browser-based; recommended for Docker/Wayland)

This fork includes `viser` in `requirements.txt`.

Inside the container:

```bash
conda run -n 3dgrut python train.py \
  --config-name apps/nerf_synthetic_3dgut.yaml \
  path=data/nerf_synthetic/lego \
  out_dir=runs experiment_name=lego_3dgut \
  with_viser_gui=True
```

Since `docker-run` uses `--net=host`, open on the host:

- http://localhost:8080

---

## Common commands (Justfile)

- List commands: `just`
- Build image: `just docker-build`
- Run shell: `just docker-run`
- Format: `just fmt`
- Format check: `just fmt-check`
- Smoke: `just smoke`

---

## Troubleshooting

### 1) `--gpus=all` / `--runtime=nvidia` fails

On NixOS, `--gpus=all` may not be enabled depending on how Docker is configured.
This fork defaults to CDI:

- `--device nvidia.com/gpu=all`

Verify CDI:

```bash
docker info | rg -n "cdi: nvidia.com/gpu=all" || true
```

### 2) `tiny-cuda-nn/common.h: No such file or directory`

Most commonly caused by mounting the host repo into `/workspace` and hiding the image’s submodules.
This fork’s `just docker-run` does **not** mount the full repo.

If you insist on a full repo bind mount for development, ensure submodules exist on the host:

```bash
git submodule update --init --recursive
```

### 3) `fatal: detected dubious ownership in repository at '/workspace'`

If you bind-mount a repo and the container user differs from the host owner, git may refuse to operate.

Inside the container:

```bash
git config --global --add safe.directory /workspace
```

---

## Formatting

Upstream formatting commands:

```bash
black . --target-version=py311 --line-length=120 --exclude=thirdparty/tiny-cuda-nn
isort . --skip=thirdparty/tiny-cuda-nn --profile=black
```

This fork provides:
- `just fmt`
- `just fmt-check`
