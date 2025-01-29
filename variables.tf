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
variable "gw_a_subnet" {
  description = "The ID of the subnet to launch the instance in"
  type        = string
  default     = ""
}
variable "gw_b_subnet" {
  description = "The ID of the subnet to launch the instance in"
  type        = string
  default     = ""
}
variable "iam_instance_profile" {
  description = "The name of the IAM instance profile to associate with the instance"
  type        = string
  default     = "EC2_servers"
}

variable "client_name" {
  description = "The client name to use for the instance tag"
  type        = string
}

variable "state" {
  description = "The state to use for the instance tag"
  type        = string
}

