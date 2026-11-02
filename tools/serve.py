"""Preview the site locally.

usage: python3 tools/serve.py [port] [folder]   (defaults: 8796, this repo)

python3 -m http.server lets the browser reuse a cached stylesheet or
script for a while after it changes, so a reload can mix new HTML with old
CSS and look broken. This server tells the browser never to cache pages,
styles and scripts. Videos, images and fonts may be cached, but are checked
against the file each time, so a changed one still shows.

It also answers byte-range requests (206 Partial Content), as GitHub Pages
does. Browsers ask for videos in pieces; without ranges a video can't be
skipped through, and Safari loads and loops it badly, so it stutters.
"""
import functools
import http.server
import os
import pathlib
import re
import sys

MEDIA = (".mp4", ".webm", ".mov", ".jpg", ".jpeg", ".png", ".webp", ".gif", ".svg", ".otf", ".woff", ".woff2", ".pdf")


class Part:
    """The file from where the range starts, cut off where it ends"""

    def __init__(self, file, length):
        self.file, self.left = file, length

    def read(self, size=-1):
        if self.left <= 0:
            return b""
        data = self.file.read(self.left if size < 0 else min(size, self.left))
        self.left -= len(data)
        return data

    def close(self):
        self.file.close()


class Preview(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        media = self.path.split("?")[0].lower().endswith(MEDIA)
        self.send_header("Cache-Control", "no-cache" if media else "no-store")
        self.send_header("Accept-Ranges", "bytes")
        super().end_headers()

    def send_head(self):
        match = re.fullmatch(r"bytes=(\d*)-(\d*)", self.headers.get("Range", "").strip())
        path = self.translate_path(self.path)
        if not match or not os.path.isfile(path):
            return super().send_head()
        size = os.path.getsize(path)
        first, last = match.groups()
        if first:
            start, end = int(first), int(last) if last else size - 1
        else:  # the last N bytes
            start, end = max(size - int(last or 0), 0), size - 1
        end = min(end, size - 1)
        if start > end:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.end_headers()
            return None
        file = open(path, "rb")
        file.seek(start)
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(end - start + 1))
        self.send_header("Last-Modified", self.date_time_string(int(os.path.getmtime(path))))
        self.end_headers()
        return Part(file, end - start + 1)

    def log_message(self, format, *args):
        pass  # a video in pieces is a lot of lines


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8796
root = sys.argv[2] if len(sys.argv) > 2 else str(pathlib.Path(__file__).resolve().parent.parent)
handler = functools.partial(Preview, directory=root)
print(f"Serving {root} at http://localhost:{port}", flush=True)
http.server.ThreadingHTTPServer(("127.0.0.1", port), handler).serve_forever()
