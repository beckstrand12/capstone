# Existing VPC and public subnets (pre-created by the lab)
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnet" "web" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Zone"
    values = ["Public"]
  }

  filter {
    name   = "tag:Name"
    values = [var.web_subnet_name]
  }
}

locals {
  web_subnet_id = data.aws_subnet.web.id
}

# New private subnets
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