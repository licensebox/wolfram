#!/usr/bin/env python3
"""Install the executable SDK artifact and test with the actual Wolfram runtime."""
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile

root = Path(__file__).resolve().parent.parent
archive = root / "build/licensebox-wolfram-0.1.0.tar.gz"
expected = {"LICENSE", "Kernel/Licensebox.wl", "build/licensebox-wolfram.jar"}
with tempfile.TemporaryDirectory(prefix="licensebox-wolfram-consumer-") as temporary:
    with tarfile.open(archive) as package:
        assert set(package.getnames()) == expected, "unexpected executable package contents"
        assert all(member.isfile() for member in package.getmembers()), "package contains links/directories"
        package.extractall(temporary, filter="data")
    environment = dict(os.environ, LICENSEBOX_PACKAGE_DIR=temporary,
                       LICENSEBOX_VECTORS=str(Path(os.environ.get("LICENSEBOX_PROTOCOL_DIR", str(root.parent / "protocol"))) / "vectors.json"))
    environment["JNA_JAR"] = str(Path(environment["JNA_JAR"]).resolve())
    environment["GSON_JAR"] = str(Path(environment["GSON_JAR"]).resolve())
    result = subprocess.run(["wolframscript", "-file", str(root / "test/consumer.wls")],
                            text=True, capture_output=True, env=environment, timeout=90)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="")
    assert result.returncode == 0, "installed Wolfram consumer failed"
    assert "PASS: actual Wolfram installed-package consumer" in result.stdout, "consumer did not complete its assertions"
