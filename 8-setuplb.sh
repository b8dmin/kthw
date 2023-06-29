#!/usr/bin/bash

source hosts.sh

UPSTREAMS="        server ${CPLAINS_IPS[0]}:6443;"
for idx in $(seq 1 $((${#CPLAINS_HN[@]} - 1))); do
  UPSTREAMS=${UPSTREAMS}"\n       server ${CPLAINS_IPS[idx]}:6443;"
done



cat <<EOD | ssh root@${LB_HN}.${DOMAIN} bash
sudo apt-get install -y nginx

sudo systemctl enable nginx
sudo mkdir -p /etc/nginx/tcpconf.d

echo "include /etc/nginx/tcpconf.d/*;" >> /etc/nginx/nginx.conf

cat << EOF | sudo tee /etc/nginx/tcpconf.d/kubernetes.conf
stream {
    upstream kubernetes {
$(echo ${UPSTREAMS})
    }

    server {
        listen 6443;
        listen 443;
        proxy_pass kubernetes;
    }
}
EOF

sudo nginx -s reload
curl -k https://localhost:6443/version
EOD