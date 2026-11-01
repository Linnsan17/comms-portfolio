"""Preview the site locally, with caching turned off.

usage: python3 tools/serve.py [port] [folder]   (defaults: 8796, this repo)

python3 -m http.server lets the browser reuse a cached stylesheet or
script for a while after it changes, so a reload can mix new HTML with old
CSS and look broken. This server tells the browser never to cache.
"""
import functools
import http.server
import pathlib
import sys


class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8796
root = sys.argv[2] if len(sys.argv) > 2 else str(pathlib.Path(__file__).resolve().parent.parent)
handler = functools.partial(NoCache, directory=root)
print(f"Serving {root} at http://localhost:{port}")
http.server.ThreadingHTTPServer(("127.0.0.1", port), handler).serve_forever()
