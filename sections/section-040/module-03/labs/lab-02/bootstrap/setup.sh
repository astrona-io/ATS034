#!/usr/bin/env bash
set -euo pipefail
sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io curl python3 ca-certificates tcpdump wireguard-tools
sudo systemctl enable --now docker
case "$(uname -m)" in
 x86_64) arch=amd64; helm_sha=0403a88ae20913d11b10a2467b50087721fea7581736da6b9d3992f5357fe54b ;;
 aarch64) arch=arm64; helm_sha=8cf8f66ecbc252ac8f7f06cca68aba88508ddfde3a6a34feb1678ad1694b4f88 ;;
 *) exit 2 ;;
esac
curl -fL --retry 3 --max-time 180 "https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-$arch" -o /tmp/kind
curl -fL --retry 3 --max-time 30 "https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-$arch.sha256sum" -o /tmp/kind.sha256
printf '%s  /tmp/kind\n' "$(cut -d' ' -f1 /tmp/kind.sha256)" | sha256sum -c -
sudo install -m 0755 /tmp/kind /usr/local/bin/kind
curl -fL --retry 3 --max-time 180 "https://dl.k8s.io/release/v1.35.0/bin/linux/$arch/kubectl" -o /tmp/kubectl
curl -fL --retry 3 --max-time 30 "https://dl.k8s.io/release/v1.35.0/bin/linux/$arch/kubectl.sha256" -o /tmp/kubectl.sha256
printf '%s  /tmp/kubectl\n' "$(cat /tmp/kubectl.sha256)" | sha256sum -c -
sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
curl -fL --retry 3 --max-time 180 "https://get.helm.sh/helm-v4.3.1-linux-$arch.tar.gz" -o /tmp/helm.tar.gz
printf '%s  /tmp/helm.tar.gz\n' "$helm_sha" | sha256sum -c -
tar -xzf /tmp/helm.tar.gz -C /tmp
sudo install -m 0755 "/tmp/linux-$arch/helm" /usr/local/bin/helm
sudo install -d -m 0755 /etc/training
export KUBECONFIG=/etc/training/kubeconfig
sudo modprobe wireguard
sudo tee /etc/training/kind.yaml >/dev/null <<'KIND'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
- role: control-plane
- role: worker
KIND
sudo kind create cluster --name encryption --kubeconfig /etc/training/kubeconfig --config /etc/training/kind.yaml --image kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f
sudo chmod 0644 /etc/training/kubeconfig
sudo helm pull cilium --repo https://helm.cilium.io --version 1.20.4 --destination /etc/training
sudo helm --kubeconfig /etc/training/kubeconfig install cilium /etc/training/cilium-1.20.4.tgz --namespace kube-system --set operator.replicas=1 --set ipam.mode=kubernetes --set kubeProxyReplacement=false --set encryption.enabled=false --wait --timeout=8m
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
kubectl wait nodes --all --for=condition=Ready --timeout=180s
kubectl create namespace encryption-training
kubectl -n encryption-training run server --image=busybox:1.37.0 --overrides='{"spec":{"nodeName":"encryption-worker"}}' -- sh -c 'mkdir -p /www; echo encrypted-service >/www/index.html; httpd -f -p 8080 -h /www'
kubectl -n encryption-training run client --image=busybox:1.37.0 --overrides='{"spec":{"nodeName":"encryption-control-plane","tolerations":[{"operator":"Exists"}]}}' -- sleep 36000
kubectl -n encryption-training wait --for=condition=Ready pod --all --timeout=180s

sudo install -d /opt/astrona-live
sudo tee /opt/astrona-live/check.py >/dev/null <<'PY_CHECK'

import json,os,pathlib,subprocess,sys,time,uuid,tempfile
os.environ['KUBECONFIG']='/etc/training/kubeconfig'
def run(args,timeout=60): return subprocess.run(args,text=True,capture_output=True,timeout=timeout)
def k(*args):
    result=run(['kubectl',*args])
    if result.returncode: raise RuntimeError(result.stderr)
    return result.stdout
def get(kind,name,namespace=None):
    return json.loads(k(*(['-n',namespace] if namespace else []),'get',kind,name,'-o','json'))

def check(outcome):
    config=get('configmap','cilium-config','kube-system')['data']
    assert config.get('enable-wireguard')=='true', 'Enable Cilium WireGuard encryption'
    nodes=('encryption-control-plane','encryption-worker')
    pids={n:run(['docker','inspect','--format','{{.State.Pid}}',n]).stdout.strip() for n in nodes}
    for node,pid in pids.items():
        state=run(['nsenter','-t',pid,'-n','wg','show','cilium_wg0','peers'])
        assert state.returncode==0 and state.stdout.strip(), 'Both node kernels must have a WireGuard peer'
    if outcome=='wireguard-peers': return
    if outcome!='encrypted-traffic': raise RuntimeError('Unknown outcome')
    server=get('pod','server','encryption-training');client=get('pod','client','encryption-training')
    assert server['spec']['nodeName']==nodes[1] and client['spec']['nodeName']==nodes[0], 'Preserve cross-node scheduling'
    ip=server['status']['podIP'];nonce='packet-proof-'+uuid.uuid4().hex
    with tempfile.TemporaryDirectory() as temp:
        captures=[]
        try:
            for interface,file in [('eth0','outer'),('cilium_wg0','inner')]:
                captures.append(subprocess.Popen(['nsenter','-t',pids[nodes[0]],'-n','tcpdump','-U','-s','0','-i',interface,'-w',temp+'/'+file+'.pcap'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL))
            time.sleep(1)
            for _ in range(3):
                response=k('-n','encryption-training','exec','client','--','wget','-T','5','-qO-','http://'+ip+':8080/?proof='+nonce)
                assert response.strip()=='encrypted-service', 'Keep the cross-node application working'
            time.sleep(2)
        finally:
            for capture in captures:
                capture.terminate();capture.wait(timeout=5)
        outer=pathlib.Path(temp+'/outer.pcap').read_bytes();inner=pathlib.Path(temp+'/inner.pcap').read_bytes()
        assert nonce.encode() in inner, 'Observe the fresh request inside the WireGuard interface'
        assert nonce.encode() not in outer, 'Never expose the request nonce in plaintext on eth0'
        packets=run(['tcpdump','-nr',temp+'/outer.pcap','udp','port','51871'])
        assert packets.returncode==0 and packets.stdout.strip(), 'Observe WireGuard transport packets on eth0'

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])

PY_CHECK
