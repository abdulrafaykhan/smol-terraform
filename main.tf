provider "aws" {
  region = "us-east-1"
}

# Getting the data of the Availability Zones
data "aws_availability_zones" "all" {}

resource "aws_security_group" "instance" {
    name = "terraform-webserver-instance"

    ingress {
    description      = "TLS from VPC"
    from_port        = var.server_port
    to_port          = var.server_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

## Creating the launch config for the ASG 
resource "aws_launch_configuration" "example" {
  image_id = "ami-052efd3df9dad4825"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  lifecycle {
    # This will create the replacement first and then destroy the old one
    create_before_destroy = true
  }
}

# Creating the ASG
resource "aws_autoscaling_group" "my-autoscaling-group" {
  
  launch_configuration = aws_launch_configuration.example.id
  availability_zones = data.aws_availability_zones.all.names

  min_size = 3
  max_size = 5

  load_balancers = [aws_elb.myelb.name]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "Terraform-ASG-Example"
    propagate_at_launch = true
  }

}

# We're using a CLB for now (UPDATE LATER PLS!! )
resource "aws_elb" "myelb" {
  name = "My-ELB"
  security_groups = [aws_security_group.elbsecgroup.id]
  availability_zones = data.aws_availability_zones.all.names

  # Adding the Health Checks
  health_check {
    target = "HTTP:${var.server_port}/"
    interval = 30
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

  # Adding a listener to the incoming HTTP requests
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = var.server_port
    instance_protocol = "http"
  }

}

# Creating a resource group for ELB
resource "aws_security_group" "elbsecgroup" {
  name = "My-ELB-SecGroup"

  # Allowing all outbound
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from anywhere
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
