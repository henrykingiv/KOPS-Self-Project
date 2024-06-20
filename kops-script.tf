locals {
  script = <<-EOF
#!/bin/bash

sudo apt update -y
sudo apt upgrade -y

#install aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
unzip awscliv2.zip
sudo ./aws/install

#install kubectl to administer our cluster
sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
sudo chmod +x kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
 
#install kops to create cluster
curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
sudo chmod +x kops-linux-amd64
sudo mv kops-linux-amd64 /usr/local/bin/kops

#installing helm
wget https://get.helm.sh/helm-v3.9.3-linux-amd64.tar.gz
tar xvf helm-v3.9.3-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin
rm helm-v3.9.3-linux-amd64.tar.gz

#configuring the aws cli on your ubuntu user
sudo su -c "aws configure set aws_access_key_id ${aws_iam_access_key.kop-user-access-key.id}" ubuntu
sudo su -c "aws configure set aws_secret_access_key ${aws_iam_access_key.kop-user-access-key.secret}" ubuntu
sudo su -c "aws configure set default.region eu-west-2" ubuntu
sudo su -c "aws configure set default.output text" ubuntu

#make access key for environment variable
export AWS_ACCESS_KEY_ID=${aws_iam_access_key.kop-user-access-key.id}
export AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.kop-user-access-key.secret}

#create keypair 
sudo su -c "ssh-keygen -t rsa -m PEM -f /home/ubuntu/.ssh/id_rsa -q -N ''" ubuntu

#create rest time
sleep 20

#variable for bucket and domain names
export NAME=henrykingroyal.co
export KOPS_STATE_STORE=s3://kops-socks-shop

# #execute kops commands to create our clusters
sudo su -c "kops create cluster --cloud=aws \
  --zones=eu-west-2a,eu-west-2b,eu-west-2c \
  --control-plane-zones=eu-west-2a,eu-west-2b,eu-west-2c \
  --networking calico \
  --state=s3://kops-socks-shop \
  --node-count=3 \
  --topology private \
  --bastion \
  --ssh-public-key /home/ubuntu/.ssh/id_rsa.pub \
  --node-size=t3.medium \
  --control-plane-size=t3.medium \
  --control-plane-count=3 \
  --name=henrykingroyal.co \
  --yes" ubuntu

# #update the cluster
sudo su -c "kops update cluster --name henrykingroyal.co --state=s3://kops-socks-shop --yes --admin" ubuntu

# #To watch on your cluster creation 
sudo su -c "kops validate cluster --state=s3://kops-socks-shop --wait 15m" ubuntu

sudo su -c "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml" ubuntu
sleep 20

sudo cat <<EOT> /home/ubuntu/admin-user.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOT
sudo chown ubuntu:ubuntu /home/ubuntu/admin-user.yaml 
sudo su -c "kubectl apply -f /home/ubuntu/admin-user.yaml" ubuntu

sudo cat <<EOT> /home/ubuntu/cluster-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOT

sudo chown ubuntu:ubuntu /home/ubuntu/cluster-binding.yaml 
sudo su -c "kubectl apply -f /home/ubuntu/cluster-binding.yaml" ubuntu

#Argocd namespace and deployment manifest
sudo su -c "kubectl create namespace argocd" ubuntu
sudo su -c "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" ubuntu


# # Ingress-nginx Helm Chart installation with Helm
sudo su -c "helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx" ubuntu
sudo su -c "helm repo update" ubuntu
sudo su -c "helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace" ubuntu

sudo su -c "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts" ubuntu
sudo su -c "helm repo add grafana https://grafana.github.io/helm-charts" ubuntu
sudo su -c "helm repo update" ubuntu

sudo su -c "helm install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace" ubuntu
sudo su -c "helm install grafana grafana/grafana --namespace monitoring" ubuntu
sleep 30

#Token Creation for namespaces
sudo su -c "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode > /home/ubuntu/argopassword" ubuntu
sudo su -c "kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode > /home/ubuntu/grafpassword" ubuntu
sudo su -c "kubectl -n kubernetes-dashboard create token admin-user > /home/ubuntu/token" ubuntu

#Repo Deployment for Stage and Prod
# REPO_URL="https://github.com/henrykingiv/boutique-microservices-application.git"
# TARGET_DIR="/home/ubuntu/boutique-microservices-application"

# # Create the target directory with correct permissions
# sudo mkdir -p $TARGET_DIR
# sudo chown -R ubuntu:ubuntu $TARGET_DIR

# # Switch to the target directory
# cd /home/ubuntu

# # Clone the repository
# sudo -u ubuntu git clone $REPO_URL $TARGET_DIR
# sudo su -c "kubectl apply -f /home/ubuntu/boutique-microservices-application/complete.yaml" ubuntu
sleep 40


# #Loadbalancer Network configuration
sudo cat <<EOT> /home/ubuntu/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  tls:
    - hosts:
        - kubernetes.henrykingroyal.co
      secretName: kubernetes-dashboard-tls
  rules:
    - host: kubernetes.henrykingroyal.co
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard
                port:
                  number: 443

---

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  tls:
    - hosts:
        - argocd.henrykingroyal.co
      secretName: argocd-tls
  rules:
    - host: argocd.henrykingroyal.co
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: stage-boutique
spec:
  ingressClassName: nginx
  rules:
    - host: stage.henrykingroyal.co
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
            path: /
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: prod-boutique
spec:
  ingressClassName: nginx
  rules:
    - host: prod.henrykingroyal.co
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
            path: /
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
    - host: prometheus.henrykingroyal.co
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-server
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
    - host: grafana.henrykingroyal.co
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 80

EOT

sudo chown ubuntu:ubuntu /home/ubuntu/ingress.yaml
sudo su -c "kubectl apply -f /home/ubuntu/ingress.yaml" ubuntu
EOF
}

# kops delete cluster --name henrykingroyal.co --state=s3://kops-socks-shop --yes

# kubectl get secret --namespace prometheus grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo