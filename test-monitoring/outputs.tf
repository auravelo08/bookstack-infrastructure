output "instance_public_ip" {
  description = "instance public ip"
  value       = aws_instance.ubuntu.public_ip
}