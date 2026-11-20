#!/bin/bash
#SBATCH --job-name=unet-run
#SBATCH --partition=gh
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=01:00:00
#SBATCH --output=jobs/%x-%j.out
set -euo pipefail
source "$SLURM_SUBMIT_DIR/env.sh"
CTR_FLAGS=(--nv)
RUN_TAG=${RUN_TAG:?RUN_TAG must be set}
SMOKE_CASES=${SMOKE_CASES:-}
RUN_DIR=$ROOT/runs/$RUN_TAG
LOG_DIR=$RUN_DIR/logs
POST_DIR=$RUN_DIR/postprocessed_data
load_apptainer
mkdir -p "$LOG_DIR" "$POST_DIR"

if [ -n "$SMOKE_CASES" ]; then
  DATA_DIR=$RUN_DIR/preprocessed_subset
  read -r -a smoke_case_list <<< "$SMOKE_CASES"
  ctr "$VENV/bin/python" "$SCRIPTS/subset_preprocessed.py" --source "$PRE" --target "$DATA_DIR" --cases "${smoke_case_list[@]}"
else
  DATA_DIR=$PRE
fi

mkdir -p "$BENCH/build"
if [ ! -e "$BENCH/build/mlperf.conf" ]; then
  cp "$INFERENCE/mlperf.conf" "$BENCH/build/mlperf.conf"
fi

{
  echo "job_id=${SLURM_JOB_ID:-} host=$(hostname) partition=${SLURM_JOB_PARTITION:-} data_dir=$DATA_DIR"
  nvidia-smi
  nvidia-smi --query-gpu=name,driver_version,memory.total,power.limit --format=csv
  lscpu | head -20
} > "$RUN_DIR/platform.txt" 2>&1
ctr "$VENV/bin/python" -c "
import torch, platform
print('machine', platform.machine())
print('torch', torch.__version__, 'cuda', torch.version.cuda, 'cudnn', torch.backends.cudnn.version())
print('cuda_available', torch.cuda.is_available(), 'device_name', torch.cuda.get_device_name(0) if torch.cuda.is_available() else None)
print('cudnn.allow_tf32', torch.backends.cudnn.allow_tf32, 'matmul.allow_tf32', torch.backends.cuda.matmul.allow_tf32)
" >> "$RUN_DIR/platform.txt" 2>&1
ctr "$VENV/bin/python" -m pip freeze > "$RUN_DIR/pip_freeze.txt"

t0=$(date +%s.%N)
ctr_at "$BENCH" env SKIP_VERIFY_ACCURACY=1 LOG_PATH="$LOG_DIR" "$VENV/bin/python" -u "$SCRIPTS/run_with_device.py" \
  --backend=pytorch --scenario=Offline --accuracy --model="$MODEL" \
  --preprocessed_data_dir="$DATA_DIR" --mlperf_conf=build/mlperf.conf 2>&1 | tee "$RUN_DIR/run.log"
t1=$(date +%s.%N)
record_stage "model_run:$RUN_TAG" "$t0" "$t1"

ctr_at "$BENCH" "$VENV/bin/python" -u accuracy_kits.py --preprocessed_data_dir="$DATA_DIR" \
  --postprocessed_data_dir="$POST_DIR" --log_file="$LOG_DIR/mlperf_log_accuracy.json" 2>&1 | tee "$RUN_DIR/accuracy.txt"
t2=$(date +%s.%N)
record_stage "evaluation:$RUN_TAG" "$t1" "$t2"
grep -h "$RUN_TAG" "$TIMINGS" > "$RUN_DIR/timings.tsv"
echo "run done"