# MLPerf 3D U-Net KiTS19 on TACC Vista

This directory reruns the MLPerf Inference 3D U-Net KiTS19 accuracy benchmark on one Vista GH200 node in Apptainer. The run uses the PyTorch backend, fp32 and the Offline scenario in accuracy mode. It reruns the task in `dataset/tasks/mlperf-vision-medical-imaging-3d-unet.json` on a new platform. It does not run the DeepVELA three-arm harness. The scientific task stays fixed and every implementation change is recorded in `docs/vista-3d-unet-kits19-reproduction.md`.

Benchmark source: `mlcommons/inference` at commit `3fbc329939999c13d0a7b5e67fb2092287e06047`, directory `vision/medical_imaging/3d-unet-kits19`.

## Files

| File | Runs on | Purpose |
|------|---------|---------|
| `env.sh` | compute node | Paths, image name, Apptainer helpers, stage timing |
| `pins.txt` | compute node | Package pins added on top of the image |
| `setup.slurm` | gg | Clones, model download, image pull, venv, LoadGen build |
| `download.slurm` | gg | KiTS19 raw data download (written after setup clones kits19) |
| `preprocess.slurm` | gg | `preprocess.py --mode preprocess`, which also checks checksums |
| `run.slurm` | gh-dev or gh | `run.py` in accuracy mode, then `accuracy_kits.py` |
| `run_with_device.py` | compute node | Runs `run.py` unchanged and prints the `pytorch device:` line |
| `subset_preprocessed.py` | compute node | Builds a few-case preprocessed view for the smoke run |
| `stage.sh` | local | Copies this directory to `$SCRATCH/mlperf-3dunet/scripts` on Vista |
| `submit.sh` | Vista login node | `sbatch` with the full account, prints only the job id |
| `fetch_results.sh` | local | Copies run outputs back to `~/cylon_experiments/deepvela/vista/3d-unet-kits19/` |

Everything on Vista lives under `$SCRATCH/mlperf-3dunet/`.

## Why every stage is a Slurm job

The TACC Good Conduct Guide requires all AI-assisted workloads to run on compute nodes. The login node is kept to ssh, sbatch, squeue, sacct, ls, small edits and staging. Setup is all downloads and installs: two git clones, the Zenodo model download, `pip install` and the LoadGen C++ build. Pulling the NGC image and converting it to a SIF takes several GB and many minutes of CPU, memory and disk, which TACC asks users not to do on shared login nodes. The `apptainer` command is also not on the login node path. The proven Vista scripts in `cylon-armada/target/tacc/scripts/` load it with `module load tacc-apptainer` inside compute jobs, and `pull_image.slurm` pulls its image inside a gg job the same way.

The cost is queue time. If gg stays busy, setup can move to gh-dev for about 1 SU instead of about 0.3 SU.

## Plan

### 1. Setup (`setup.slurm`, gg, 2 h limit)

1. Clone `mlcommons/inference` with only `loadgen/`, the 3d-unet-kits19 folder and `mlperf.conf` checked out, then check out the pinned commit and verify HEAD.
2. Clone `neheller/kits19` and record its commit.
3. Download `3dunet_kits19_pytorch.ptc` from Zenodo record 5597155 and check its md5 against the record API.
4. Pull `nvcr.io/nvidia/pytorch:24.04-py3` (arm64, CUDA 12.4) as a SIF. The reference image `nvcr.io/nvidia/pytorch:20.12-py3` is x86_64 only and cannot run on Vista.
5. Build a venv on top of the image with the pins in `pins.txt`:
   * SciPy 1.12.0, because SciPy 1.13 removed `scipy.signal.gaussian`, which `inference_utils.py` uses, and `preprocess.py` imports the deprecated `scipy.ndimage.interpolation`.
   * pandas 1.5.3, because pandas 2 removed `DataFrame.append`, which `accuracy_kits.py` uses.
   * nibabel 3.2.1, the version the reference Dockerfile pins.
   * NumPy held at the image version.
6. Build LoadGen from `loadgen/` at the pinned commit. The reference Dockerfile clones the unpinned inference HEAD for this.
7. Record `pip freeze`, the torch, CUDA and cuDNN versions, and check that every benchmark module imports.

### 2. Download (`download.slurm`, gg)

1. Read the kits19 `get_imaging.py` and `requirements.txt` first, so its installs cannot overwrite the pins.
2. Run `python -m starter_code.get_imaging`, which fetches all 300 cases (about 30 GB). Only the 43 in `meta/inference_cases.json` are used.
3. Copy case_00185 to case_00400 as the Makefile does. `preprocess.py` asserts that every case in `meta/inference_cases.json` is present, and case_00400 is listed there.

### 3. Preprocess (`preprocess.slurm`, gg, 2 h limit)

Run `preprocess.py --mode preprocess` as in the reference. It checks the output against `meta/checksum_inference.json` by itself. Newer Python, NumPy or SciPy builds could change the bytes. If the check fails, the failing cases are recorded and the run continues, because a checksum mismatch alone does not make the data wrong.

### 4. GPU smoke (`run.slurm` on gh-dev, about 30 min)

Run two or three cases through the full path: GPU detection, model load, LoadGen, evaluator. The cases are selected by writing a smaller `preprocessed_files.pkl` that links to the real files, so no benchmark code changes.

### 5. Full accuracy run (`run.slurm` on gh, 1 h cap)

1. `run.py --backend=pytorch --scenario=Offline --accuracy` over all 43 cases, with `mlperf.conf` copied to `build/mlperf.conf` as the Makefile does.
2. `run_with_device.py` prints the `pytorch device:` line from the loaded model's parameters without editing `run.py`.
3. `SKIP_VERIFY_ACCURACY=1` is set so `accuracy_kits.py` runs as its own timed step on `mlperf_log_accuracy.json`, which is the same command `run.py` would run.
4. The job saves `nvidia-smi` output (GPU, driver) and the TF32 settings.

### 6. Results and report

`fetch_results.sh` copies the logs, `accuracy.txt`, `summary.csv`, job logs, timings and `pip freeze` to `~/cylon_experiments/deepvela/vista/3d-unet-kits19/`. `mlperf_log_accuracy.json` stays on Vista. The report in `docs/vista-3d-unet-kits19-reproduction.md` covers platform, image and package versions, every deviation and its reason, per-stage wall times, the measured mean, kidney and tumor DICE, the device line, and problems with their fixes.

The reference scores 43 cases including the case_00400 duplicate, while the task record excludes it. The report gives the 43-case scores the evaluator prints and a clearly labeled 42-case mean from `summary.csv` without case_00400.

## Running

```bash
./stage.sh
ssh vista 'cd $SCRATCH/mlperf-3dunet/scripts && ./submit.sh setup'
ssh vista 'cd $SCRATCH/mlperf-3dunet/scripts && ./submit.sh download'
ssh vista 'cd $SCRATCH/mlperf-3dunet/scripts && ./submit.sh preprocess'
ssh vista 'cd $SCRATCH/mlperf-3dunet/scripts && RUN_TAG=smoke SMOKE_CASES="case_00000 case_00003" ./submit.sh run --partition=gh-dev --time=00:30:00'
ssh vista 'cd $SCRATCH/mlperf-3dunet/scripts && RUN_TAG=full ./submit.sh run'
./fetch_results.sh
```

Reach Vista only through the open ControlMaster (`ssh -O check vista`). If it is down, the user runs `ssh -fN vista`.

## Budget and risks

About 2 SU in total: gg jobs at 0.33 SU per node hour and about 1 to 1.5 GPU node hours. Queue wait will take longer than compute. The KiTS19 imaging host may no longer serve the data, and the SSH master lasts 8 hours.
