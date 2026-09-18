############################################
# Virtual Private Gateway - attached to the existing VPC
############################################

resource "aws_vpn_gateway" "main" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Name = "${var.project}-vgw"
  }
}

############################################
# Customer Gateway - represents the on-prem router/firewall
############################################

resource "aws_customer_gateway" "on_prem" {
  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.project}-cgw-on-prem"
  }
}

############################################
# VPN Connection - static routing (no BGP)
############################################

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

############################################
# Propagate the VPN connection's static route into the private
# route table, so APP and DB instances send on-prem-bound replies
# back through the tunnel. This is the standard AWS mechanism for
# this - it works with static routing too, not just BGP: once the
# route exists on the VPN connection (above), propagation pushes
# it into any route table that opts in.
#
# The public (web) route table is never given propagation, so it
# never learns a route to on-prem at all - this is what makes the
# web server unreachable from any on-prem address, regardless of
# security group/NACL rules.
############################################

resource "aws_vpn_gateway_route_propagation" "private" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.private.id
}
