output "web_subnet_id" {
  value = local.web_subnet_id
}

output "app_subnet_id" {
  value = aws_subnet.app.id
}

output "db_subnet_id" {
  value = aws_subnet.db.id
}

output "web_public_ip" {
  value = aws_eip.web.public_ip
}

output "web_private_ip" {
  value = aws_instance.web.private_ip
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}

output "vpn_connection_id" {
  value = aws_vpn_connection.main.id
}

output "vpn_tunnel1_address" {
  value = aws_vpn_connection.main.tunnel1_address
}

output "vpn_tunnel2_address" {
  value = aws_vpn_connection.main.tunnel2_address
}

output "vpn_tunnel1_cgw_inside_address" {
  description = "Address to set on the on-prem tunnel interface (append /30)"
  value       = aws_vpn_connection.main.tunnel1_cgw_inside_address
}

output "vpn_tunnel1_vgw_inside_address" {
  description = "AWS-side tunnel inside address (the on-prem router's peer)"
  value       = aws_vpn_connection.main.tunnel1_vgw_inside_address
}

output "vpn_tunnel1_preshared_key" {
  description = "PSK for tunnel 1 - retrieve with: terraform output -raw vpn_tunnel1_preshared_key"
  value       = aws_vpn_connection.main.tunnel1_preshared_key
  sensitive   = true
}

output "vpn_tunnel2_cgw_inside_address" {
  value = aws_vpn_connection.main.tunnel2_cgw_inside_address
}

output "vpn_tunnel2_vgw_inside_address" {
  value = aws_vpn_connection.main.tunnel2_vgw_inside_address
}

output "vpn_tunnel2_preshared_key" {
  description = "PSK for tunnel 2 - retrieve with: terraform output -raw vpn_tunnel2_preshared_key"
  value       = aws_vpn_connection.main.tunnel2_preshared_key
  sensitive   = true
}

output "customer_gateway_id" {
  value = aws_customer_gateway.on_prem.id
}

output "vpn_gateway_id" {
  value = aws_vpn_gateway.main.id
}
