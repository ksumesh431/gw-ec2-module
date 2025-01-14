variable "instance_type" {
  type        = string
  description = "The type of EC2 instance to launch"
  default     = "t3a.micro"
}

variable "key_name" {
  type        = string
  description = "The name of the SSH key to use for the instance"
}

variable "availability_zone" {
  type        = string
  description = "The availability zone to launch the instance in"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the vpc to launch the instance in"
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "The IDs of the security groups to associate with the instance"
}

variable "iam_instance_profile" {
  type        = string
  description = "The name of the IAM instance profile to associate with the instance"
}

variable "tag_client_name" {
  type        = string
  description = "The client name to use for the instance tag"
}

variable "tag_logical_name" {
  type        = string
  description = "The logical name to use for the instance tag"
}

variable "tag_name" {
  type        = string
  description = "The name to use for the instance tag"
}

variable "tag_role" {
  type        = string
  description = "The role to use for the instance tag"
}

variable "tag_state" {
  type        = string
  description = "The state to use for the instance tag"
}
