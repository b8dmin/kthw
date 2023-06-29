source hosts.sh
export KUBECONFIG=kthw.kubeconfig

for idx in $(seq 0 $((${#WORKERS_HN[@]} - 1))); do
  echo wr_${idx} - ${WORKERS_HN[idx]}
  cat <<EOD | ssh root@${WORKERS_HN[idx]}.${DOMAIN} bash
    sudo sysctl net.ipv4.conf.all.forwarding=1
    echo "net.ipv4.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.d/99-k8s.conf
EOD

done
set -x
cat << EOF > kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

patches:
  - patch: |-
      - op: add
        path: ./spec/template/spec/containers/0/env/-
        value:
          name: IPALLOC_RANGE
          value: "10.200.0.0/16"
    target:
      group: apps
      version: v1
      kind: DaemonSet
      name: weave-net
EOF

kubectl apply -k .

rm kustomization.yaml


# install DNS
kubectl apply -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/deployments/coredns-1.7.0.yaml