#!/usr/bin/env bash
set -euo pipefail
HOST=${VISTA_HOST:-vista}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ssh -O check "$HOST"
REMOTE_ROOT=${MLPERF_ROOT:-$(ssh "$HOST" 'echo $SCRATCH')/mlperf-3dunet}
ssh "$HOST" "mkdir -p '$REMOTE_ROOT/scripts/jobs'"
rsync -as --exclude jobs "$HERE/" "$HOST:$REMOTE_ROOT/scripts/"
echo "staged to $HOST:$REMOTE_ROOT/scripts"