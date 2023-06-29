source hosts.sh

INITIAL_CLUSTER=${CPLAINS_HN[0]}.${DOMAIN}=https://${CPLAINS_IPS[0]}:2380
for idx in $(seq 1 $((${#CPLAINS_HN[@]} - 1))); do
  INITIAL_CLUSTER=${INITIAL_CLUSTER},${CPLAINS_HN[idx]}.${DOMAIN}=https://${CPLAINS_IPS[idx]}:2380
done



for idx in $(seq 0 $((${#CPLAINS_HN[@]} - 1))); do
  echo cp_${idx} - ${CPLAINS_HN[idx]}
  cat <<EOD | ssh root@${CPLAINS_HN[idx]}.${DOMAIN} bash
wget --show-progress  https://github.com/coreos/etcd/releases/download/v3.4.26/etcd-v3.4.26-linux-amd64.tar.gz
tar -xf etcd-v3.4.26-linux-amd64.tar.gz
mv etcd-v3.4.26-linux-amd64/etcd* /usr/local/bin/
mkdir -p /etc/etcd /var/lib/etcd
cd /root/k8s
cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
cat << EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd  \\\\
  --name ${CPLAINS_HN[idx]}.${DOMAIN}  \\\\
  --cert-file=/etc/etcd/kubernetes.pem  \\\\
  --key-file=/etc/etcd/kubernetes-key.pem  \\\\
  --peer-cert-file=/etc/etcd/kubernetes.pem  \\\\
  --peer-key-file=/etc/etcd/kubernetes-key.pem  \\\\
  --trusted-ca-file=/etc/etcd/ca.pem  \\\\
  --peer-trusted-ca-file=/etc/etcd/ca.pem  \\\\
  --peer-client-cert-auth  \\\\
  --client-cert-auth  \\\\
  --initial-advertise-peer-urls https://${CPLAINS_IPS[idx]}:2380  \\\\
  --listen-peer-urls https://${CPLAINS_IPS[idx]}:2380  \\\\
  --listen-client-urls https://${CPLAINS_IPS[idx]}:2379,https://127.0.0.1:2379  \\\\
  --advertise-client-urls https://${CPLAINS_IPS[idx]}:2379 \\\\
  --initial-cluster-token etcd-cluster-0 \\\\
  --initial-cluster ${INITIAL_CLUSTER} \\\\
  --initial-cluster-state new \\\\
  --data-dir=/var/lib/etcd 
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cd ~
rm -rf etcd*

systemctl daemon-reload
systemctl enable etcd
systemctl restart etcd
ufw disable
EOD

done