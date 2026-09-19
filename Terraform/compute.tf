# AMI lookup - Amazon Linux 2023
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# Web server - public subnet =========================================

resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = local.web_subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  dynamic "credit_specification" {
    for_each = startswith(var.instance_type, "t3") ? [1] : []
    content {
      cpu_credits = "standard"
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  tags = {
    Name = "${var.project}-web"
  }
}

resource "aws_eip" "web" {
  domain   = "vpc"
  instance = aws_instance.web.id

  tags = {
    Name = "${var.project}-web-eip"
  }
}


# App server - private subnet ========================================

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.app.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_name

  dynamic "credit_specification" {
    for_each = startswith(var.instance_type, "t3") ? [1] : []
    content {
      cpu_credits = "standard"
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  tags = {
    Name = "${var.project}-app"
  }
}


# DB server - private subnet ====================================

resource "aws_instance" "db" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.db.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = var.key_name

  dynamic "credit_specification" {
    for_each = startswith(var.instance_type, "t3") ? [1] : []
    content {
      cpu_credits = "standard"
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  tags = {
    Name = "${var.project}-db"
  }
}
