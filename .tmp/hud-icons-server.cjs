const http = require('node:http');
const fs = require('node:fs');
const icon = fs.readFileSync('assets/hud/rebirth-icons/rebirth-cycle-white.png');
http.createServer((req, res) => {
  if (req.url !== '/rebirth-cycle.png') { res.writeHead(404); res.end(); return; }
  res.writeHead(200, {'Content-Type': 'image/png'}); res.end(icon);
}).listen(34873, '127.0.0.1');
