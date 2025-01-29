# The vpc and subnets data block is only used if subnet ids are not defined

data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = [var.client_name]
  }
}

# Fetch subnets in the specified VPC and Availability Zone
data "aws_subnets" "vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "availability-zone"
    values = [var.availability_zone]
  }
}

# Fetch details of the first subnet in the filtered list
data "aws_subnet" "selected" {
  id = data.aws_subnets.vpc_subnets.ids[0]
}
