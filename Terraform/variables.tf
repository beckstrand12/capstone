############################################
# General
############################################

variable "aws_region" {
  description = "AWS region - lab requires us-west-2"
  type        = string
  default     = "us-west-2"
}

variable "project" {
  description = "Project name, used as a prefix/tag on resources"
  type        = string
  default     = "myapp"
}

############################################
# Pre-existing resources (created for you by the lab - do not recreate)
############################################

variable "vpc_id" {
  description = "Existing VPC ID provided by the lab"
  type        = string
  default     = "vpc-048612df325ce3e29"
}

variable "public_subnet_ids" {
  description = "Existing public subnet IDs provided by the lab (one will be used for the web server, based on AZ)"
  type        = list(string)
  default     = [
    "subnet-035d4e36a69985386",
    "subnet-0610d7f45fda55375",
    "subnet-0bafe2f6803bdd531",
    "subnet-09e47bbbcc1ee859c"
  ]
}

############################################
# AZ placement - single-AZ per tier, no HA
############################################

variable "web_az" {
  description = "AZ for the public web server (must match one of the existing public subnets)"
  type        = string
  default     = "us-west-2a"
}

variable "app_az" {
  description = "AZ for the private app server"
  type        = string
  default     = "us-west-2b"
}

variable "db_az" {
  description = "AZ for the private db server"
  type        = string
  default     = "us-west-2c"
}

############################################
# New private subnets we create in the existing VPC
# NOTE: these CIDRs must fall inside the existing VPC's CIDR block
# and must not overlap the two existing public subnets.
# Run: aws ec2 describe-vpcs --vpc-ids vpc-0e1f0d15acc7bdcb5
# and: aws ec2 describe-subnets --filters Name=vpc-id,Values=vpc-0e1f0d15acc7bdcb5
# to confirm before applying, then adjust these defaults if needed.
############################################

variable "app_subnet_cidr" {
  description = "CIDR for the new private app subnet"
  type        = string
  default     = "172.31.101.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR for the new private db subnet"
  type        = string
  default     = "172.31.102.0/24"
}

############################################
# On-prem / VPN
############################################

variable "on_prem_cidr" {
  description = "Full on-prem supernet, routed to over the VPN (into app + db route tables only, never the public one)"
  type        = string
  default     = "10.10.0.0/16"
}

variable "on_prem_full_access_cidr" {
  description = "On-prem subnet allowed to reach the app and db servers directly, but explicitly blocked from web"
  type        = string
  default     = "10.10.30.0/24"
}

variable "on_prem_blocked_host" {
  description = "Single on-prem host explicitly blocked from reaching the web server"
  type        = string
  default     = "10.10.20.201/32"
}

variable "customer_gateway_ip" {
  description = "Public/reachable IP of the on-prem customer gateway"
  type        = string
}

variable "customer_gateway_bgp_asn" {
  description = "BGP ASN for the customer gateway (required by AWS even though we're using static routing)"
  type        = number
  default     = 65000
}

############################################
# Compute
############################################

variable "key_name" {
  description = "Lab-provided EC2 key pair name (find with: aws ec2 describe-key-pairs --query \"KeyPairs[*].KeyName\" --output text)"
  type        = string
}

variable "instance_type" {
  description = "Instance type for all three EC2s - must be one of the lab-allowed types"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size (GB) for each instance - 3 instances x this must stay under the lab's 150GB total cap"
  type        = number
  default     = 20
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the web server from the internet (your admin IP, not 0.0.0.0/0)"
  type        = string
}

variable "app_port" {
  description = "Port the web server uses to reach the app server"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port the app server uses to reach the db server"
  type        = number
  default     = 5432
}
