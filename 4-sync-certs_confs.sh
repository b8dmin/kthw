#!/usr/bin/env bash

source hosts.sh
set +x
# controll plains
cp_files=(
    kube-scheduler.kubeconfig
    admin.kubeconfig
    kube-controller-manager.kubeconfig
    ca.pem 
    ca-key.pem  
    kubernetes.pem 
    kubernetes-key.pem 
    service-account.pem 
    service-account-key.pem
    encryption-config.yaml
)

for idx in $(seq 0 $((${#CPLAINS_HN[@]} - 1))); do
  echo cp_${idx} - ${CPLAINS_HN[idx]}
  #ssh root@${CPLAINS_HN[idx]}.${DOMAIN} rm -rf /root/k8s
  rsync -a --files-from=<( printf "%s\n" "${cp_files[@]}" ) ./crts_cfgs/ root@${CPLAINS_HN[idx]}.${DOMAIN}:~/k8s/
done



# workers
for idx in $(seq 0 $((${#WORKERS_HN[@]} - 1))); do
  echo wr_${idx} - ${WORKERS_HN[idx]}
  w_files=(
    ca.pem
    ${WORKERS_HN[idx]}.${DOMAIN}-key.pem
    ${WORKERS_HN[idx]}.${DOMAIN}.pem
    ${WORKERS_HN[idx]}.${DOMAIN}.kubeconfig
    kube-proxy.kubeconfig
  )
  #ssh root@${CPLAINS_HN[idx]}.${DOMAIN} rm -rf /root/k8s
  rsync -a --files-from=<( printf "%s\n" "${w_files[@]}" ) ./crts_cfgs/ root@${WORKERS_HN[idx]}.${DOMAIN}:~/k8s/
done