# Local runtime validation — 2026-10-18

Status: **source preview, fully tested locally on Wolfram Engine 15.0.0/Linux**.
Hosted GitHub CI remains **Java bridge only**. No stable SDK release, licensed
hosted-runtime CI pass, or other operating-system/runtime support is claimed.

The actual runtime reports `15.0.0 for Linux x86 (64-bit) (May 31, 2026)` and
`Linux-x86-64`. The bridge was compiled using OpenJDK 21.0.12.1 and tested with
JNA 5.18.1, Gson 2.13.2 and the shared C core commit
`d1e17acc49d17120723aa1f17ae5f9d817d8ceae`. Shared test scripts were run from
protocol commit `bd07daf685fd41eaa0a6f5220ca24103c706a88e`.

| Actual check | Result |
| --- | --- |
| Java bridge compilation, native lifetime and thrown callbacks | PASS |
| Wolfram 100-client creation with actual live Java/native handles and deterministic close | PASS |
| Wolfram callback throws (tagged/untagged), aborts, invalid types, cancellation, reentry and closed-client refusal | PASS |
| Real activation callback failure/cancellation against synthetic server, without saving a lease or allocating a seat | PASS |
| Unicode RawJSON/Java roundtrip and signed non-ASCII request payload | PASS |
| Installed executable-package consumer using actual signatures, trusted keys and native identity helpers | PASS |
| All 69 unchanged shared protocol cases, fresh Wolfram OS process per request | PASS |
| Untrusted CA, wrong CA and hostname mismatch refused; trusted loopback TLS activates | PASS |
| Shell/Python test-entrypoint syntax and explicit executable-package allowlist | PASS |

The shared suite covers activation, renewal, module authorization, requests,
access links, retry-safe usage, offline expiry, clock rollback, long-idle renewal,
terms changes, persisted policy refusals including corrupt state, credential-copy
refusal, seat transfer, reinstall, revocation and logout. Keys, clocks, identities,
loopback hosts and records are synthetic. No private product files, account data,
activation files or production credentials are used or packaged.

Run the same checks on an already activated runtime:

```sh
export LICENSEBOX_LIB_DIR=/path/to/native/lib
export LICENSEBOX_INCLUDE_DIR=/path/to/native/include
export LD_LIBRARY_PATH="$LICENSEBOX_LIB_DIR:${LD_LIBRARY_PATH:-}"
export JNA_JAR=/path/to/jna.jar
export GSON_JAR=/path/to/gson.jar
bash ci/full-test.sh
```

Logs are retained under `build/logs/`: `runtime.log`, `build-test.log`,
`lifetime.log`, `callbacks.log`, `activation-callbacks.log`, `unicode.log`,
`package-consumer.log`, `conformance.log`, and `tls.log`. Distinct earlier stdin,
callback-conversion and Unicode failure logs are retained locally for review;
they are excluded from downloadable artifacts. The final conformance log ends
with `PASS: 69 shared conformance checks` and the TLS log records trusted success
and all three refusal cases.

The package consumer audits the archive's exact allowlist:
`LICENSE`, `Kernel/Licensebox.wl`, `build/licensebox-wolfram.jar`. It extracts to a
new temporary directory and loads the installed Wolfram code/JAR. Third-party
JNA/Gson JARs are separate dependencies, not bundled. Tests fail unless the actual
Wolfram assertions print their completion marker; an unevaluated expression or a
kernel message with exit status zero cannot silently count as a pass.

The runtime fixes contain callback failures at the Wolfram/JLink boundary,
prevent client reentry, correctly retain Java Boolean callback values, handle
WolframScript stdin, and preserve Unicode across Wolfram JSON byte strings and
Java Unicode strings. Native identity and cryptography remain in the maintained
C core. No licensing rules, shared fixtures or assertions were weakened.

Recommendation: keep the public **source preview** label until a repeatable,
licensed runtime CI job runs this complete suite for dependency and source
updates. The official Wolfram CI template requires an on-demand entitlement
secret or a licensed self-hosted/MathLM configuration; the existing public job
proves only the bridge profile. No licensing credentials or activation changes
were made during this validation, and no remote release/tag was published.

## Optional heartbeat candidate — 2026-10-18

The separate `feature/heartbeat` branch additionally passes all **36 shared
heartbeat cases** through actual Wolfram Engine 15/JLink/native execution. The
complete 69-case suite was rerun successfully against the same corrected native
C candidate `c530e36b4656d9a66cb1b01c977a84df1f458fc3`. The shared regression
comes from protocol commit `e1f44de9fac558889e30e02bc033485917c7d0ce`;
`conformance/heartbeat.py` has SHA256
`d654e6be89d18f8b8b41f54b4472d134c365af77f723ad7de669ab447ee7f793`.

The installed executable-package consumer also invokes the new public
`LicenseboxHeartbeat` method and checks missing-lease and closed-client refusal.
The existing runtime, package, callback, Unicode and TLS checks passed during
candidate validation. Logs are retained locally as `build/logs/heartbeat.log`
and `build/logs/conformance-c530e36.log`, with earlier 34-case evidence retained
separately; no raw logs, tests or documentation are included in executable
packages.

The primitive preserves the optional verified signed policy and returns the
complete lease plus the `online` result. The shared cases exercise forced contact
on repeated calls and after cached Require, offline deadlines, removed modules,
persisted refusals, terms, revocation, missing identity without creating a new
key, and refusal of an HTTP redirect without forwarding signed credentials.
No automatic timer, runtime thread, sign-in or monitor starts. Applications own
scheduling and safe cancellation on their runtime thread.

This local evidence does not promote the source preview or establish licensed
hosted CI. The existing GitHub profile remains bridge only; a stable release
still requires repeatable licensed runtime CI.
