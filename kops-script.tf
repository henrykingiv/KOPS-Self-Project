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
  --node-count=5 \
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

EOT

sudo chown ubuntu:ubuntu /home/ubuntu/ingress.yaml
sudo su -c "kubectl apply -f /home/ubuntu/ingress.yaml" ubuntu

#Create istio namespace and install instio

# Define variables
ISTIO_VERSION="1.16.2"
TARGET_DIREC="/home/ubuntu/istio-1.16.2"
PROFILE="default"
KUBECONFIG_PATH="/home/ubuntu/.kube/config"

# Create directory for Istio
sudo mkdir -p $TARGET_DIREC

#Change ownership
sudo chown -R ubuntu:ubuntu $TARGET_DIREC
cd $TARGET_DIREC

# Download Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -

sleep 5

# Move to Istio directory
sudo chown -R ubuntu:ubuntu istio-1.16.2
cd istio-1.16.2

sleep 10

# Add istioctl to PATH
export PATH=$PWD/bin:$PATH

# Persist the PATH update
echo 'export PATH=$HOME/istio-1.16.2/bin:$PATH' >> /home/ubuntu/.bashrc

# Source the .bashrc to make istioctl available immediately
source /home/ubuntu/.bashrc

# Set up KUBECONFIG environment variable
export KUBECONFIG=$KUBECONFIG_PATH

sleep 10

# Install Istio
istioctl install -y

# Verify the installation
sudo su -c "kubectl get pods -n istio-system" ubuntu
sudo su -c "kubectl -n istio-system get deploy" ubuntu

# Label default namespace for Istio sidecar injection
sudo su -c "kubectl create namespace istio" ubuntu
sudo su -c "kubectl label namespace istio istio-injection=enabled" ubuntu

# Label namespace for Prod manifest
sudo su -c "kubectl create namespace prod-istio" ubuntu
sudo su -c "kubectl label namespace prod-istio istio-injection=enabled" ubuntu

sudo echo "Istio installation is complete."

sudo su -c "kubectl apply -f ~/istio-1.16.2/istio-1.16.2/samples/addons" ubuntu
sleep 10

# echo "Fetching initial admin password..."
# ARGOCD_ADMIN_PASSWORD=$(<argopassword)
# echo "Initial admin password: $ARGOCD_ADMIN_PASSWORD"

# # Step 5: Login to ArgoCD using CLI
# ARGOCD_SERVER="argocd.henrykingroyal.co"
# echo "Logging in to ArgoCD..."
# argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_ADMIN_PASSWORD --insecure

# # Step 6: Create a new ArgoCD application
# echo "Creating ArgoCD application..."
# argocd app create my-app \
#   --repo https://github.com/henrykingiv/boutique-microservices-application.git \
#   --path . \
#   --dest-server http://kubernetes.henrykingroyal.co \
#   --dest-namespace istio

# # Step 7: Sync the application to deploy it
# echo "Deploying the application..."
# argocd app sync my-app

# echo "ArgoCD setup and application deployment complete!"

# #Repo Deployment for Stage and Prod
# REPO_URL="https://github.com/henrykingiv/boutique-microservices-application.git"
# TARGET_DIR="/home/ubuntu/boutique-microservices-application"

# # Create the target directory with correct permissions
# sudo mkdir -p $TARGET_DIR
# sudo chown -R ubuntu:ubuntu $TARGET_DIR

# # Switch to the target directory
# cd /home/ubuntu

# # Clone the repository
# sudo -u ubuntu git clone $REPO_URL $TARGET_DIR
# sudo su -c "kubectl apply -f /home/ubuntu/boutique-microservices-application/deployment.yaml" ubuntu
# sleep 20

# Istio Network Gateway Configuration
sudo cat <<EOT> /home/ubuntu/istio.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: app-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "boutique.henrykingroyal.co"
    - "kiali.henrykingroyal.co"
    - "prometheus.henrykingroyal.co"
    - "grafana.henrykingroyal.co"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend
  namespace: istio
spec:
  hosts:
  - "boutique.henrykingroyal.co"
  gateways:
  - istio-system/app-gateway
  http:
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: frontend
        port:
          number: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: kiali
  namespace: istio-system
spec:
  hosts:
  - "kiali.henrykingroyal.co"
  gateways:
  - app-gateway
  http:
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: kiali
        port:
          number: 20001

---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: prometheus
  namespace: istio-system
spec:
  hosts:
  - "prometheus.henrykingroyal.co"
  gateways:
  - app-gateway
  http:
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: prometheus
        port:
          number: 9090

---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: grafana
  namespace: istio-system
spec:
  hosts:
  - "grafana.henrykingroyal.co"
  gateways:
  - app-gateway
  http:
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: grafana
        port:
          number: 3000

EOT

sudo chown ubuntu:ubuntu /home/ubuntu/istio.yaml
sudo su -c "kubectl apply -f /home/ubuntu/istio.yaml" ubuntu

EOF
}

# kops delete cluster --name henrykingroyal.co --state=s3://kops-socks-shop --yes

# kubectl get secret --namespace prometheus grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
