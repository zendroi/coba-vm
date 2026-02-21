#!/usr/bin/env python3
"""Simple Bridge Proxy that rewrites paths like /chat/... to /v1/chat/... and forwards to CLIProxyAPI.

Usage:
  python3 bridge_proxy.py --listen 8320 --target-host 127.0.0.1 --target-port 8317
"""
import argparse
import http.client
import logging
import socketserver
from http.server import BaseHTTPRequestHandler


class ProxyHandler(BaseHTTPRequestHandler):
    def _rewrite_path(self, path: str) -> str:
        # If OpenCode sends /chat/..., convert to /v1/chat/...
        if path.startswith("/chat") and not path.startswith("/v1/"):
            return "/v1" + path
        return path

    def _forward(self):
        target_host = self.server.target_host
        target_port = self.server.target_port
        path = self._rewrite_path(self.path)

        try:
            length = int(self.headers.get('Content-Length', 0))
        except Exception:
            length = 0
        body = self.rfile.read(length) if length > 0 else None

        conn = http.client.HTTPConnection(target_host, target_port, timeout=20)
        # Copy headers except Host (we set a proper Host)
        headers = {k: v for k, v in self.headers.items() if k.lower() != 'host'}
        headers['Host'] = f"{target_host}:{target_port}"

        try:
            conn.request(self.command, path, body=body, headers=headers)
            resp = conn.getresponse()
            resp_body = resp.read()

            self.send_response(resp.status, resp.reason)
            # Filter hop-by-hop headers
            hop_by_hop = {
                'connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization',
                'te', 'trailers', 'transfer-encoding', 'upgrade'
            }
            for k, v in resp.getheaders():
                if k.lower() in hop_by_hop:
                    continue
                self.send_header(k, v)
            self.end_headers()
            if resp_body:
                self.wfile.write(resp_body)
        except Exception as e:
            logging.exception('Error forwarding request')
            self.send_error(502, f'Bad Gateway: {e}')
        finally:
            conn.close()

    def do_GET(self):
        self._forward()

    def do_POST(self):
        self._forward()

    def do_PUT(self):
        self._forward()

    def do_DELETE(self):
        self._forward()

    def do_PATCH(self):
        self._forward()

    def do_OPTIONS(self):
        self._forward()


class ThreadedHTTPServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True


def main():
    parser = argparse.ArgumentParser(description='Bridge proxy (rewrite /chat -> /v1/chat)')
    parser.add_argument('--listen', type=int, default=8320, help='listen port (default 8320)')
    parser.add_argument('--target-host', default='127.0.0.1', help='target host (default 127.0.0.1)')
    parser.add_argument('--target-port', type=int, default=8317, help='target port (default 8317)')
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s: %(message)s')
    server = ThreadedHTTPServer(('127.0.0.1', args.listen), ProxyHandler)
    server.target_host = args.target_host
    server.target_port = args.target_port
    logging.info('Bridge proxy listening on 127.0.0.1:%d -> %s:%d', args.listen, args.target_host, args.target_port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logging.info('Shutting down')
        server.shutdown()


if __name__ == '__main__':
    main()
