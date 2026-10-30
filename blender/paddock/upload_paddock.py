"""Upload the paddock props through Open Cloud, like tools/upload_car_meshes.py (same key / creator env vars).

    SSL_CERT_FILE=/etc/ssl/cert.pem python3 blender/paddock/upload_paddock.py

Uploads TimingTower.fbx / TyreStack.fbx as Model assets and PaddockPalette.png as a Decal, and records the asset ids
in blender/paddock/ids.json. The MeshId / image id inside each asset is read in Studio afterwards
(InsertService:LoadAsset), as the car pipeline does.
"""
import json
import os
import sys
import time
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / 'tools'))
from upload_car_meshes import API, call  # noqa: E402


def upload(path, asset_type, mime, key, creator):
    request = {'assetType': asset_type, 'displayName': 'paddock_' + path.stem,
               'description': 'Racer RNG spawn paddock prop: ' + path.stem, 'creationContext': {'creator': creator}}
    boundary = uuid.uuid4().hex
    body = b''.join([
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n'.encode(), json.dumps(request).encode(),
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
        f'Content-Type: {mime}\r\n\r\n'.encode(), path.read_bytes(), f'\r\n--{boundary}--\r\n'.encode(),
    ])
    op = call('POST', API + 'assets', key, body, {'Content-Type': f'multipart/form-data; boundary={boundary}'})
    for _ in range(60):
        if op.get('done'):
            break
        time.sleep(2)
        op = call('GET', API + op['path'], key)
    if not op.get('done') or 'response' not in op:
        raise SystemExit(f'{path.name}: upload did not finish: {op}')
    return op['response']['assetId']


def main():
    key, creator_id = os.environ.get('ROBLOX_OPEN_CLOUD_KEY'), os.environ.get('ROBLOX_CREATOR_ID')
    if not key or not creator_id:
        raise SystemExit('Set ROBLOX_OPEN_CLOUD_KEY and ROBLOX_CREATOR_ID (see manual.json car-redesign-upload-key).')
    creator = {'groupId' if os.environ.get('ROBLOX_CREATOR_TYPE') == 'group' else 'userId': creator_id}
    ids = {}
    for name in ['TimingTower', 'TyreStack']:
        ids[name] = upload(HERE / (name + '.fbx'), 'Model', 'model/fbx', key, creator)
        print(name, ids[name], flush=True)
    ids['PaddockPalette'] = upload(HERE / 'PaddockPalette.png', 'Decal', 'image/png', key, creator)
    print('PaddockPalette', ids['PaddockPalette'])
    (HERE / 'ids.json').write_text(json.dumps(ids, indent=2) + '\n')


if __name__ == '__main__':
    main()
