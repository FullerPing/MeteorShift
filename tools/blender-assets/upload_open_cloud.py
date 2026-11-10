"""Upload FBX models to Roblox through Open Cloud and record their asset ids.

    python tools/blender-assets/upload_open_cloud.py blender/upload/*.fbx

Needs ROBLOX_API_KEY (an Open Cloud key with asset write access for the game's group). Uploads to the group that owns
the place (GROUP_ID) and writes blender/upload/asset-ids.json ({file stem: asset id}); files already listed there are
skipped, so a rerun only uploads what is new. Studio then loads each id with game:GetObjects.
"""
import json, os, sys, time, uuid, urllib.request, urllib.error
from pathlib import Path

GROUP_ID = 526085770
API = 'https://apis.roblox.com/assets/v1/'
KEY = os.environ['ROBLOX_API_KEY']


def call(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={'x-api-key': KEY, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{method} {url} -> {e.code}: {e.read().decode(errors="replace")[:400]}')


def upload(path: Path) -> str:
    request = {'assetType': 'Model', 'displayName': 'MS_' + path.stem, 'description': 'MeteorShift map dressing',
               'creationContext': {'creator': {'groupId': str(GROUP_ID)}}}
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n{json.dumps(request)}\r\n'
            f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
            f'Content-Type: model/fbx\r\n\r\n').encode() + path.read_bytes() + f'\r\n--{boundary}--\r\n'.encode()
    op = call('POST', API + 'assets', body, {'Content-Type': f'multipart/form-data; boundary={boundary}'})
    for _ in range(60):
        if op.get('done'):
            if 'error' in op:
                raise RuntimeError(f'{path.name}: {op["error"]}')
            return op['response']['assetId']
        time.sleep(2)
        op = call('GET', API + op['path'])
    raise RuntimeError(f'{path.name}: upload did not finish')


def main(files):
    out = Path('blender/upload/asset-ids.json')
    ids = json.loads(out.read_text()) if out.exists() else {}
    for f in map(Path, files):
        if f.stem in ids:
            continue
        ids[f.stem] = upload(f)
        print(f.stem, ids[f.stem], flush=True)
        out.write_text(json.dumps(ids, indent=2))


if __name__ == '__main__':
    main(sys.argv[1:])
