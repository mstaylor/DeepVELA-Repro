#!/usr/bin/env bash
set -euo pipefail
HOST=${VISTA_HOST:-vista}
DEST=${DEST:-/home/parallels/cylon_experiments/deepvela/vista/3d-unet-kits19}
ssh -O check "$HOST"
REMOTE_ROOT=${MLPERF_ROOT:-$(ssh "$HOST" 'echo $SCRATCH')/mlperf-3dunet}
mkdir -p "$DEST"
rsync -as --exclude mlperf_log_accuracy.json --exclude preprocessed_subset --exclude 'case_*' \
  "$HOST:$REMOTE_ROOT/runs" "$DEST/"
rsync -as "$HOST:$REMOTE_ROOT/env" "$HOST:$REMOTE_ROOT/timings.tsv" "$DEST/"
rsync -as "$HOST:$REMOTE_ROOT/scripts/jobs" "$DEST/"
echo "fetched to $DEST"
