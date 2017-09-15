##
### TERRAFORM VERSION
##
terraform {
  required_version = ">= 0.8.7"
}


##
### PROVIDER SETTINGS
##
#variable "aws_access_key" { type = "string" }
#variable "aws_secret_key" { type = "string" }
variable "region"         { type = "string" }
variable "azs"            { type = "list"   }

provider "aws" {
#	access_key = "${var.aws_access_key}"
#	secret_key = "${var.aws_secret_key}"
	region     = "${var.region}"
}



##
### NETWORKING
##
variable "vpc_cidr" { type = "string" }

resource "aws_vpc" "hashi-vpc" {
	cidr_block = "${var.vpc_cidr}"
	tags {
		Name = "hashi-vpc"
	}
}

resource "aws_network_acl" "hashi-nacl" {
	vpc_id = "${aws_vpc.hashi-vpc.id}"
	egress {
		protocol = "-1"
		rule_no = 100
		action = "allow"
		cidr_block =  "0.0.0.0/0"
		from_port = 0
		to_port = 0
	}
	ingress {
		protocol = "-1"
		rule_no = 100
		action = "allow"
		cidr_block =  "0.0.0.0/0"
		from_port = 0
		to_port = 0
	}
	tags {
		Name = "hashi-nacl"
	}
}

resource "aws_internet_gateway" "hashi-igw" {
	vpc_id = "${aws_vpc.hashi-vpc.id}"
	tags {
		Name = "hashi-igw"
	}
}

resource "aws_subnet" "hashi-subnet" {
	count                   = "${length(var.azs)}"
	vpc_id                  = "${aws_vpc.hashi-vpc.id}"
	availability_zone       = "${var.region}${element(var.azs, count.index)}"
	cidr_block              = "${cidrsubnet(aws_vpc.hashi-vpc.cidr_block, length(var.azs), count.index)}"
	map_public_ip_on_launch = true
	tags {
		Name                = "hashi-subnet-${count.index}"
	}
	depends_on              = ["aws_internet_gateway.hashi-igw"]
}

resource "aws_route_table" "hashi-route-table" {
	vpc_id = "${aws_vpc.hashi-vpc.id}"
	route {
		cidr_block     = "0.0.0.0/0"
		gateway_id     = "${aws_internet_gateway.hashi-igw.id}"
	}
#	route {
#		cidr_block     = "0.0.0.0/0"
#		nat_gateway_id = "${aws_nat_gateway.hashi-nat.id}"
#	}
	tags {
		Name = "hashi-route-table"
	}
}

resource "aws_route_table_association" "hashi-rtassoc" {
	count          = "${length(var.azs)}"
	subnet_id      = "${element(aws_subnet.hashi-subnet.*.id, count.index)}"
	route_table_id = "${aws_route_table.hashi-route-table.id}"
}

resource "aws_default_security_group" "hashi-defaultsg" {
	vpc_id = "${aws_vpc.hashi-vpc.id}"
	ingress {
		protocol  = -1
		#self      = true
		cidr_blocks = ["0.0.0.0/0"]
		from_port = 0
		to_port   = 0
	}
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags {
		Name = "hashi-defaultsg"
	}
}



##
### TOOLS
##
#variable "tools"           { type = "list"   }
variable "instance_type"   { type = "string" }
variable "ssh_key_public"  { type = "string" }
variable "ssh_key_private" { type = "string" }

data "aws_ami" "amazonlinux" {
	most_recent   = true
	owners        = ["amazon"]
	filter {
		name    = "architecture"
		values  = ["x86_64"]
	}
	filter {
		name    = "virtualization-type"
		values  = ["hvm"]
	}
	filter {
		name    = "name"
		values  = ["amzn-ami-hvm*"]
	}
	filter {
		name    = "description"
		values  = ["*GP2"]
	}
}

resource "aws_key_pair" "hashi-key" {
	key_name = "hashi-key"
	public_key = "${file("${var.ssh_key_public}")}"
}

resource "aws_instance" "hashi-instance" {
	count         = 1
	ami           = "${data.aws_ami.amazonlinux.id}"
	instance_type = "${var.instance_type}"
	key_name      = "${aws_key_pair.hashi-key.key_name}"
	#subnet_id     = "${element(aws_subnet.hashi-subnet.*.id, count.index % length(var.tools))}"
	subnet_id     = "${aws_subnet.hashi-subnet.0.id}"
	provisioner "remote-exec" {
		inline = [
			"sudo mkdir -p /hashiboot",
			"sudo chmod 0777 /hashiboot"
		]
		connection {
			type = "ssh"
			user = "ec2-user"
			private_key = "${file("${var.ssh_key_private}")}"
			timeout = "3m"
			agent = false
		}
	}
	provisioner "file" {
		source      = "./install_scripts/"
		destination = "/hashiboot"
		connection {
			type = "ssh"
			user = "ec2-user"
			private_key = "${file("${var.ssh_key_private}")}"
			timeout = "3m"
			agent = false
		}
	}
	provisioner "remote-exec" {
		inline = [
			"sudo chmod -R +x /hashiboot",
			"sudo /hashiboot/install.sh vault.server",
			#"sudo rm -rf /hashiboot"
		]
		connection {
			type = "ssh"
			user = "ec2-user"
			private_key = "${file("${var.ssh_key_private}")}"
			timeout = "3m"
			agent = false
		}
	}
	tags {
		Name = "hashi-vault-${count.index}"
	}
	depends_on = ["aws_key_pair.hashi-key"]
}


##
### Database
##
variable "db_name" { type = "string" }
variable "db_user" { type = "string" }
variable "db_pass" { type = "string" }
variable "db_instance_type" { type = "string" }

resource "aws_db_subnet_group" "HashiDBSubnetGroup" {
  name       = "main"
  subnet_ids = ["${aws_subnet.hashi-subnet.0.id}", "${aws_subnet.hashi-subnet.1.id}"]

  tags {
    Name = "HashiDBSubnetGroup"
  }
}

resource "aws_db_instance" "mydb" {
  allocated_storage    = 5
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "9.6.2"
  instance_class       = "${var.db_instance_type}"
  name                 = "${var.db_name}"
  username             = "${var.db_user}"
  password             = "${var.db_pass}"
  db_subnet_group_name = "${aws_db_subnet_group.HashiDBSubnetGroup.id}"
  skip_final_snapshot  = "true"
  #parameter_group_name = "default.mysql5.6"
}

## Outputs
output "SSH Command" {
	value = "ssh ec2-user@${aws_instance.hashi-instance.public_ip} -i ${var.ssh_key_private}"
}
output "Vault DB Connection String" {
	value = "postgresql://${var.db_user}:${var.db_pass}@${aws_db_instance.mydb.address}:5432/${var.db_name}"
}