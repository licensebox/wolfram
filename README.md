# Licensebox for Wolfram Language

**Source preview — Wolfram 15 on Linux is tested locally.** No versioned SDK
release is published. The complete runtime suite passes on the activated local
Wolfram Engine 15.0.0 installation; hosted GitHub CI currently validates only the
Java native bridge. A repeatable licensed runtime job is required before stable
release promotion. See [VALIDATION.md](VALIDATION.md) for exact evidence.

Application licensing SDK by [Vijai Kumar](https://meshing.engineer). MIT, 2026.
Uses the maintained Licensebox C core **>=0.5.0** for HTTPS, hybrid Ed25519 + ML-DSA-65 verification, native machine identity, persistence, activation, offline access, policy refusals and bounded usage collection. No licensing server or administration credentials are included.

## Build and install

An activated Wolfram runtime with J/Link, Java 21, JNA and Gson. The tested versions are Wolfram Engine 15.0.0, OpenJDK 21, JNA 5.18.1 and Gson 2.13.2. Other runtime versions are unvalidated.
Build/install the public [C core](https://github.com/licensebox/c) as a shared library first. Export `LICENSEBOX_LIB_DIR` (directory containing liblicensebox.so), `LICENSEBOX_INCLUDE_DIR` (public headers), and `LD_LIBRARY_PATH`. `LICENSEBOX_LIBRARY` may identify the library path; scripts derive its containing directory when supplied. Linked bindings resolve liblicensebox.so through the native dynamic loader, so use a compatible library basename. CI uses only a disposable Ubuntu runner; ci/setup.sh is not a workstation installer.

```sh
# ci/setup.sh is optional disposable-runner dependency setup, not host activation.
export JNA_JAR=/path/to/jna.jar
export GSON_JAR=/path/to/gson.jar
bash ci/full-test.sh
```

`ci/test.sh` builds real language code, checks callback/lifetime behavior, and tests a consumer installed from the executable SDK package. `ci/full-test.sh` additionally runs the unchanged 69-case shared suite and real loopback TLS tests. Neither script activates Wolfram or changes accounts/licenses. Set `LICENSEBOX_PROTOCOL_DIR` if the shared protocol checkout is not adjacent. Artifacts contain only executable `Kernel/Licensebox.wl`, `build/licensebox-wolfram.jar`, and `LICENSE`; JNA/Gson are separate dependencies selected by `JNA_JAR` and `GSON_JAR`. The adapter is test-only and supplies synthetic clock/binding callbacks. It is not a production command-line bypass.

## Use

```
Get["Kernel/Licensebox.wl"];
c = LicenseboxOpen[<|"product" -> "your-product", "keys" -> <|"signing-key-id" -> "PUBLIC_BASE64URL_KEY"|>, "version" -> "1.0"|>,
  <|"on_sign_in" -> Function[{url, code}, Print[url, " ", code]]|>];
result = LicenseboxRequire[c, "core"]; (* Check before opening user files. *)
LicenseboxClose[c];
```

Explicitly sign in using the sign-in method when the user chooses to activate. Retain one client per process and close it deterministically. A protected call renews silently with a short bound; verified unexpired offline access is allowed only for eligible transport/server failures. Expiry returns offline and does not automatically activate. Explicit policy refusals persist and block cached access. Native identity is never replaced with random, hostname or network identifiers.

## API

`LicenseboxLease`, `LicenseboxHeartbeat`, `LicenseboxRequire`, `LicenseboxStatus`, `LicenseboxSignIn`, `LicenseboxLogout`, `LicenseboxModules`, `LicenseboxRequests`, `LicenseboxRequestAccess`, `LicenseboxAccessLink`, `LicenseboxRecord`, `LicenseboxDeriveBinding`, `LicenseboxNativeBinding`, `LicenseboxVerifyLease`. Failures return Failure[code, association].

Constructor options include version, server, directory and optional ca_bundle. TLS certificate and hostname verification stay enabled. The sign-in callback receives the verification URL and user code. Clock, machine binding and cancellation are **typed trusted application callbacks**, not JSON option overrides or end-user settings. Callback state stays alive for the native client's lifetime. Exceptions are contained at the FFI boundary and reported after native execution. Callbacks must not reenter the client; the wrapper rejects reentry. Calls and error inspection are serialized; do not move language runtime handles between unsupported threads.

Access links, leases and private device codes are credentials; avoid logs. Keep public verification keys in the application and installation private keys local. Collect fixed-command usage only; never filenames, arguments or file data.

## Validation

Actual Wolfram Engine 15.0.0 on Linux x86-64 passes all 69 shared checks, TLS trust/hostname tests, the installed-package consumer, 100-client lifecycle checks, Unicode JSON roundtrips and real sign-in/cancellation callbacks. Each shared adapter request starts a fresh Wolfram process and executes the actual Wolfram API/JLink/native stack. The heartbeat feature candidate also passes all 37 shared heartbeat checks, including missing-identity refusal and HTTP redirect refusal. All fixtures and servers are synthetic; no production endpoint or private product data is used.

The exact public protocol pin is protocol-lock.json; native-version.txt records the minimum C release. Follow [the shared contract](https://github.com/licensebox/protocol) before changing licensing behavior. Administration remains in the Go CLI.

The scheduled update workflow tests only the bridge before proposing native
dependency/contract updates. Its PRs retain the bridge-only validation profile; they do not prove a new dependency passes Wolfram runtime checks. Run `ci/full-test.sh` on an already activated runner before promoting any preview/dependency update to a released SDK.

The [official Wolfram CI template](https://github.com/WolframResearch/WL-FunctionCompile-CI-Template#2-create-an-on-demand-license-entitlement) uses an on-demand licensing entitlement stored as a repository secret, or a licensed self-hosted/MathLM setup. A public repository alone does not provide automatic Wolfram activation. This project has not configured a licensed hosted runtime job and does not copy local activation files or credentials into the repository.

## Optional explicit heartbeat

Use `LicenseboxHeartbeat[client, "core"]` for an explicit bounded renewal/checkpoint. The mandatory module must be nonempty. The result contains `lease` (the complete verified lease, preserving optional signed `heartbeat.interval_seconds`/`grace_seconds`) and `online` (whether this check renewed successfully online). Every invocation attempts renewal, including after a cached `Require`; it never starts interactive activation or transfers a seat. Eligible outages may return `online=false` only while the last verified signed lease remains unexpired. Refusals, missing modules and expired offline access remain errors.

Default Client/Lease/Require behavior is unchanged. No timer, task, thread or background heartbeat starts automatically. The application owns event-loop scheduling/checkpoints on the language runtime thread, and safe cancellation of protected work on refusal or the last verified expiry deadline. A failed check cannot extend that deadline. This is especially important for MATLAB, Wolfram/JLink and other runtimes whose callbacks must stay on their owning thread. The matching native C heartbeat API/contract is required.

Validate the feature against the candidate native core with `python3 ../protocol/conformance/heartbeat.py --adapter bash ci/adapter.sh` in addition to the existing full shared suite.
