#!/usr/bin/bash

source hosts.sh

for idx in $(seq 0 $((${#WORKERS_HN[@]} - 1))); do
  echo wr_${idx} - ${WORKERS_HN[idx]}
  cat <<EOD | ssh root@${WORKERS_HN[idx]}.${DOMAIN} bash
sudo apt-get update
sudo apt-get -y install socat conntrack ipset

wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-incubator/cri-tools/releases/download/v1.0.0-beta.0/crictl-v1.0.0-beta.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz \
  https://github.com/containerd/containerd/releases/download/v1.4.4/containerd-1.4.4-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubelet

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

chmod +x kubectl kube-proxy kubelet runc.amd64 
sudo mv runc.amd64 runc
sudo mv kubectl kube-proxy kubelet runc  /usr/local/bin/
sudo tar -xvf crictl-v1.0.0-beta.0-linux-amd64.tar.gz -C /usr/local/bin/
sudo tar -xvf cni-plugins-linux-amd64-v0.9.1.tgz -C /opt/cni/bin/

mkdir containerd
sudo tar -xvf containerd-1.4.4-linux-amd64.tar.gz -C containerd
sudo mv containerd/bin/* /bin/

suro rm -rf containerd crictl-v1.0.0-beta.0-linux-amd64.tar.gz cni-plugins-linux-amd64-v0.9.1.tgz containerd-1.4.4-linux-amd64.tar.gz

sudo mkdir -p /etc/containerd/

cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins."io.containerd.runc.v2"]
      runtime_type = "io.containerd.runc.v2"
      runtime_engine = "/usr/local/bin/runc"
    #[plugins.cri.containerd.untrusted_workload_runtime]
    #  runtime_type = "io.containerd.runtime.v1.linux"
    #  runtime_engine = "/usr/local/bin/runsc"
    #  runtime_root = "/run/containerd/runsc"
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
  --container-runtime=remote \\\\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\\\
  --image-pull-progress-deadline=2m \\\\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\\\
  --network-plugin=cni \\\\
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

