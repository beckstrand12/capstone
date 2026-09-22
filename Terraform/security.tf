# SECURITY GROUPS ============================================================

resource "aws_security_group" "web" {
  name        = "${var.project}-web-sg"
  description = "Public web tier"
  vpc_id      = data.aws_vpc.main.id

  # Public web access
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Administration
  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # IT management
  ingress {
    description = "SSH from on-prem IT"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_it_cidr]
  }

  # ICMP from on-prem IT
  ingress {
    description = "ICMP from on-prem IT"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = [var.on_prem_it_cidr]
  }

  # ICMP from App subnet
  ingress {
    description = "ICMP from App subnet"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = [var.app_subnet_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-web-sg"
  }
}


resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "Private application tier"
  vpc_id      = data.aws_vpc.main.id

  # Web to App - application traffic
  ingress {
    description     = "Application traffic from Web"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Web to App - SSH
  ingress {
    description     = "SSH from Web"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Web to App - ICMP
  ingress {
    description = "ICMP from Web subnet"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = [data.aws_subnet.web.cidr_block]
  }

  # IT to App - application traffic
  ingress {
    description = "Application access from on-prem IT"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_it_cidr]
  }

  # IT to App - SSH
  ingress {
    description = "SSH from on-prem IT"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_it_cidr]
  }

  # IT to App - ICMP
  ingress {
    description = "ICMP from on-prem IT"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = [var.on_prem_it_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-app-sg"
  }
}


resource "aws_security_group" "db" {
  name        = "${var.project}-db-sg"
  description = "Private database tier"
  vpc_id      = data.aws_vpc.main.id

  # App to DB - PostgreSQL
  ingress {
    description     = "PostgreSQL from App"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # App to DB - ICMP
  ingress {
    description     = "ICMP from App"
    protocol        = "icmp"
    from_port       = -1
    to_port         = -1
    security_groups = [aws_security_group.app.id]
  }

  # IT to DB - PostgreSQL
  ingress {
    description = "PostgreSQL from on-prem IT"
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_it_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-db-sg"
  }
}


# WEB NACL ============================================================

resource "aws_network_acl" "web" {
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = [local.web_subnet_id]

  tags = {
    Name = "${var.project}-nacl-web"
  }

  # HTTP from Internet
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # HTTPS from Internet
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # SSH from administrator
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.admin_cidr
    from_port  = 22
    to_port    = 22
  }

  # SSH from on-prem IT
  ingress {
    rule_no    = 125
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.on_prem_it_cidr
    from_port  = 22
    to_port    = 22
  }

  # ICMP from on-prem IT
  ingress {
    rule_no    = 127
    protocol   = "icmp"
    action     = "allow"
    cidr_block = var.on_prem_it_cidr
    from_port  = -1
    to_port    = -1
  }

  # Ephemeral TCP ports for return traffic
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}


# APP NACL ============================================================

resource "aws_network_acl" "app" {
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = [aws_subnet.app.id]

  tags = {
    Name = "${var.project}-nacl-app"
  }

  # Web to App - application traffic
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = data.aws_subnet.web.cidr_block
    from_port  = var.app_port
    to_port    = var.app_port
  }

  # Web to App - SSH
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = data.aws_subnet.web.cidr_block
    from_port  = 22
    to_port    = 22
  }

  # Web to App - ICMP
  ingress {
    rule_no    = 115
    protocol   = "icmp"
    action     = "allow"
    cidr_block = data.aws_subnet.web.cidr_block
    from_port  = -1
    to_port    = -1
  }

  # IT to App
  ingress {
    rule_no    = 120
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.on_prem_it_cidr
  }

  # Ephemeral TCP ports for return traffic
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}


# DB NACL ============================================================

resource "aws_network_acl" "db" {
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = [aws_subnet.db.id]

  tags = {
    Name = "${var.project}-nacl-db"
  }

  # App to DB - PostgreSQL
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.app_subnet_cidr
    from_port  = var.db_port
    to_port    = var.db_port
  }

  # App to DB - ICMP
  ingress {
    rule_no    = 105
    protocol   = "icmp"
    action     = "allow"
    cidr_block = var.app_subnet_cidr
    from_port  = -1
    to_port    = -1
  }

  # IT to DB
  ingress {
    rule_no    = 110
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.on_prem_it_cidr
  }

  # Ephemeral TCP ports for return traffic
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}