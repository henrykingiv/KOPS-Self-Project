output "kops-ip" {
  value = aws_instance.kops-server.public_ip
}