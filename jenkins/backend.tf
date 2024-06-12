terraform {
  backend "s3" {
    bucket         = "kops-socks-shop"
    key            = "jenkins-server/tfstate"
    dynamodb_table = "kops-socks-table"
    region         = "eu-west-2"
    encrypt        = true
    profile        = "LeadUser"
  }
}
