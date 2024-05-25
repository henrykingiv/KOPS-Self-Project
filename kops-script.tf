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
sleep 10

#variable for bucket and domain names
export NAME=henrykingroyal.co
export KOPS_STATE_STORE=s3://kops-socks-shop

# #execute kops commands to create our clusters
# sudo su -c "kops create cluster --cloud=aws \
#   --zones=eu-west-2a,eu-west-2b,eu-west-2c \
#   --control-plane-zones=eu-west-2a,eu-west-2b,eu-west-2c \
#   --networking calico \
#   --state=s3://kops-socks-shop \
#   --node-count=3 \
#   --topology private \
#   --bastion \
#   --ssh-public-key /home/ubuntu/.ssh/id_rsa.pub \
#   --node-size=t3.medium \
#   --control-plane-size=t3.medium \
#   --control-plane-count=3 \
#   --name=henrykingroyal.co \
#   --yes" ubuntu

# #update the cluster
# sudo su -c "kops update cluster --name henrykingroyal.co --state=s3://kops-socks-shop --yes --admin" ubuntu

# #To watch on your cluster creation 
# sudo su -c "kops validate cluster --state=s3://kops-socks-shop --wait 10m" ubuntu
EOF
}