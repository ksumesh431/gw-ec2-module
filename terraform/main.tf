module "gateway_a_server" {
  source               = "./modules/ec2"
  client_name          = var.client_name
  key_name             = var.key_name
  availability_zone    = var.availability_zone_gw_a
  gw_a_subnet          = var.gw_a_subnet
  iam_instance_profile = var.iam_instance_profile
  # migrate_gw_a_eip     = var.migrate_gw_a_eip
  # migrate_gw_b_eip     = var.migrate_gw_b_eip
  # old_gw_a_instance_id = var.old_gw_a_instance_id
  # old_gw_b_instance_id = var.old_gw_b_instance_id
  tag_client_name      = var.client_name
  tag_logical_name     = "GatewayAServer"
  tag_name             = "${var.client_name}-gw-a"
  tag_role             = "gw-a-server"
  tag_state            = var.state
}

module "gateway_b_server" {
  source               = "./modules/ec2"
  client_name          = var.client_name
  key_name             = var.key_name
  availability_zone    = var.availability_zone_gw_b
  gw_b_subnet          = var.gw_b_subnet
  iam_instance_profile = var.iam_instance_profile
  # migrate_gw_a_eip     = var.migrate_gw_a_eip
  # migrate_gw_b_eip     = var.migrate_gw_b_eip
  # old_gw_a_instance_id = var.old_gw_a_instance_id
  # old_gw_b_instance_id = var.old_gw_b_instance_id
  tag_client_name      = var.client_name
  tag_logical_name     = "GatewayBServer"
  tag_name             = "${var.client_name}-gw-b"
  tag_role             = "gw-b-server"
  tag_state            = var.state
}

output "gateway_a_server_public_ip" {
  value = module.gateway_a_server.public_ip
}

output "gateway_b_server_public_ip" {
  value = module.gateway_b_server.public_ip
}
