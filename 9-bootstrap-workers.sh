source hosts.sh

for idx in $(seq 0 $((${#WORKERS_HN[@]} - 1))); do
  echo wr_${idx} - ${WORKERS_HN[idx]}
  cat <<EOD | ssh root@${WORKERS_HN[idx]}.${DOMAIN} bash
sudo apt-get update
sudo apt-get -y install socat conntrack ipset

wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.27.0/crictl-v1.27.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz \
  https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.27.3/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.27.3/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.27.3/bin/linux/amd64/kubelet \
  https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/runsc \
  https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/containerd-shim-runsc-v1

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

chmod +x kubectl kube-proxy kubelet runc.amd64 runsc containerd-shim-runsc-v1
sudo mv runc.amd64 runc
sudo mv kubectl kube-proxy kubelet runc runsc containerd-shim-runsc-v1 /usr/local/bin/
sudo tar -xvf crictl-v1.27.0-linux-amd64.tar.gz -C /usr/local/bin/
sudo tar -xvf cni-plugins-linux-amd64-v1.3.0.tgz -C /opt/cni/bin/

mkdir containerd
sudo tar -xvf containerd-1.7.2-linux-amd64.tar.gz -C containerd
sudo mv containerd/bin/* /bin/

suro rm -rf containerd crictl-v1.27.0-linux-amd64.tar.gz cni-plugins-linux-amd64-v1.3.0.tgz containerd-1.7.2-linux-amd64.tar.gz

sudo mkdir -p /etc/containerd/

cat << EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF

# Create the containerd unit file:

cat << EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

EOD

  cat <<EOD | ssh root@${WORKERS_HN[idx]}.${DOMAIN} bash

cd /root/k8s
sudo cp ${WORKERS_HN[idx]}.${DOMAIN}-key.pem ${WORKERS_HN[idx]}.${DOMAIN}.pem /var/lib/kubelet/
sudo cp ${WORKERS_HN[idx]}.${DOMAIN}.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp ca.pem /var/lib/kubernetes/


cat << EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${WORKERS_HN[idx]}.${DOMAIN}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${WORKERS_HN[idx]}.${DOMAIN}-key.pem"
EOF

# Create the kubelet unit file:

cat << EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\\\
  --config=/var/lib/kubelet/kubelet-config.yaml \\\\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\\\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\\\
  --register-node=true \\\\
  --v=2 \\\\
  --hostname-override=${WORKERS_HN[idx]}.${DOMAIN}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat << EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

cat << EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\\\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

ufw disable
sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl restart containerd kubelet kube-proxy

EOD
done

