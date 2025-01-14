data "aws_vpc" "selected" {
  id = var.vpc_id
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
