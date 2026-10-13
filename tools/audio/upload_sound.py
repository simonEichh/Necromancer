"""Uploads prepared sounds to Roblox (Open Cloud Assets API) and prints their asset ids.

  python tools/audio/upload_sound.py sounds/loops/rumble.ogg [more files...]

Needs the API key in tools/audio/.roblox_api_key (git-ignored; permission: assets read + write). The sounds are
uploaded to the user below. New audio goes through moderation: it can take a few minutes before it plays in game.
Results are also appended to tools/audio/uploaded.txt (path -> rbxassetid).
"""
import json
import os
import sys
import time
import urllib.request
import uuid

USER_ID = "7135437538"
HERE = os.path.dirname(os.path.abspath(__file__))
KEY = open(os.path.join(HERE, ".roblox_api_key"), encoding="utf-8").read().strip()
API = "https://apis.roblox.com/assets/v1"
TYPES = {".ogg": "audio/ogg", ".mp3": "audio/mpeg", ".wav": "audio/wav", ".flac": "audio/flac"}


def request(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": KEY, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raise SystemExit("%s %s -> %d %s" % (method, url, e.code, e.read().decode()[:500]))


def upload(path):
    name = os.path.splitext(os.path.basename(path))[0]
    folder = os.path.basename(os.path.dirname(path))
    meta = {
        "assetType": "Audio",
        "displayName": "Necro %s %s" % (folder, name),
        "description": "Necro Buddies sound: %s/%s" % (folder, name),
        "creationContext": {"creator": {"userId": USER_ID}},
    }
    boundary = uuid.uuid4().hex
    data = open(path, "rb").read()
    ctype = TYPES[os.path.splitext(path)[1].lower()]
    body = b"".join([
        b"--" + boundary.encode() + b"\r\n",
        b'Content-Disposition: form-data; name="request"\r\n\r\n',
        json.dumps(meta).encode(), b"\r\n",
        b"--" + boundary.encode() + b"\r\n",
        ('Content-Disposition: form-data; name="fileContent"; filename="%s"\r\n' % os.path.basename(path)).encode(),
        ("Content-Type: %s\r\n\r\n" % ctype).encode(),
        data, b"\r\n",
        b"--" + boundary.encode() + b"--\r\n",
    ])
    op = request("POST", API + "/assets", body, {"Content-Type": "multipart/form-data; boundary=" + boundary})
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", API + "/operations/" + op_id)
    if not op.get("done"):
        raise SystemExit("%s: still processing (operation %s), run again later" % (path, op_id))
    asset_id = op["response"]["assetId"]
    line = "%s -> rbxassetid://%s" % (path.replace("\\", "/"), asset_id)
    print(line)
    with open(os.path.join(HERE, "uploaded.txt"), "a", encoding="utf-8") as f:
        f.write(line + "\n")
    return asset_id


for p in sys.argv[1:]:
    upload(p)
