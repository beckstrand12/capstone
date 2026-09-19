# Virtual Private Gateway
resource "aws_vpn_gateway" "main" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Name = "${var.project}-vgw"
  }
}

# Customer Gateway
resource "aws_customer_gateway" "on_prem" {
  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.project}-cgw-on-prem"
  }
}

# VPN Connection - static
resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.on_prem.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "${var.project}-vpn-connection"
  }
}

resource "aws_vpn_connection_route" "on_prem" {
  vpn_connection_id      = aws_vpn_connection.main.id
  destination_cidr_block = var.on_prem_cidr
}

resource "aws_vpn_gateway_route_propagation" "private" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.private.id
}

data "aws_route_table" "web" {
  subnet_id = local.web_subnet_id
}

resource "aws_route" "web_to_on_prem" {
  route_table_id         = data.aws_route_table.web.id
  destination_cidr_block = var.on_prem_cidr
  gateway_id             = aws_vpn_gateway.main.id
}
