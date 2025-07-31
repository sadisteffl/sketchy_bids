output "db_vm_public_ip" {
  description = "Public IP address of the Database VM."
  value       = aws_instance.mongodb_server.public_ip
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host."
  value       = aws_instance.bastion_host.public_ip
}