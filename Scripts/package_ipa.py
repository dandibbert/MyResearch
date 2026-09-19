#!/usr/bin/env python3
"""Package actual iphoneos arm64 products; never substitute simulator apps."""
import hashlib
import json
import os
import pathlib
import plistlib
import shutil
import subprocess
import zipfile

root=pathlib.Path(__file__).resolve().parents[1]
os.chdir(root)
app=root/'build/DerivedData/Build/Products/Release-iphoneos/MyResearch.app'
if not app.is_dir(): raise SystemExit('Missing Release-iphoneos app; device build must succeed first.')
info=plistlib.loads((app/'Info.plist').read_bytes())
if info.get('DTPlatformName') != 'iphoneos': raise SystemExit('Refusing to package a non-iphoneos app.')
binary=app/info['CFBundleExecutable']
arches=subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip()
if arches != 'arm64': raise SystemExit(f'Unexpected architecture: {arches}')
out=root/'dist'; out.mkdir(exist_ok=True)

def unsigned_copy(destination, core=False):
    if destination.exists(): shutil.rmtree(destination)
    payload=destination/'Payload'; payload.mkdir(parents=True)
    target=payload/app.name
    shutil.copytree(app,target,symlinks=True)
    if core and (target/'PlugIns').exists(): shutil.rmtree(target/'PlugIns')
    for path in list(target.rglob('_CodeSignature')):
        if path.is_dir(): shutil.rmtree(path)
    for path in list(target.rglob('embedded.mobileprovision')): path.unlink()
    for path in list(target.rglob('*')):
        if not path.is_file() or path.is_symlink(): continue
        with open(path,'rb') as handle: magic=handle.read(4)
        if magic in [b'\xcf\xfa\xed\xfe',b'\xce\xfa\xed\xfe',b'\xca\xfe\xba\xbe']:
            subprocess.run(['codesign','--remove-signature',str(path)],check=False,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            check=subprocess.run(['codesign','-d',str(path)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            if check.returncode==0: raise SystemExit(f'Binary still signed: {path}')
    filename='MyResearch-core-unsigned.ipa' if core else 'MyResearch-unsigned.ipa'
    with zipfile.ZipFile(out/filename,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for path in sorted(payload.rglob('*')):
            if path.is_file(): archive.write(path,path.relative_to(destination))
    with zipfile.ZipFile(out/filename) as archive:
        if archive.testzip() is not None: raise SystemExit('IPA zip integrity error')
        names=archive.namelist()
        if 'Payload/MyResearch.app/MyResearch' not in names: raise SystemExit('Executable not in IPA')
        if any('embedded.mobileprovision' in n or '/_CodeSignature/' in n for n in names): raise SystemExit('Signing materials leaked')
    print(filename, (out/filename).stat().st_size, 'bytes')

unsigned_copy(root/'build/package-full')
unsigned_copy(root/'build/package-core',core=True)
manifest={
    'app':'MyResearch','version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],
    'commit':os.environ.get('GITHUB_SHA','local'),'workflowRun':os.environ.get('GITHUB_RUN_ID','local'),
    'platform':info.get('DTPlatformName'),'sdk':info.get('DTSDKName'),'minimumOS':info.get('MinimumOSVersion'),
    'architectures':arches,'signed':False,'xcode':subprocess.check_output(['xcodebuild','-version'],text=True).strip(),
}
(out/'build-info.json').write_text(json.dumps(manifest,indent=2)+'\n')
checksums=[]
for path in sorted(out.glob('*.ipa')):
    checksums.append(hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.name)
(out/'SHA256SUMS.txt').write_text('\n'.join(checksums)+'\n')
for source,name in [('docs/INSTALL.md','INSTALL.md'),('docs/PRODUCT_DESIGN.md','PRODUCT_DESIGN.md')]:
    if (root/source).exists(): shutil.copy2(root/source,out/name)
# No certificate is included; only templates and re-signing guidance.
if (root/'Signing').is_dir():
    shutil.copytree(root/'Signing', out/'Signing', dirs_exist_ok=True)
if (root/'docs/SHARE_EXTENSION.md').exists():
    shutil.copy2(root/'docs/SHARE_EXTENSION.md', out/'SHARE_EXTENSION.md')
