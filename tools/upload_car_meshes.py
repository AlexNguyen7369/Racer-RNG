"""Upload redesigned car FBX files as Roblox Model assets through Open Cloud (docs/CAR_REDESIGN_SPEC.md).

    python3 tools/upload_car_meshes.py [--skip-done] go_kart [more ids...]

Reads ROBLOX_OPEN_CLOUD_KEY, ROBLOX_CREATOR_ID and optional ROBLOX_CREATOR_TYPE (user|group) from the environment.
Uploads drafts/cars/<id>/redesign/<id>.fbx and records the Model asset id in assets/meshes/cars/ids.json.
"""
import concurrent.futures
import json
import os
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IDS = ROOT / 'assets/meshes/cars/ids.json'
API = 'https://apis.roblox.com/assets/v1/'


def call(method, url, key, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={'x-api-key': key, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=120) as res:
            return json.loads(res.read() or b'{}')
    except urllib.error.HTTPError as e:
        raise SystemExit(f'{method} {url} -> {e.code}: {e.read().decode(errors="replace")[:500]}')


def upload(car_id, key, creator):
    fbx = ROOT / 'drafts/cars' / car_id / 'redesign' / (car_id + '.fbx')
    request = {
        'assetType': 'Model',
        'displayName': ('car_' + car_id)[:50],
        'description': 'Racer RNG car skin (redesign): ' + car_id,
        'creationContext': {'creator': creator},
    }
    boundary = uuid.uuid4().hex
    body = b''.join([
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n'.encode(),
        json.dumps(request).encode(), b'\r\n',
        f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{fbx.name}"\r\n'
        f'Content-Type: model/fbx\r\n\r\n'.encode(),
        fbx.read_bytes(), b'\r\n', f'--{boundary}--\r\n'.encode(),
    ])
    op = call('POST', API + 'assets', key, body, {'Content-Type': f'multipart/form-data; boundary={boundary}'})
    for _ in range(60):
        if op.get('done'):
            break
        time.sleep(2)
        op = call('GET', API + op['path'], key)
    if not op.get('done') or 'response' not in op:
        raise SystemExit(f'{car_id}: upload did not finish: {op}')
    return op['response']['assetId']


def main():
    key = os.environ.get('ROBLOX_OPEN_CLOUD_KEY')
    creator_id = os.environ.get('ROBLOX_CREATOR_ID')
    if not key or not creator_id:
        raise SystemExit('Set ROBLOX_OPEN_CLOUD_KEY and ROBLOX_CREATOR_ID (see manual.json car-redesign-upload-key).')
    kind = 'groupId' if os.environ.get('ROBLOX_CREATOR_TYPE') == 'group' else 'userId'
    ids = json.loads(IDS.read_text()) if IDS.exists() else {}
    # --skip-done leaves cars that already have an id (resume an interrupted batch); otherwise every id re-uploads.
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    todo = [c for c in args if '--skip-done' not in sys.argv or c not in ids]
    lock = threading.Lock()

    def one(car_id):
        asset = upload(car_id, key, {kind: creator_id})
        with lock:
            ids[car_id] = asset
            IDS.parent.mkdir(parents=True, exist_ok=True)
            IDS.write_text(json.dumps(dict(sorted(ids.items())), indent=2) + '\n')
            print(car_id, asset, flush=True)

    # Roblox takes ~25 s to process each model, so a few uploads run side by side.
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for future in [pool.submit(one, c) for c in todo]:
            future.result()


if __name__ == '__main__':
    main()
