ROOT=${MLPERF_ROOT:-$SCRATCH/mlperf-3dunet}
SCRIPTS=$ROOT/scripts
INFERENCE_URL=https://github.com/mlcommons/inference.git
INFERENCE_COMMIT=3fbc329939999c13d0a7b5e67fb2092287e06047
KITS19_URL=https://github.com/neheller/kits19
DOCKER_IMAGE=${DOCKER_IMAGE:-nvcr.io/nvidia/pytorch:24.04-py3}
SIF=$ROOT/sif/$(basename "${DOCKER_IMAGE//:/_}").sif
VENV=$ROOT/venv
INFERENCE=$ROOT/inference
BENCH=$INFERENCE/vision/medical_imaging/3d-unet-kits19
MODEL_URL="https://zenodo.org/record/5597155/files/3dunet_kits19_pytorch.ptc?download=1"
MODEL_RECORD_API=https://zenodo.org/api/records/5597155
MODEL=$ROOT/model/3dunet_kits19_pytorch.ptc
KITS=$ROOT/kits19
RAW=$KITS/data
PRE=$ROOT/preprocessed_data
ENV_DIR=$ROOT/env
TIMINGS=$ROOT/timings.tsv

export XALT_EXECUTABLE_TRACKING=no
export APPTAINER_CACHEDIR=${APPTAINER_CACHEDIR:-$SCRATCH/apptainer_cache}
export APPTAINER_TMPDIR=$ROOT/tmp
export APPTAINERENV_PYTHONNOUSERSITE=1
export APPTAINERENV_PIP_CACHE_DIR=$ROOT/pip_cache
export APPTAINERENV_PREPEND_PATH=$VENV/bin

load_apptainer() {
  set +u
  module load tacc-apptainer
  set -u
}

ctr() {
  apptainer exec --cleanenv "${CTR_FLAGS[@]}" --bind "$ROOT" "$SIF" "$@"
}

ctr_at() {
  local dir=$1
  shift
  apptainer exec --cleanenv "${CTR_FLAGS[@]}" --pwd "$dir" --bind "$ROOT" "$SIF" "$@"
}

record_stage() {
  local stage=$1 start=$2 end=$3
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${SLURM_JOB_ID:-none}" "$stage" "$start" "$end" \
    "$(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.1f", b - a }')" "$(hostname)" >> "$TIMINGS"
}