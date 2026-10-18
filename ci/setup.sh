#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y default-jdk libjna-java libgoogle-gson-java
# The licensed Wolfram runtime must already be installed on this runner.
command -v wolframscript >/dev/null || { echo 'wolframscript + J/Link required; install and activate a licensed Wolfram runtime.' >&2; exit 1; }
