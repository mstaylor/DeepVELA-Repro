#!/bin/bash
#SBATCH --job-name=unet-download
#SBATCH --partition=gg
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=06:00:00
#SBATCH --output=jobs/%x-%j.out
set -euo pipefail
source "$SLURM_SUBMIT_DIR/env.sh"
CTR_FLAGS=()
GET_IMAGING_ATTEMPTS=${GET_IMAGING_ATTEMPTS:-3}
load_apptainer

numpy_version=$(ctr "$VENV/bin/python" -c "import numpy; print(numpy.__version__)")
ctr env -u PIP_CONSTRAINT "$VENV/bin/python" -m pip install -r "$KITS/requirements.txt" \
  -c "$SCRIPTS/pins.txt" "numpy==$numpy_version"
ctr "$VENV/bin/python" -m pip freeze > "$ENV_DIR/pip_freeze_after_kits19.txt"

t0=$(date +%s.%N)
for attempt in $(seq 1 "$GET_IMAGING_ATTEMPTS"); do
  echo "get_imaging attempt $attempt"
  ctr_at "$KITS" "$VENV/bin/python" -m starter_code.get_imaging 2>&1 | grep -v '|' || true
  missing=$(for i in $(seq 0 299); do f=$(printf '%s/case_%05d/imaging.nii.gz' "$RAW" "$i"); [ -s "$f" ] || echo "$i"; done | wc -l)
  echo "imaging files missing after attempt $attempt: $missing"
  [ "$missing" -eq 0 ] && break
done
t1=$(date +%s.%N)
record_stage download "$t0" "$t1"

if [ -s "$RAW/case_00185/imaging.nii.gz" ]; then
  cp -Rf "$RAW/case_00185" "$RAW/case_00400"
fi

needed_missing=$(ctr "$VENV/bin/python" -c "
import json, os, sys
cases = json.load(open(os.path.join(sys.argv[1], 'meta', 'inference_cases.json')))
print(' '.join(c for c in cases if not all(os.path.getsize(os.path.join(sys.argv[2], c, f)) > 0 if os.path.exists(os.path.join(sys.argv[2], c, f)) else False for f in ('imaging.nii.gz', 'segmentation.nii.gz'))))
" "$BENCH" "$RAW")
{
  echo "all_cases_missing=$missing"
  echo "inference_cases_missing=${needed_missing:-none}"
  du -sh "$RAW"
} | tee "$ENV_DIR/download_status.txt"
[ -z "$needed_missing" ]
