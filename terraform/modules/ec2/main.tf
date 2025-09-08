data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_security_group" "edge_sg" {
  filter {
    name   = "tag:Name"
    values = ["edge-sg"]
  }
}


locals {
  defined_subnet_id = var.tag_logical_name == "GatewayAServer" ? var.gw_a_subnet : var.gw_b_subnet
}

resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  availability_zone      = var.availability_zone
  tenancy                = "default"
  subnet_id              = local.defined_subnet_id != "" ? local.defined_subnet_id : data.aws_subnet.selected.id # if empty value, then subnet id fetched dynamically based on vpc and AZ
  ebs_optimized          = false
  vpc_security_group_ids = [data.aws_security_group.edge_sg.id]
  source_dest_check      = true
  user_data = "${path.module}/files/user_data.tpl"
  # user_data = templatefile("${path.module}/files/user_data.tpl", {
  #   ansible_playbook = templatefile(
  #     "${path.module}/files/ansible/${var.tag_logical_name == "GatewayAServer" ? "ansible_playbook_gw_a.tpl" : "ansible_playbook_gw_b.tpl"}",
  #     {
  #       client_name = var.client_name
  #     }
  #   )
  # })
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = false
  }
  iam_instance_profile = var.iam_instance_profile
  tags = {
    Email            = "SMTP"
    Application      = "EC2"
    ClientName       = lower(var.tag_client_name)
    Environment      = "aws_prod"
    FrontlineProduct = "erp_teams"
    LogicalName      = var.tag_logical_name
    Name             = lower("${var.tag_name}-v2")
    Owner            = "DIST_Technology_SaaSIO_SRE_Team_Cask@frontlineed.com"
    Role             = var.tag_role
    State            = var.tag_state
  }
}

# Conditional EIP migration from old gateway to this instance
locals {
  is_gateway_a    = var.tag_logical_name == "GatewayAServer"
  do_migrate_eip  = local.is_gateway_a ? var.migrate_gw_a_eip : var.migrate_gw_b_eip
  old_instance_id = local.is_gateway_a ? var.old_gw_a_instance_id : var.old_gw_b_instance_id
}

data "aws_instance" "old_gateway" {
  count       = local.do_migrate_eip && local.old_instance_id != "" ? 1 : 0
  instance_id = local.old_instance_id
}

data "aws_eip" "old_gateway_eip" {
  count     = local.do_migrate_eip && local.old_instance_id != "" ? 1 : 0
  public_ip = data.aws_instance.old_gateway[0].public_ip
}

resource "aws_eip_association" "migrate_eip" {
  count               = local.do_migrate_eip && local.old_instance_id != "" ? 1 : 0
  allocation_id       = data.aws_eip.old_gateway_eip[0].id
  instance_id         = aws_instance.ec2.id
  allow_reassociation = true
}
