#!/usr/bin/bash

source hosts.sh
cd crts_cfgs

KUBERNETES_ADDRESS=$LB_IP

# Generate a kubelet kubeconfig for each worker node:
for idx in $(seq 0 $((${#WORKERS_HN[@]} - 1))); do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_ADDRESS}:6443 \
    --kubeconfig=${WORKERS_HN[idx]}.${DOMAIN}.kubeconfig
  kubectl config set-credentials system:node:${WORKERS_HN[idx]}.${DOMAIN} \
    --client-certificate=${WORKERS_HN[idx]}.${DOMAIN}.pem \
    --client-key=${WORKERS_HN[idx]}.${DOMAIN}-key.pem \
    --embed-certs=true \
    --kubeconfig=${WORKERS_HN[idx]}.${DOMAIN}.kubeconfig
  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${WORKERS_HN[idx]}.${DOMAIN} \
    --kubeconfig=${WORKERS_HN[idx]}.${DOMAIN}.kubeconfig

  kubectl config use-context default --kubeconfig=${WORKERS_HN[idx]}.${DOMAIN}.kubeconfig
done

# Generate a kube-proxy kubeconfig:
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig
  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig
  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}

# Generate a kube-controller-manager kubeconfig:
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}

# Generate a kube-scheduler kubeconfig:
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}

# Generate an admin kubeconfig:
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}


# remote kubeconfig
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${LB_HN}.${DOMAIN}:6443 \
    --kubeconfig=../kthw.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --kubeconfig=../kthw.kubeconfig

  kubectl config set-context kthw \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=../kthw.kubeconfig

  kubectl config use-context kthw --kubeconfig=../kthw.kubeconfig
}