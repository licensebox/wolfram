#!/usr/bin/env python3
"""Actual Wolfram callbacks against the unchanged public synthetic server."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
from http.server import ThreadingHTTPServer

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(os.environ.get("LICENSEBOX_PROTOCOL_DIR", str(root.parent / "protocol"))) / "conformance"))
from run import Handler, State

server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
server.state = State()
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix="licensebox-wolfram-callback-") as directory:
        environment = dict(os.environ, LICENSEBOX_CALLBACK_SERVER=f"http://127.0.0.1:{server.server_port}",
                           LICENSEBOX_CALLBACK_DIRECTORY=directory)
        result = subprocess.run(["wolframscript", "-file", str(root / "test/activation_callbacks.wls")],
                                text=True, capture_output=True, env=environment, timeout=90)
        print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="")
        assert result.returncode == 0, "Wolfram activation callback test failed"
        assert "PASS: actual Wolfram sign-in callback" in result.stdout, "callback assertions did not finish"
        assert server.state.device_count == 2, "callback tests did not reach real device flow"
        assert not server.state.seats, "cancelled callbacks must not allocate seats"
finally:
    server.shutdown()
    server.server_close()
