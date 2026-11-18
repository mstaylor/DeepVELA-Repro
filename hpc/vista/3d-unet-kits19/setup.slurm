#!/bin/bash
#SBATCH --job-name=unet-setup
#SBATCH --partition=gg
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=02:00:00
#SBATCH --output=jobs/%x-%j.out
set -euo pipefail
source "$SLURM_SUBMIT_DIR/env.sh"
CTR_FLAGS=()
mkdir -p "$ROOT"/{sif,model,tmp,pip_cache} "$ENV_DIR" "$APPTAINER_CACHEDIR"
t0=$(date +%s.%N)

if [ ! -d "$INFERENCE/.git" ]; then
  git clone --filter=blob:none --no-checkout "$INFERENCE_URL" "$INFERENCE"
  git -C "$INFERENCE" sparse-checkout set --no-cone /loadgen/ /vision/medical_imaging/3d-unet-kits19/ /mlperf.conf
  git -C "$INFERENCE" checkout --detach "$INFERENCE_COMMIT"
fi
test "$(git -C "$INFERENCE" rev-parse HEAD)" = "$INFERENCE_COMMIT"
git -C "$INFERENCE" rev-parse HEAD > "$ENV_DIR/inference_commit.txt"

if [ ! -d "$KITS/.git" ]; then
  git clone "$KITS19_URL" "$KITS"
fi
git -C "$KITS" rev-parse HEAD > "$ENV_DIR/kits19_commit.txt"

if [ ! -s "$MODEL" ]; then
  curl -fL --retry 5 -o "$MODEL.part" "$MODEL_URL"
  mv "$MODEL.part" "$MODEL"
fi
curl -fsSL --retry 5 "$MODEL_RECORD_API" -o "$ENV_DIR/zenodo_record_5597155.json"
expected_md5=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print([f['checksum'].split(':')[-1] for f in d['files'] if f['key']=='3dunet_kits19_pytorch.ptc'][0])" "$ENV_DIR/zenodo_record_5597155.json")
actual_md5=$(md5sum "$MODEL" | cut -d' ' -f1)
echo "model md5 expected=$expected_md5 actual=$actual_md5" | tee "$ENV_DIR/model_md5.txt"
test "$expected_md5" = "$actual_md5"
t1=$(date +%s.%N)
record_stage model_and_repos "$t0" "$t1"

load_apptainer
if [ ! -s "$SIF" ]; then
  apptainer pull "$SIF" "docker://$DOCKER_IMAGE"
fi
apptainer inspect "$SIF" > "$ENV_DIR/sif_inspect.txt" || true
t2=$(date +%s.%N)
record_stage image_pull "$t1" "$t2"

ctr cat /etc/pip/constraint.txt > "$ENV_DIR/ngc_pip_constraint.txt" 2>/dev/null || true
if [ ! -x "$VENV/bin/python" ]; then
  ctr python -m venv --system-site-packages "$VENV"
fi
numpy_version=$(ctr "$VENV/bin/python" -c "import numpy; print(numpy.__version__)")
ctr env -u PIP_CONSTRAINT "$VENV/bin/pip" install "numpy==$numpy_version" -r "$SCRIPTS/pins.txt"
ctr env -u PIP_CONSTRAINT "$VENV/bin/pip" install "$INFERENCE/loadgen"
ctr "$VENV/bin/pip" freeze > "$ENV_DIR/pip_freeze.txt"
ctr cat /etc/os-release > "$ENV_DIR/container_os_release.txt"
ctr_at "$BENCH" "$VENV/bin/python" -c "
import platform, sys, numpy, scipy, pandas, nibabel, torch, mlperf_loadgen
from scipy import signal
from scipy.ndimage.interpolation import zoom
import preprocess, accuracy_kits, inference_utils, pytorch_SUT, kits_QSL
signal.gaussian(8, 1.0)
print('machine', platform.machine(), 'python', sys.version.split()[0])
print('torch', torch.__version__, 'cuda', torch.version.cuda, 'cudnn', torch.backends.cudnn.version())
print('numpy', numpy.__version__, 'scipy', scipy.__version__, 'pandas', pandas.__version__, 'nibabel', nibabel.__version__)
" | tee "$ENV_DIR/versions.txt"
t3=$(date +%s.%N)
record_stage venv_and_loadgen "$t2" "$t3"
echo "setup done"