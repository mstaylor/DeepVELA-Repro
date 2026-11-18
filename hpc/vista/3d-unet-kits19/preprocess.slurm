#!/bin/bash
#SBATCH --job-name=unet-preprocess
#SBATCH --partition=gg
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=02:00:00
#SBATCH --output=jobs/%x-%j.out
set -euo pipefail
source "$SLURM_SUBMIT_DIR/env.sh"
CTR_FLAGS=()
load_apptainer
mkdir -p "$PRE"

t0=$(date +%s.%N)
set +e
ctr_at "$BENCH" "$VENV/bin/python" -u preprocess.py --raw_data_dir "$RAW" --results_dir "$PRE" --mode preprocess \
  2>&1 | tee "$ENV_DIR/preprocess.log"
rc=${PIPESTATUS[0]}
set -e
t1=$(date +%s.%N)
record_stage preprocess_and_verify "$t0" "$t1"
echo "preprocess_exit=$rc" | tee "$ENV_DIR/preprocess_status.txt"
ls "$PRE" | grep -c '^case_.*\.pkl$' | sed 's/^/preprocessed_case_pkls=/' | tee -a "$ENV_DIR/preprocess_status.txt"
exit "$rc"