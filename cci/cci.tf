provider "aws" {
  version = "~> 2.0"
  region = "ap-south-1"
}

resource "aws_vpc" "concourse" {
  cidr_block       = "10.91.0.0/16"
  instance_tenancy = "default"

  tags = {
    managed = "terraform"
    ou = "devops"
    purpose = "ci"
  }
}

resource "aws_internet_gateway" "concourse" {
  vpc_id = "aws_vpc.concourse.id"

  tags = {
    managed = "terraform"
    ou = "devops"
    purpose = "ci"
  }
}

resource "aws_route_table" "public" {

  vpc_id = "aws_vpc.concourse.id"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "aws_internet_gateway.cf_test.id"
  }
}

resource "aws_subnet" "ext1" {
  vpc_id     = "aws_vpc.concourse.id"
  cidr_block = "cidrsubnet(var.vpc_cidr, 8, 1)"
  map_public_ip_on_launch = "true"
  availability_zone = "element(data.aws_availability_zones.available.names, 1)"

  tags = {
    managed = "terraform"
    ou = "devops"
    purpose = "ci"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id = "aws_subnet.ext1.id"
  route_table_id = "aws_route_table.public.id"
}

resource "aws_instance" "master" {
  ami = "data.aws_ami.al2_ecs.id"
  instance_type = "t3.micro"

  tags = {
    managed = "terraform"
    ou = "devops"
    purpose = "ci"
  }
}

# This is used to ensure that all the ELB subnets are in different AZs
data "aws_availability_zones" "available" {}

data "aws_ami" "al2_ecs" {
  most_recent = true
  owners = [ "amazon" ]
  filter {
    name = "name"
    values = [ "amzn2-ami-ecs-hvm-2.0*" ]
  }
  filter {
    name = "architecture"
    values = [ "x86_64" ]
  }
  filter {
    name = "root-device-type"
    values = [ "ebs" ]
  }
  filter {
    name = "virtualization-type"
    values = [ "hvm" ]
  }
}
