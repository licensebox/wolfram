# Licensebox for Wolfram Language

**Source preview — Wolfram runtime is unvalidated.** No versioned SDK release
is published yet. Linux CI compiles and tests only the native Java bridge,
including callback/lifetime behavior. Full Wolfram evaluation and shared
licensing conformance still require a licensed runtime.

Application licensing SDK by [Vijai Kumar](https://meshing.engineer). MIT, 2026.
Uses the maintained Licensebox C core **>=0.3.0** for HTTPS, pure Ed25519 verification, native machine identity, persistence, activation, offline access, policy refusals and bounded usage collection. No licensing server or administration credentials are included.

## Build and install

A licensed Wolfram runtime with J/Link, Java >=17, JNA >=5.18 and Gson. The included Java native bridge is built by javac; the Wolfram API and callbacks require Wolfram itself.
Build/install the public [C core](https://github.com/licensebox/c) as a shared library first. Export `LICENSEBOX_LIB_DIR` (directory containing liblicensebox.so), `LICENSEBOX_INCLUDE_DIR` (public headers), and `LD_LIBRARY_PATH`. `LICENSEBOX_LIBRARY` may identify the library path; scripts derive its containing directory when supplied. Linked bindings resolve liblicensebox.so through the native dynamic loader, so use a compatible library basename. CI uses only a disposable Ubuntu runner; ci/setup.sh is not a workstation installer.

```sh
bash ci/setup.sh
bash ci/test.sh
python3 ../protocol/conformance/run.py --adapter bash ci/adapter.sh
```

`ci/test.sh` builds real language code and runs repeated allocation/close checks, then creates or installs the language package. The adapter is test-only and supplies synthetic clock/binding callbacks. It is not a production command-line bypass.

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

`LicenseboxLease`, `LicenseboxRequire`, `LicenseboxStatus`, `LicenseboxSignIn`, `LicenseboxLogout`, `LicenseboxModules`, `LicenseboxRequests`, `LicenseboxRequestAccess`, `LicenseboxAccessLink`, `LicenseboxRecord`, `LicenseboxDeriveBinding`, `LicenseboxNativeBinding`, `LicenseboxVerifyLease`. Failures return Failure[code, association].

Constructor options include version, server, directory and optional ca_bundle. TLS certificate and hostname verification stay enabled. The sign-in callback receives the verification URL and user code. Clock, machine binding and cancellation are **typed trusted application callbacks**, not JSON option overrides or end-user settings. Callback state stays alive for the native client's lifetime. Exceptions are contained at the FFI boundary and reported after native execution. Callbacks must not reenter the client; the wrapper rejects reentry. Calls and error inspection are serialized; do not move language runtime handles between unsupported threads.

Access links, leases and private device codes are credentials; avoid logs. Keep public verification keys in the application and installation private keys local. Collect fixed-command usage only; never filenames, arguments or file data.

## Validation

The Wolfram runtime is unavailable in the development environment. The Java bridge compiles, but Wolfram evaluation, J/Link callbacks, lifetime and protocol conformance are **unvalidated**; run the commands below on a licensed runner before release.

The exact public protocol pin is protocol-lock.json; native-version.txt records the minimum C release. Follow [the shared contract](https://github.com/licensebox/protocol) before changing licensing behavior. Administration remains in the Go CLI.

The scheduled update workflow tests only the bridge before proposing native
dependency/contract updates. Its PRs explicitly retain the runtime-unvalidated
status. Run `ci/test.sh` and the full shared suite with a licensed Wolfram runtime
before promoting this preview to a released SDK.
