############################################
# Existing VPC and public subnets (pre-created by the lab)
############################################

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnet" "public" {
  for_each = toset(var.public_subnet_ids)
  id       = each.value
}

# Pick whichever of the two existing public subnets sits in web_az.
# This avoids hardcoding which subnet ID maps to which AZ.
locals {
  web_subnet_id = [
    for s in data.aws_subnet.public : s.id if s.availability_zone == var.web_az
  ][0]
}

############################################
# New private subnets - app and db, one each, single-AZ (no HA)
############################################

resource "aws_subnet" "app" {
  vpc_id            = data.aws_vpc.main.id
  cidr_block        = var.app_subnet_cidr
  availability_zone = var.app_az

  tags = {
    Name = "${var.project}-app-private"
    Tier = "app-private"
  }
}

resource "aws_subnet" "db" {
  vpc_id            = data.aws_vpc.main.id
  cidr_block        = var.db_subnet_cidr
  availability_zone = var.db_az

  tags = {
    Name = "${var.project}-db-private"
    Tier = "db-private"
  }
}

############################################
# Route table - shared by both app and db private subnets
# No default route (no NAT Gateway, no IGW route) - these subnets
# have zero internet access, by design. Only the local VPC route
# (implicit) applies plus whatever the VPN gateway propagates in
# (see vpn.tf - aws_vpn_gateway_route_propagation).
############################################

resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Name = "${var.project}-rt-private"
  }
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.private.id
}

# Note: the two existing public subnets already have their own
# route table with a default route to the Internet Gateway - we
# don't touch that here.
