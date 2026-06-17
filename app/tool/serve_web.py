"""Static server for the Flutter web build with the headers Flutter's wasm
renderer needs (cross-origin isolation) + correct wasm/js MIME types.
Usage: python app/tool/serve_web.py [port]
"""
import http.server
import os
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        # Intentionally NOT cross-origin isolated: keeps Flutter on the
        # main-thread CanvasKit renderer (worker-based skwasm is hard to capture).
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


Handler.extensions_map = {
    **http.server.SimpleHTTPRequestHandler.extensions_map,
    ".wasm": "application/wasm",
    ".js": "text/javascript",
    ".mjs": "text/javascript",
}


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True


print(f"serving {WEB_DIR} on http://localhost:{PORT}")
with Server(("", PORT), Handler) as httpd:
    httpd.serve_forever()
