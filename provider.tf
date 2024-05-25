provider "aws" {
  region = "eu-west-2"
  profile = "LeadUser"
}

locals {
  name = "kops-self-project"
}