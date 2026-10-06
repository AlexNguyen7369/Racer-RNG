#!/usr/bin/env python3
"""Read or edit the running dashboard from Codex or a terminal (stdlib only)."""
import argparse
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("endpoint", help="API path, e.g. todo, meta, agents, manual/<id>, team/sync")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--session", help="session id from meta, for agents/messages/agent/<id>")
    parser.add_argument("--json", dest="body", help="POST this JSON object; without it, read with GET")
    args = parser.parse_args()
    endpoint = args.endpoint.removeprefix("/api/").strip("/")
    if not endpoint or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_/-" for c in endpoint):
        parser.error("endpoint must be an API path, without a URL or query string")
    data = None
    if args.body is not None:
        try:
            body = json.loads(args.body)
        except ValueError as exc:
            parser.error(f"invalid JSON: {exc}")
        if not isinstance(body, dict):
            parser.error("POST body must be a JSON object")
        data = json.dumps(body).encode()
    url = f"http://127.0.0.1:{args.port}/api/{endpoint}"
    if args.session:
        url += "?" + urlencode({"session": args.session})
    try:
        request = Request(url, data=data, headers={"Content-Type": "application/json"})
        with urlopen(request, timeout=30) as response:
            print(json.dumps(json.load(response), indent=2))
    except HTTPError as exc:
        print(exc.read().decode(), file=sys.stderr)
        return 1
    except (URLError, ValueError) as exc:
        print(f"Dashboard unavailable: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
