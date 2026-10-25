#!/usr/bin/env python3
"""Visitor counter for the portfolio's interview-mode 3-tier stack.

Config comes from Parameter Store, the DB password from Secrets Manager.
Nothing secret is stored on disk or in code.
"""
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg2

ENV = os.environ["APP_ENV"]
PREFIX = f"/cloud-portfolio/{ENV}/db"
PORT = int(os.environ.get("APP_PORT", "8080"))


def aws(*args):
    """Run an AWS CLI command and return its text output."""
    out = subprocess.run(["aws", *args, "--output", "text"],
                         check=True, capture_output=True, text=True)
    return out.stdout.strip()


def load_params():
    names = [f"{PREFIX}/{n}" for n in ("host", "port", "name", "secret-arn")]
    raw = aws("ssm", "get-parameters", "--names", *names,
              "--query", "Parameters[].[Name,Value]")
    pairs = dict(line.split("\t", 1) for line in raw.splitlines())
    return {key.rsplit("/", 1)[1]: val for key, val in pairs.items()}


def load_secret(arn):
    secret = aws("secretsmanager", "get-secret-value",
                 "--secret-id", arn, "--query", "SecretString")
    return json.loads(secret)


PARAMS = load_params()


def connect():
    creds = load_secret(PARAMS["secret-arn"])
    return psycopg2.connect(host=PARAMS["host"], port=int(PARAMS["port"]),
                            dbname=PARAMS["name"], user=creds["username"],
                            password=creds["password"], sslmode="require",
                            connect_timeout=5)


def bump_count():
    """Add one visit and return the new total. Retries once on auth/connection errors."""
    for attempt in (1, 2):
        try:
            with connect() as conn, conn.cursor() as cur:
                cur.execute("CREATE TABLE IF NOT EXISTS visits "
                            "(id INT PRIMARY KEY, total BIGINT NOT NULL)")
                cur.execute("INSERT INTO visits (id, total) VALUES (1, 1) "
                            "ON CONFLICT (id) DO UPDATE SET total = visits.total + 1 "
                            "RETURNING total")
                return cur.fetchone()[0]
        except psycopg2.OperationalError:
            if attempt == 2:
                raise


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/api/health":
            self._send(200, {"status": "ok"})
        elif self.path == "/api/visits":
            try:
                self._send(200, {"visits": bump_count()})
            except Exception:
                self._send(503, {"error": "counter unavailable"})
        else:
            self._send(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} {fmt % args}", flush=True)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
