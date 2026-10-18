#!/usr/bin/env bash
# Requires an already activated/licensed Wolfram runtime. No activation changes.
set -euo pipefail
cd "$(dirname "$0")/.."
source ci/env.sh
mkdir -p build/logs
bash ci/test.sh 2>&1 | tee build/logs/build-test.log
protocol="${LICENSEBOX_PROTOCOL_DIR:-../protocol}"
[[ -f "$protocol/conformance/run.py" && -f "$protocol/conformance/tls_transport.py" && -f "$protocol/conformance/heartbeat.py" ]]
python3 "$protocol/conformance/run.py" --adapter bash ci/adapter.sh 2>&1 | tee build/logs/conformance.log
python3 "$protocol/conformance/tls_transport.py" --adapter bash ci/adapter.sh 2>&1 | tee build/logs/tls.log
python3 "$protocol/conformance/heartbeat.py" --adapter bash ci/adapter.sh 2>&1 | tee build/logs/heartbeat.log
