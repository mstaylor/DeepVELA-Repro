# MLPerf 3D U-Net KiTS19 Reproduction on TACC Vista

This report covers the rerun of the MLPerf Inference 3D U-Net KiTS19 accuracy benchmark on one TACC Vista GH200 node. The task is `dataset/tasks/mlperf-vision-medical-imaging-3d-unet.json`. The scripts are in `hpc/vista/3d-unet-kits19/` and the plan is in that directory's README. The run uses the PyTorch backend, fp32 and the Offline scenario in accuracy mode.

## Result

The full run over all 43 inference cases matches the reference accuracy published in the pinned benchmark README.

| | Mean DICE | Kidney | Tumor |
|---|---|---|---|
| MLPerf reference (README at the pinned commit) | 0.86170 | 0.9347 | 0.7887 |
| Vista, 43 cases as the evaluator prints them | **0.86167** | **0.9347** | **0.7887** |
| Vista, 43 cases from `summary.csv` at full precision | 0.861675 | 0.934686 | 0.788664 |
| Vista, 42 cases without the case_00400 duplicate | 0.86329 | 0.93418 | 0.79241 |

Kidney and tumor match the reference to every printed digit. The mean differs by 0.00003, which is within the rounding of the reference table, since the reference mean of the two printed class scores is also 0.8617. The result clears the 99% target of 0.85308 and the 99.9% target of 0.86084.

The reference evaluator scores 43 cases, and one of them is case_00400, which the Makefile creates as a copy of case_00185. The task record leaves that duplicate out, so the 42-case row is computed from the per-case `summary.csv` without case_00400. It is labeled separately and is not the number the reference reports.

The same full run was submitted twice, once to `gh` and once to `gh-dev`, to shorten queue time. Both copies ran on different nodes and produced byte-identical `summary.csv` files, so the result is deterministic across nodes.

## Platform

| Item | Value |
|---|---|
| System | TACC Vista, one node per job |
| GPU | NVIDIA GH200 120GB (97,871 MiB visible), driver 615.71.09 |
| CPU | 72 core ARM Neoverse-V2, aarch64 |
| Container | Apptainer SIF of `nvcr.io/nvidia/pytorch:24.04-py3` (arm64), Ubuntu 22.04.4 |
| Python | 3.10.12 |
| PyTorch | 2.3.0a0+6ddf5cf85e.nv24.04, CUDA 12.4, cuDNN 9.1.0 |
| Device line | `pytorch device: cuda:0` |
| TF32 | `cudnn.allow_tf32 True`, `matmul.allow_tf32 True` (the container default) |
| Benchmark source | `mlcommons/inference` at `3fbc329939999c13d0a7b5e67fb2092287e06047` |
| LoadGen | 6.0.17, built from `loadgen/` at the same commit |
| Dataset source | `neheller/kits19` at `456b293435b25303bbc7995f094f83a0afdff0eb` |
| Model | `3dunet_kits19_pytorch.ptc` from Zenodo record 5597155, md5 `2251109371f408c9f10a4320ffdcaef8` (matches the record) |

## Deviations from the reference and why

1. **Container image.** The reference Dockerfile uses `nvcr.io/nvidia/pytorch:20.12-py3`, which is published only for x86_64. Vista is aarch64, so the run uses the arm64 `24.04-py3` image.
2. **Package pins.** The newer image needs three pins so the unchanged benchmark code runs.
   * SciPy 1.12.0, because SciPy 1.13 removed `scipy.signal.gaussian`, which `inference_utils.py` calls.
   * pandas 1.5.3, because pandas 2 removed `DataFrame.append`, which `accuracy_kits.py` calls.
   * nibabel 3.2.1, the version the reference Dockerfile pins.
   * NumPy stays at the image version, 1.24.4.
3. **LoadGen source.** The reference Dockerfile builds LoadGen from the unpinned inference HEAD. Here it is built from the pinned commit.
4. **Virtual environment.** The venv is created with `--system-site-packages --without-pip` on top of the image, because the image has no `ensurepip`. Pip is run as `venv/bin/python -m pip`.
5. **Device reporting.** `run_with_device.py` runs `run.py` unchanged and prints the device of the loaded model's parameters. No benchmark file is edited.
6. **Separate evaluation step.** `SKIP_VERIFY_ACCURACY=1` is set so that `accuracy_kits.py` runs as its own timed step on `mlperf_log_accuracy.json`. It is the same command `run.py` would run.

No model, preprocessing or evaluation code was changed.

## Data and preprocessing

All 300 KiTS19 cases downloaded (27 GB, none missing), and all inference cases were present. case_00185 was copied to case_00400 as the Makefile does. `preprocess.py --mode preprocess` wrote 43 case files and reported "All files' checksums match" against `meta/checksum_inference.json`, so the newer NumPy and SciPy builds produce byte-identical preprocessed data.

## Jobs and wall times

| Job | Stage | Partition | Node | State | Elapsed |
|---|---|---|---|---|---|
| 1151920 | setup | gg | i617-113 | FAILED (no `ensurepip`) | 1:13:18 |
| 1154642 | setup | gg | i614-132 | COMPLETED | 0:01:44 |
| 1154792 | download | gh-dev | c642-012 | COMPLETED | 0:11:07 |
| 1154793 | preprocess | gh-dev | c642-051 | COMPLETED | 0:01:00 |
| 1154794 | smoke run, 2 cases | gh-dev | c642-052 | COMPLETED | 0:00:24 |
| 1156401 | full run, 43 cases | gh | c641-092 | COMPLETED | 0:02:04 |
| 1156431 | full run, 43 cases | gh-dev | c642-031 | COMPLETED | 0:02:04 |

Stage times recorded inside the jobs:

| Stage | Seconds |
|---|---|
| NGC image pull and SIF build (job 1151920) | 4,347.7 |
| venv and LoadGen build (job 1154642) | 92.9 |
| KiTS19 download | 646.9 |
| Preprocess and checksum check | 53.8 |
| Model run, 43 cases (gh / gh-dev) | 75.3 / 76.3 |
| Evaluation, 43 cases (gh / gh-dev) | 36.6 / 36.4 |

The largest case, 384 by 384 by 384 with 125 sub-volumes, took 2.8 s of inference.

Download, preprocess and the smoke run were moved from gg to gh-dev with the user's approval because the gg queue would have delayed the GPU runs. Setup ran on gg.

## Smoke run

The two-case smoke run (case_00000 and case_00003) scored mean 0.90345, kidney 0.9689 and tumor 0.8380. It checked GPU detection, model load, LoadGen and the evaluator before the full run.

## Problems and fixes

1. **No `ensurepip` in the NGC image.** The first setup job pulled the image (72 minutes) and then failed to create the venv. The fix was to build the venv with `--system-site-packages --without-pip`. The retry reused the SIF and finished in 1m44s.
2. **One package index unreachable from the compute node.** During the kits19 requirements install, pip could not resolve one extra index host for `imageio` and fell back to PyPI after retries. The install succeeded.
3. **LoadGen config error.** `mlperf_log_detail.txt` records one error, "Multiple conf files are used. This is not valid for official submission." It comes from loading both `mlperf.conf` and `user.conf` as the reference harness does. It does not affect accuracy, but these logs are not valid as an official submission.
4. **Both full run copies ran.** The plan was to cancel whichever copy started second. The gh-dev copy started about 4.5 minutes before the gh copy, but the cancel never ran, so about 0.07 node hours were spent instead of about 0.035.

## Files

Run outputs are copied to `~/cylon_experiments/deepvela/vista/3d-unet-kits19/` by `fetch_results.sh`.

| Path | Content |
|---|---|
| `runs/full/accuracy.txt`, `runs/full_ghdev/accuracy.txt` | Evaluator output |
| `runs/full/postprocessed_data/summary.csv` | Per-case kidney, tumor and composite DICE |
| `runs/full/logs/` | LoadGen summary, detail and trace logs |
| `runs/full/platform.txt` | `nvidia-smi`, `lscpu`, torch and TF32 settings |
| `runs/*/pip_freeze.txt`, `env/pip_freeze.txt` | Package versions |
| `env/` | Commits, model md5, download and preprocess status, versions |
| `timings.tsv` | Per-stage start, end and duration |
| `jobs/` | Slurm job logs |

`mlperf_log_accuracy.json` and the postprocessed case volumes stay on Vista under `$SCRATCH/mlperf-3dunet/runs/`.
