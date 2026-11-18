#!/usr/bin/env bash
set -euo pipefail
STAGE=${1:?usage: submit.sh STAGE [sbatch args]}
shift
ACCOUNT=${ACCOUNT:-TG-NAIRR260130}
cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p jobs
sbatch --account="$ACCOUNT" --parsable --export=ALL "$@" "$STAGE.slurm" | grep -E '^[0-9]+(;.*)?$' | tail -1 | cut -d';' -f1