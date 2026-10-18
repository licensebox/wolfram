#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ci/env.sh
jna="${JNA_JAR:-/usr/share/java/jna.jar}"
gson="${GSON_JAR:-/usr/share/java/gson.jar}"
mkdir -p build/classes
javac -cp "$jna:$gson" -d build/classes Java/dev/licensebox/*.java
javac -cp "build/classes:$jna:$gson" -d build/classes test/BridgeLifetime.java
java -cp "build/classes:$jna:$gson" BridgeLifetime
jar cf build/licensebox-wolfram.jar -C build/classes .
cp "$jna" build/jna.jar
cp "$gson" build/gson.jar
wolframscript -file test/lifetime.wls
tar -czf build/licensebox-wolfram-0.1.0.tar.gz LICENSE Kernel Java ci test build/licensebox-wolfram.jar
