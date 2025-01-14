variable "aws_region" {
  description = "The AWS region to use"
  type        = string
}

variable "key_name" {
  description = "The name of the SSH key to use for the instance"
  type        = string
}

variable "availability_zone_gw_a" {
  description = "The availability zone to launch the instance in"
  type        = string
}
variable "availability_zone_gw_b" {
  description = "The availability zone to launch the instance in"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the vpc to launch the instance in"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "The IDs of the security groups to associate with the instance"
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "The name of the IAM instance profile to associate with the instance"
  type        = string
}

variable "client_name" {
  description = "The client name to use for the instance tag"
  type        = string
}

variable "state" {
  description = "The state to use for the instance tag"
  type        = string
}

