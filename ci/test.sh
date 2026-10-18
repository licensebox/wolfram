#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ci/env.sh
if [[ -z "${JNA_JAR:-}" ]]; then
 if [[ -f /usr/share/java/jna.jar ]]; then JNA_JAR=/usr/share/java/jna.jar
 else JNA_JAR=../deps/jna-5.18.1.jar; fi
fi
if [[ -z "${GSON_JAR:-}" ]]; then
 if [[ -f /usr/share/java/gson.jar ]]; then GSON_JAR=/usr/share/java/gson.jar
 else GSON_JAR=../deps/gson-2.13.2.jar; fi
fi
export JNA_JAR="$(realpath "$JNA_JAR")" GSON_JAR="$(realpath "$GSON_JAR")"
[[ -f "$JNA_JAR" && -f "$GSON_JAR" ]]
mkdir -p build/classes build/test-classes build/logs
javac -cp "$JNA_JAR:$GSON_JAR" -d build/classes Java/dev/licensebox/*.java
javac -cp "build/classes:$JNA_JAR:$GSON_JAR" -d build/test-classes test/BridgeLifetime.java
java -cp "build/classes:build/test-classes:$JNA_JAR:$GSON_JAR" BridgeLifetime
jar cf build/licensebox-wolfram.jar -C build/classes dev
# Development classpath only; third-party jars are excluded from SDK artifacts.
cp "$JNA_JAR" build/jna.jar
cp "$GSON_JAR" build/gson.jar
wolframscript -code 'Print[$Version];Print[$SystemID]' >build/logs/runtime.log
wolframscript -file test/unicode.wls 2>&1 | tee build/logs/unicode.log
grep -q '^PASS: Wolfram RawJSON' build/logs/unicode.log
wolframscript -file test/lifetime.wls 2>&1 | tee build/logs/lifetime.log
grep -q '^PASS: actual Wolfram 100-client' build/logs/lifetime.log
wolframscript -file test/callbacks.wls 2>&1 | tee build/logs/callbacks.log
grep -q '^PASS: actual Wolfram callback exception' build/logs/callbacks.log
python3 test/activation_callbacks.py 2>&1 | tee build/logs/activation-callbacks.log
mkdir -p build/package/Kernel build/package/build
cp Kernel/Licensebox.wl build/package/Kernel/Licensebox.wl
cp build/licensebox-wolfram.jar build/package/build/licensebox-wolfram.jar
cp LICENSE build/package/LICENSE
# Executable Wolfram code, Java bytecode and LICENSE only; no source/tests/docs.
tar -czf build/licensebox-wolfram-0.1.0.tar.gz -C build/package LICENSE Kernel/Licensebox.wl build/licensebox-wolfram.jar
python3 test/package_consumer.py 2>&1 | tee build/logs/package-consumer.log
