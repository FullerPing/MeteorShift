"""One-shot receiver: Studio POSTs a serialized ScreenGui (binary rbxm) and this writes it into assets/native-ui.

  python tools/receive_rbxm.py            # listens on 127.0.0.1:8125, exits after one file

Studio side (execute_luau in Edit mode):
  local buf = game:GetService("SerializationService"):SerializeInstancesAsync({ game.StarterGui.RefineryMenu })
  HttpService:PostAsync("http://127.0.0.1:8125/RefineryMenu.rbxm", buffer.tostring(buf), Enum.HttpContentType.TextPlain)
"""
import os, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'native-ui'))


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        name = os.path.basename(self.path.lstrip('/'))
        if not name.endswith('.rbxm'):
            self.send_response(400); self.end_headers(); return
        data = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        with open(os.path.join(OUT, name), 'wb') as f:
            f.write(data)
        print('wrote', name, len(data), 'bytes', flush=True)
        self.send_response(200); self.end_headers(); self.wfile.write(b'ok')
        self.server.done = True

    def log_message(self, *args):
        pass


server = HTTPServer(('127.0.0.1', 8125), Handler)
server.done = False
while not server.done:
    server.handle_request()
