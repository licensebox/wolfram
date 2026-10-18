#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ci/env.sh
exec wolframscript -file test/adapter.wls
