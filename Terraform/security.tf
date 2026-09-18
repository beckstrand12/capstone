############################################
# Security Groups
############################################

# ============================================================
# WEB EC2
# ============================================================

resource "aws_security_group" "web" {
  name        = "${var.project}-web-sg"
  description = "Public web tier"
  vpc_id      = data.aws_vpc.main.id

  # Public website
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

  # Administrative SSH
  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # IT has full access to Web
  ingress {
    description = "Full access from on-prem IT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.on_prem_it_cidr]
  }

  # Web can initiate connections to other AWS resources.
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


# ============================================================
# APP EC2
# ============================================================

resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "Private application tier"
  vpc_id      = data.aws_vpc.main.id

  # Web EC2 -> App
  ingress {
    description     = "Application traffic from Web EC2"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "SSH from Web EC2"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "Ping from Web EC2"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.web.id]
  }

  # IT -> App: full access
  ingress {
    description = "Full access from on-prem IT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.on_prem_it_cidr]
  }

  # Production -> App: restricted ports
  ingress {
    description = "HTTP from on-prem Production"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_production_cidr]
  }

  ingress {
    description = "HTTPS from on-prem Production"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_production_cidr]
  }

  ingress {
    description = "Application port from on-prem Production"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_production_cidr]
  }

  ingress {
    description = "Ping from on-prem Production"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.on_prem_production_cidr]
  }

  # DB -> App is not required.
  # Servers -> App is not allowed.
  # DMZ -> App is not allowed.

  egress {
    description = "All outbound within private network/VPN"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-app-sg"
  }
}


# ============================================================
# DB EC2
# ============================================================

resource "aws_security_group" "db" {
  name        = "${var.project}-db-sg"
  description = "Private database tier"
  vpc_id      = data.aws_vpc.main.id

  # App -> DB
  ingress {
    description     = "PostgreSQL from App EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "Ping from App EC2"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.app.id]
  }

  # IT -> DB: full access
  ingress {
    description = "Full access from on-prem IT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.on_prem_it_cidr]
  }

  # Servers -> DB: restricted access
  ingress {
    description = "PostgreSQL from on-prem Servers"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_servers_cidr]
  }

  ingress {
    description = "MySQL from on-prem Servers"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_servers_cidr]
  }

  ingress {
    description = "SMB from on-prem Servers"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_servers_cidr]
  }

  ingress {
    description = "Ping from on-prem Servers"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.on_prem_servers_cidr]
  }

  # Production -> DB is not allowed.
  # DMZ -> DB is not allowed.
  # Web -> DB is not allowed.

  egress {
    description = "All outbound within private network/VPN"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-db-sg"
  }
}


############################################
# Network ACLs
#
# NACLs provide subnet-level boundaries.
# Security Groups provide instance-level boundaries.
#
# NACLs are stateless, so outbound traffic is explicitly allowed.
############################################


# ============================================================
# WEB SUBNET NACL
# ============================================================

resource "aws_network_acl" "web" {
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = [local.web_subnet_id]

  tags = {
    Name = "${var.project}-nacl-web"
  }
}

# Block Production
resource "aws_network_acl_rule" "web_in_deny_production" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 50
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = var.on_prem_production_cidr
  from_port      = 0
  to_port        = 0
}

# Block Servers
resource "aws_network_acl_rule" "web_in_deny_servers" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 60
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = var.on_prem_servers_cidr
  from_port      = 0
  to_port        = 0
}

# Block DMZ
resource "aws_network_acl_rule" "web_in_deny_dmz" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 70
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = var.on_prem_dmz_cidr
  from_port      = 0
  to_port        = 0
}

# IT has full access
resource "aws_network_acl_rule" "web_in_allow_it" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 80
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.on_prem_it_cidr
  from_port      = 0
  to_port        = 0
}

# Public HTTP
resource "aws_network_acl_rule" "web_in_http" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# Public HTTPS
resource "aws_network_acl_rule" "web_in_https" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# Admin SSH
resource "aws_network_acl_rule" "web_in_ssh" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.admin_cidr
  from_port      = 22
  to_port        = 22
}

# Return traffic
resource "aws_network_acl_rule" "web_in_ephemeral" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "web_out_all" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}


# ============================================================
# APP SUBNET NACL
# ============================================================

resource "aws_network_acl" "app" {
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = [aws_subnet.app.id]

  tags = {
    Name = "${var.project}-nacl-app"
  }
}

# Block DMZ
resource "aws_network_acl_rule" "app_in_deny_dmz" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 50
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = var.on_prem_dmz_cidr
  from_port      = 0
  to_port        = 0
}

# Block Servers
resource "aws_network_acl_rule" "app_in_deny_servers" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 60
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = var.on_prem_servers_cidr
  from_port      = 0
  to_port        = 0
}

# IT full access
resource "aws_network_acl_rule" "app_in_it" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 70
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.on_prem_it_cidr
  from_port      = 0
  to_port        = 0
}

# Production HTTP
resource "aws_network_acl_rule" "app_in_production_http" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.on_prem_production_cidr
  from_port      = 80
  to_port        = 80
}

# Production HTTPS
resource "aws_network_acl_rule" "app_in_production_https" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.on_prem_production_cidr
  from_port      = 443
  to_port        = 443
}

# Production App
resource "aws_network_acl_rule" "app_in_production_app" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.on_prem_production_cidr
  from_port      = 8080
  to_port        = 8080
}

# Production ping
resource "aws_network_acl_rule" "app_in_production_icmp" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 130
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = var.on_prem_production_cidr
  from_port      = -1
  to_port        = -1
}

# Web subnet -> App
resource "aws_network_acl_rule" "app_in_from_web" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 140
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = data.aws_subnet.public[local.web_subnet_id].cidr_block
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "app_out_all" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}


# ============================================================
# DB SUBNET NACL
# ============================================================

resource "aws_network_acl" "db" {
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = [aws_subnet.db.id]

  tags = {
    Name = "${var.project}-nacl-db"
  }
}

# Block Production
resource "aws_network_acl_rule" "db_in_deny_production" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 50
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = var.on_prem_production_cidr
  from_port      = 0
  to_port        = 0
}

# Block DMZ
resource "aws_network_acl_rule" "db_in_deny_dmz" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 60
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = var.on_prem_dmz_cidr
  from_port      = 0
  to_port        = 0
}

# IT full access
resource "aws_network_acl_rule" "db_in_it" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 70
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.on_prem_it_cidr
  from_port      = 0
  to_port        = 0
}

# App -> DB PostgreSQL
resource "aws_network_acl_rule" "db_in_from_app" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 80
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.app_subnet_cidr
  from_port      = 5432
  to_port        = 5432
}

# App -> DB ping
resource "aws_network_acl_rule" "db_in_from_app_icmp" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 90
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = var.app_subnet_cidr
  from_port      = -1
  to_port        = -1
}

# Servers -> DB PostgreSQL
resource "aws_network_acl_rule" "db_in_servers_postgres" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.on_prem_servers_cidr
  from_port      = 5432
  to_port        = 5432
}

# Servers -> DB MySQL
resource "aws_network_acl_rule" "db_in_servers_mysql" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.on_prem_servers_cidr
  from_port      = 3306
  to_port        = 3306
}

# Servers -> DB SMB
resource "aws_network_acl_rule" "db_in_servers_smb" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.on_prem_servers_cidr
  from_port      = 445
  to_port        = 445
}

# Servers -> DB ping
resource "aws_network_acl_rule" "db_in_servers_icmp" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 130
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = var.on_prem_servers_cidr
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "db_out_all" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}