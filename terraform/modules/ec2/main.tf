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
  user_data = templatefile("${path.module}/files/user_data.tpl", {})
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

# Look up the instance profile to get its role name
data "aws_iam_instance_profile" "this" {
  name = var.iam_instance_profile
}

# Attach the inline policy to the role used by the instance profile
resource "aws_iam_role_policy" "gw_b_v2_migration" {
  name = "gw-b-v2-migration-policy"
  role = data.aws_iam_instance_profile.this.role

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESListIdentities"
        Effect = "Allow"
        Action = [
          "ses:ListIdentities",
          "ses:GetIdentityVerificationAttributes"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEIPAssociationInUsEast2"
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:DescribeAddresses",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "us-east-2"
          }
        }
      }
    ]
  })
}
