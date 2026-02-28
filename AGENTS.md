# AGENTS.md (3dgrut)

This file is instructions for agentic coding agents working in this repo.
Keep changes minimal, avoid touching `thirdparty/` unless required.

## Scope / Existing Rule Files

- Cursor rules: none found (no `.cursorrules` / `.cursor/rules/`).
- Copilot rules: none found (no `.github/copilot-instructions.md`).
- CI reference: `.github/workflows/ci.yaml` runs `./install_env.sh` then a smoke command.

## Quickstart (Environment)

Primary supported workflow is Conda (matches upstream docs + CI).

- Create env + install deps (CUDA toolkits, PyTorch, native extensions):
  - `./install_env.sh 3dgrut`
  - If host compiler is gcc>=12, use the optional flag:
    - `./install_env.sh 3dgrut WITH_GCC11`
  - Optional CUDA version override:
    - `CUDA_VERSION=12.8.1 ./install_env.sh 3dgrut_cuda12 WITH_GCC11`
- Activate:
  - `conda activate 3dgrut`

Notes:
- `install_env.sh` pins Python to 3.11 and installs `requirements.txt` then `pip install -e .`.
- Repo contains git submodules; `install_env.sh` runs `git submodule update --init --recursive`.

## Build / Run Commands

There is no single “build” step; native extensions are compiled during install.

Common entrypoints:
- Train:
  - `python train.py --config-name apps/nerf_synthetic_3dgrt.yaml path=data/... out_dir=runs experiment_name=...`
- Render from checkpoint:
  - `python render.py --checkpoint runs/.../ckpt_last.pt --out-dir outputs/eval`
- Playground UI:
  - `python playground.py --gs_object runs/.../ckpt_last.pt`

Playground extras:
- Extra deps:
  - `pip install -r threedgrut_playground/requirements.txt`
- Asset download:
  - `chmod +x ./threedgrut_playground/download_assets.sh`
  - `./threedgrut_playground/download_assets.sh`

## Test / Smoke Test Commands

This repo currently has no unit test suite (no `pytest` config / `tests/` tree).
CI uses a minimal smoke test:
- `python train.py --help`

Suggested “single check” commands (fast failure signals):
- CLI smoke (mirrors CI intent):
  - `python train.py --help`
- Import smoke:
  - `python -c "import threedgrut; print('ok')"`

If you add tests:
- Prefer `pytest` and place tests under `tests/`.
- Run all tests:
  - `pytest`
- Run a single test file:
  - `pytest tests/test_trainer.py`
- Run a single test by name:
  - `pytest -k test_name`

## Lint / Formatting

Upstream contribution docs specify formatting tools (see `README.md`).

- Format (apply changes):
  - `black . --target-version=py311 --line-length=120 --exclude=thirdparty/tiny-cuda-nn`
  - `isort . --skip=thirdparty/tiny-cuda-nn --profile=black`
- Check-only (for CI-style validation):
  - `black . --check --target-version=py311 --line-length=120 --exclude=thirdparty/tiny-cuda-nn`
  - `isort . --check-only --skip=thirdparty/tiny-cuda-nn --profile=black`

No repo-pinned config files for black/isort were found (no `pyproject.toml`).
Do not reformat `thirdparty/` or submodule code unless explicitly requested.

## Python Version / Typing

- Target Python: 3.11+ (see `setup.py` / `install_env.sh`).
- Prefer type hints for new or changed public APIs.
  - Use Python 3.11 built-in generics: `list[int]`, `dict[str, Any]`, `tuple[T1, T2]`.
  - Use `Protocol` for interface-like dataset contracts (pattern exists in `threedgrut/datasets/protocols.py`).
  - Use `Optional[T]` where `None` is meaningful.

## Imports

Follow the existing import style (see `train.py`, `threedgrut/trainer.py`):

1. Standard library
2. Third-party packages
3. Local imports (`threedgrut.*`)

Rules:
- Separate groups with a single blank line.
- Avoid wildcard imports.
- Avoid import cycles; if needed, prefer local imports inside functions (pattern used in `train.py`).

## Formatting / Layout

- Indentation: 4 spaces.
- Line length: 120 (align with `black --line-length=120`).
- Prefer black-compatible formatting; don’t hand-align code.
- Keep functions cohesive; avoid large “utility” modules unless existing patterns require it.

## Naming Conventions

- Modules/files: `snake_case.py`.
- Classes: `PascalCase` (e.g., `Trainer3DGRUT`).
- Functions/variables: `snake_case`.
- Constants: `UPPER_SNAKE_CASE`.
- Config keys: keep consistent with Hydra/OmegaConf config structure under `configs/`.

## Error Handling / Logging

- Use `threedgrut.utils.logger.logger` for user-facing logs.
  - `logger.info(...)`, `logger.warning(...)`, `logger.error(...)`.
- Prefer specific exceptions; avoid `except Exception` unless at a boundary where best-effort is intended.
  - If you must catch broadly, include context in the message and fail safely.
- `assert` is commonly used for invariants and shape checks (see `threedgrut/datasets/protocols.py`).
  - Use `assert` for internal invariants; raise explicit exceptions for user input / config errors.

## Config / Hydra (Important)

- Main entrypoint is Hydra (`@hydra.main(config_path="configs")` in `train.py`).
- Avoid breaking config resolution. If adding new config fields:
  - Update YAML under `configs/` accordingly.
  - Provide sensible defaults.
- When logging config, prefer `OmegaConf.to_yaml(conf)` for readability.

## Files to Treat Carefully

- `thirdparty/`: vendored code and submodules; avoid reformatting.
- Large GPU / native code paths: validate imports and basic smoke commands after edits.
- Generated artifacts should stay untracked (see `.gitignore`: `runs/`, `outputs/`, `wandb/`, `data/`, etc.).

## Git / Contributions

- Follow DCO sign-off (see `CONTRIBUTING.md`): use `git commit -s`.
- Keep PRs focused; avoid drive-by refactors.
