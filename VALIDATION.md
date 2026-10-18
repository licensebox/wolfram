# Validation — 2026-10-18

Java/JNA/Gson native bridge compilation passes with javac; its Java-side 100-client close and throwing-callback test passes. This does not validate Wolfram evaluation. Wolfram runtime/JLink callback behavior, lifetime tests and protocol conformance are UNVALIDATED because wolframscript is unavailable. ci/setup.sh reports that prerequisite explicitly; ci/test.sh and ci/adapter.sh require the real runtime. No Wolfram conformance pass is claimed.

The C core was built as a shared library from the public SDK checkout. Test keys, times, identities and loopback server data are synthetic. Linux x86-64 only; other OS/runtime paths are unvalidated. No remote release or registry publication is performed by these scripts.
