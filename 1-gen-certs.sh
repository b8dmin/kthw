#!/usr/bin/bash

set +x

source hosts.sh

cd crts_cfgs

### gen CA cert
cat << EOF > ca-config.json
{"signing":{"default":{"expiry":"8760h"},"profiles":{"kubernetes":{"usages":["signing","key encipherment","server auth","client auth"],"expiry":"8760h"}}}}
EOF

cat << EOF > ca-csr.json 
{"CN":"Kubernetes","key":{"algo":"rsa","size":2048},"names":[{"C":"US","L":"Portland","O":"Kubernetes","OU":"CA","ST":"Oregon"}]}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

### gen admin cert
cat << EOF > admin-csr.json
{"CN":"admin","key":{"algo":"rsa","size":2048},"names":[{"C":"US","L":"Portland","O":"system:masters","OU":"Kubernetes The Hard Way","ST":"Oregon"}]}
EOF

# kube services
cat << EOF > kube-controller-manager-csr.json
{"CN":"system:kube-controller-manager","key":{"algo":"rsa","size":2048},"names":[{"C":"US","L":"Portland","O":"system:kube-controller-manager","OU":"Kubernetes The Hard Way","ST":"Oregon"}]}
EOF

cat << EOF > kube-proxy-csr.json
{"CN":"system:kube-proxy","key":{"algo":"rsa","size":2048},"names":[{"C":"US","L":"Portland","O":"system:node-proxier","OU":"Kubernetes The Hard Way","ST":"Oregon"}]}
EOF

cat << EOF > kube-scheduler-csr.json
{"CN":"system:kube-scheduler","key":{"algo":"rsa","size":2048},"names":[{"C":"US","L":"Portland","O":"system:kube-scheduler","OU":"Kubernetes The Hard Way","ST":"Oregon"}]}
EOF

# service-account crt
cat << EOF > service-account-csr.json
{"CN":"service-accounts","key":{"algo":"rsa","size":2048},"names":[{"C":"US","L":"Portland","O":"Kubernetes","OU":"Kubernetes The Hard Way","ST":"Oregon"}]}
EOF

for svc in admin kube-controller-manager kube-proxy kube-scheduler service-account; do
  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    ${svc}-csr.json | cfssljson -bare ${svc}
done

# gen WORKERS certs
for idx in $(seq 0 $((${#WORKERS_HN[@]} - 1))); do
  echo $idx - ${WORKERS_HN[idx]} 
  cat > ${WORKERS_HN[idx]}.${DOMAIN}-csr.json << EOF
{"CN":"system:node:${WORKERS_HN[idx]}.${DOMAIN}","key":{"algo":"rsa","size":2048},"names":[{"C":"US","L":"Portland","O":"system:nodes","OU":"Kubernetes The Hard Way","ST":"Oregon"}]}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${WORKERS_IPS[idx]},${WORKERS_HN[idx]}.${DOMAIN} \
  -profile=kubernetes \
  ${WORKERS_HN[idx]}.${DOMAIN}-csr.json | cfssljson -bare ${WORKERS_HN[idx]}.${DOMAIN}

done

# kube api certs
CERT_HOSTNAME=10.32.0.1,
for idx in $(seq 0 $((${#CPLAINS_HN[@]} - 1))); do
  echo $idx - ${CPLAINS_HN[idx]} 
  CERT_HOSTNAME=${CERT_HOSTNAME}${CPLAINS_HN[idx]}.${DOMAIN},${CPLAINS_IPS[idx]},
done
CERT_HOSTNAME=${CERT_HOSTNAME}${LB_IP},${LB_HN}.${DOMAIN},127.0.0.1,localhost,kubernetes.default


cat << EOF > kubernetes-csr.json
{"CN":"kubernetes","key":{"algo":"rsa","size":2048},"names":[{"C":"US","L":"Portland","O":"Kubernetes","OU":"Kubernetes The Hard Way","ST":"Oregon"}]}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${CERT_HOSTNAME} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
