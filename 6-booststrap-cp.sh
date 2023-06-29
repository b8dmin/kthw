source hosts.sh

for idx in $(seq 0 $((${#CPLAINS_HN[@]} - 1))); do
  echo cp_${idx} - ${CPLAINS_HN[idx]}
  cat <<EOD | ssh root@${CPLAINS_HN[idx]}.${DOMAIN} bash
    sudo mkdir -p /etc/kubernetes/config
    wget -q --show-progress --https-only --timestamping \
        "https://storage.googleapis.com/kubernetes-release/release/v1.27.3/bin/linux/amd64/kube-apiserver" \
        "https://storage.googleapis.com/kubernetes-release/release/v1.27.3/bin/linux/amd64/kube-controller-manager" \
        "https://storage.googleapis.com/kubernetes-release/release/v1.27.3/bin/linux/amd64/kube-scheduler" \
        "https://storage.googleapis.com/kubernetes-release/release/v1.27.3/bin/linux/amd64/kubectl"
    chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
    sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
EOD

done



ETCD_SERVERS=https://${CPLAINS_IPS[0]}:2379
for idx in $(seq 1 $((${#CPLAINS_HN[@]} - 1))); do
  ETCD_SERVERS=${ETCD_SERVERS},https://${CPLAINS_IPS[idx]}:2379
done

for idx in $(seq 0 $((${#CPLAINS_HN[@]} - 1))); do
  echo cp_${idx} - ${CPLAINS_HN[idx]}
  cat <<EOD | ssh root@${CPLAINS_HN[idx]}.${DOMAIN} bash
cd /root/k8s

sudo mkdir -p /var/lib/kubernetes/
sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
  service-account-key.pem service-account.pem \
  encryption-config.yaml /var/lib/kubernetes/

cat << EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\\\
  --advertise-address=${CPLAINS_IPS[idx]} \\\\
  --allow-privileged=true \\\\
  --apiserver-count=3 \\\\
  --audit-log-maxage=30 \\\\
  --audit-log-maxbackup=3 \\\\
  --audit-log-maxsize=100 \\\\
  --audit-log-path=/var/log/audit.log \\\\
  --authorization-mode=Node,RBAC \\\\
  --bind-address=0.0.0.0 \\\\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\\\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\\\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\\\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\\\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\\\
  --etcd-servers=${ETCD_SERVERS} \\\\
  --event-ttl=1h \\\\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\\\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\\\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\\\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\\\
  --runtime-config=api/all=true \\\\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\\\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\\\
  --service-account-issuer=https://${LB_IP}:6443 \\\\
  --service-cluster-ip-range=10.32.0.0/24 \\\\
  --service-node-port-range=30000-32767 \\\\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\\\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\\\
  --v=2 \\\\
  --kubelet-preferred-address-types=InternalIP,InternalDNS,Hostname,ExternalIP,ExternalDNS
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-apiserver
systemctl restart kube-apiserver
EOD
done

for idx in $(seq 0 $((${#CPLAINS_HN[@]} - 1))); do
  echo cp_${idx} - ${CPLAINS_HN[idx]}
  cat <<EOD | ssh root@${CPLAINS_HN[idx]}.${DOMAIN} bash
cd /root/k8s

sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/

cat << EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\\\
  --bind-address=0.0.0.0 \\\\
  --cluster-cidr=10.200.0.0/16 \\\\
  --cluster-name=kubernetes \\\\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\\\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\\\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\\\
  --leader-elect=true \\\\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\\\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\\\
  --service-cluster-ip-range=10.32.0.0/24 \\\\
  --use-service-account-credentials=true \\\\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl restart kube-controller-manager
EOD
done


for idx in $(seq 0 $((${#CPLAINS_HN[@]} - 1))); do
  echo cp_${idx} - ${CPLAINS_HN[idx]}
  cat <<EOD | ssh root@${CPLAINS_HN[idx]}.${DOMAIN} bash
cd /root/k8s
sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/

cat << EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

cat << EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\\\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\\\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-scheduler
systemctl restart kube-scheduler
EOD

done