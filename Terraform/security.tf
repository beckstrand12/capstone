############################################
# Security Groups
############################################

resource "aws_security_group" "web" {
  name        = "${var.project}-web-sg"
  description = "Web tier - internet facing"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from admin only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # No ingress rule references on-prem CIDRs at all - the public
  # route table has no route back to on-prem, so this is already
  # unreachable from there. See NACL below for a belt-and-suspenders
  # explicit deny.

  egress {
    description = "All outbound (internet + reaching the app server)"
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
  description = "App tier - private, reachable from web, db, and a specific on-prem subnet"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "App traffic from web server"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "SSH from web server (jump box)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "ICMP (ping) from web server"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "Traffic from db server"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.db.id]
  }

  ingress {
    description     = "ICMP (ping) from db server"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.db.id]
  }

  ingress {
    description = "SSH + app port from the on-prem subnet with direct access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_full_access_cidr]
  }

  ingress {
    description = "App port from the on-prem subnet with direct access"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_full_access_cidr]
  }

  ingress {
    description = "ICMP (ping) from the on-prem subnet with direct access"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.on_prem_full_access_cidr]
  }

  egress {
    description = "To web, db, and back out the VPN to on-prem"
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
  description = "DB tier - private, reachable only from app and a specific on-prem subnet"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "DB traffic from app server"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "SSH from app server (jump box)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "ICMP (ping) from app server"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description = "SSH from the on-prem subnet with direct access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_full_access_cidr]
  }

  ingress {
    description = "DB port from the on-prem subnet with direct access"
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_full_access_cidr]
  }

  ingress {
    description = "ICMP (ping) from the on-prem subnet with direct access"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.on_prem_full_access_cidr]
  }

  # No ingress from web-sg anywhere in this resource - db is
  # unreachable from the web tier, by design.

  egress {
    description = "To the app server"
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
# NACLs
# Stateless - explicit inbound AND outbound rules required.
############################################

# --- Web subnet NACL ---
# Attached only to the specific public subnet the web server sits
# in, so the other pre-existing public subnet is left untouched.
resource "aws_network_acl" "web" {
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = [local.web_subnet_id]

  tags = {
    Name = "${var.project}-nacl-web"
  }
}

# Explicit denies, evaluated first (lowest rule numbers win).
resource "aws_network_acl_rule" "web_in_deny_on_prem_subnet" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 50
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = var.on_prem_full_access_cidr
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "web_in_deny_blocked_host" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 60
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = var.on_prem_blocked_host
  from_port      = 0
  to_port        = 0
}

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

# --- App subnet NACL ---
resource "aws_network_acl" "app" {
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = [aws_subnet.app.id]

  tags = {
    Name = "${var.project}-nacl-app"
  }
}

resource "aws_network_acl_rule" "app_in_from_web" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = data.aws_subnet.public[local.web_subnet_id].cidr_block
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "app_in_from_db" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 110
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.db_subnet_cidr
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "app_in_from_on_prem_subnet" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 120
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.on_prem_full_access_cidr
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

# --- DB subnet NACL ---
# No rule anywhere in this NACL references the web subnet CIDR -
# default deny handles the web -> db block at the subnet level too.
resource "aws_network_acl" "db" {
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = [aws_subnet.db.id]

  tags = {
    Name = "${var.project}-nacl-db"
  }
}

resource "aws_network_acl_rule" "db_in_from_app" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.app_subnet_cidr
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "db_in_from_on_prem_subnet" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 110
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.on_prem_full_access_cidr
  from_port      = 0
  to_port        = 0
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
