#!/usr/bin/env bash
set -euo pipefail

sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io curl ca-certificates bzip2 python3
case "$(uname -m)" in
  x86_64) arch=x86_64; checksum=6f6b1a8f0f4665a403238135167d0d990bfaeaff5544abf68f5e0d822b35484a ;;
  aarch64) arch=aarch64; checksum=909c95f245a46000d3bb0d5285f07dde23597056e7c3a4aab758b218e95bdab0 ;;
  *) exit 2 ;;
esac
curl -fL --retry 3 --max-time 180 "https://github.com/google/gvisor/releases/download/release-20261102.0/gvisor-$arch.tar.bz2" -o /tmp/gvisor.tar.bz2
printf '%s  /tmp/gvisor.tar.bz2\n' "$checksum" | sha256sum -c -
sudo tar -xjf /tmp/gvisor.tar.bz2 -C /usr/local/bin
sudo /usr/local/bin/runsc --version
sudo systemctl enable --now docker
sudo docker pull busybox:1.37.0
sudo install -d /srv/scout /opt/astrona-live
printf 'scout-ready\n' | sudo tee /srv/scout/index.html >/dev/null
sudo sh -c 'find /usr/local/bin/gvisor-bin -type f -exec sha256sum {} +; sha256sum /usr/local/bin/runsc' | sudo tee /opt/astrona-live/runtime.sha256 >/dev/null

sudo install -d /opt/astrona-live
sudo tee /opt/astrona-live/check.py >/dev/null <<'PY_CHECK'

import json, subprocess, sys, uuid
def run(args,timeout=45):
    return subprocess.run(args,text=True,capture_output=True,timeout=timeout)
def docker(*args):
    return run(['docker',*args])
def check(outcome):
    hashes=run(['sha256sum','-c','/opt/astrona-live/runtime.sha256'])
    assert hashes.returncode==0, 'Preserve the pinned gVisor binaries'
    info=docker('info','--format','{{json .Runtimes}}')
    if info.returncode: raise RuntimeError('Docker unavailable: '+info.stderr)
    runtimes=json.loads(info.stdout)
    assert 'runsc' in runtimes, 'Register and load the runsc runtime'
    assert runtimes['runsc'].get('path')=='/usr/local/bin/runsc', 'Use the installed runsc binary'
    if outcome=='runtime':
        fresh=docker('run','--rm','--runtime=runsc','--network=none','busybox:1.37.0','dmesg')
        assert fresh.returncode==0 and 'gVisor' in fresh.stdout, 'A fresh container must start under gVisor'
    elif outcome=='workload':
        result=docker('inspect','scout')
        assert result.returncode==0, 'Create the scout container'
        spec=json.loads(result.stdout)[0]
        assert spec['State']['Running'] and spec['HostConfig']['Runtime']=='runsc', 'Run scout with the runsc runtime'
        assert spec['Config']['Image']=='busybox:1.37.0', 'Keep the supplied workload image'
        log=docker('exec','scout','dmesg')
        assert log.returncode==0 and 'gVisor' in log.stdout, 'The workload must run within the gVisor application kernel'
        response=run(['curl','--noproxy','*','--max-time','5','-fsS','http://127.0.0.1:8080/'])
        assert response.returncode==0 and response.stdout.strip()=='scout-ready', 'Preserve the HTTP response through the sandbox'
    else: raise RuntimeError('Unknown outcome')

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])

PY_CHECK
