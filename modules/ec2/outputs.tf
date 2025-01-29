output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.ec2.public_ip
}

output "ami_id" {
  description = "The ID of the AMI used by the EC2 instance"
  value       = data.aws_ami.ami.id
}