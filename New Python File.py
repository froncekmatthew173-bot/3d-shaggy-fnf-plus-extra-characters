#!/usr/bin/env python3

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ANDROID_REPO = "https://github.com/Luansilv16/Psych-Engine-1.0.4-Android.git"
MOD_REPO = "https://github.com/froncekmatthew173-bot/3d-shaggy-fnf-plus-extra-characters.git"

OUT = Path("Merged-PsychEngine")

def run(cmd, cwd=None):
    print(" ".join(cmd))
    subprocess.check_call(cmd, cwd=cwd)

tmp = Path(tempfile.mkdtemp())

android = tmp / "android"
mod = tmp / "mod"

run(["git","clone",ANDROID_REPO,str(android)])
run(["git","clone",MOD_REPO,str(mod)])

if OUT.exists():
    shutil.rmtree(OUT)

shutil.copytree(android, OUT)

os.chdir(OUT)

run(["git","init"])
run(["git","config","user.name","merge"])
run(["git","config","user.email","merge@local"])

run(["git","add","."])
run(["git","commit","-m","Android base"])

merge_dir = tmp/"modcopy"
shutil.copytree(mod, merge_dir, dirs_exist_ok=True)

for root, dirs, files in os.walk(merge_dir):
    for f in files:
        src = Path(root)/f
        rel = src.relative_to(merge_dir)
        dst = OUT/rel

        dst.parent.mkdir(parents=True, exist_ok=True)

        if not dst.exists():
            shutil.copy2(src,dst)
        else:
            shutil.copy2(src,dst)

run(["git","add","."])

try:
    run(["git","commit","-m","Imported mod"])
except:
    pass

print()
print("="*60)
print("Merge complete!")
print("Output:", OUT.resolve())
print("="*60)