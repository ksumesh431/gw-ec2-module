data "aws_ami" "ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "ena-support"
    values = ["true"]
  }

  owners = ["amazon"] # Restrict to AMIs owned by Amazon
}



resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  availability_zone      = var.availability_zone
  tenancy                = "default"
  subnet_id              = data.aws_subnet.selected.id # fetched dynamically based on vpc and AZ
  ebs_optimized          = false
  vpc_security_group_ids = var.vpc_security_group_ids
  source_dest_check      = true
  root_block_device {
    volume_size           = 25
    volume_type           = "gp3"
    delete_on_termination = false
  }
  iam_instance_profile = var.iam_instance_profile
  tags = {
    APM              = "Observium"
    Application      = "EC2"
    ClientName       = var.tag_client_name
    Environment      = "aws_prod"
    FrontlineProduct = "erp_teams"
    LogicalName      = var.tag_logical_name
    Name             = var.tag_name
    Owner            = "DIST_Technology_SaaSIO_SRE_Team_Cask@frontlineed.com"
    Role             = var.tag_role
    State            = var.tag_state
  }
}
