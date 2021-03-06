provider "aws" {
    region = "us-east-2"
    profile = "Administrator"
}


data "aws_availability_zones" "all" {

}

resource "aws_security_group" "instance"{
    name = "terraform-example-instance"


    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_launch_configuration" "example"{
    image_id = "ami-0c55b159cbfafe1f0"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instance.id]
    user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_autoscaling_group" "example"{
    launch_configuration = aws_launch_configuration.example.id
    availability_zones = data.aws_availability_zones.all.names
    load_balancers = [aws_elb.example.name]
    health_check_type = "ELB"
    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
    }

}


resource "aws_security_group" "elb_sg" {
    name = "terraform-example-elb-sg"
    #Allow all outbound
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


resource "aws_elb" "example" {
    name = "terraform-asg-elb-example"
    availability_zones = data.aws_availability_zones.all.names
    security_groups = [aws_security_group.elb_sg.id]
    # This adds a listener for incoming HTTP requests.

    health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

    listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = var.server_port
        instance_protocol = "http"
    }
}


terraform {
    backend "s3" {
        bucket = "terraform-up-and-running-state-4567"
        key = "global/s3/terraform.tfstate"
        region = "us-east-2"

        #DynamoDB table name!
        dynamodb_table = "terraform-up-and-running-locks"
        encrypt        = true
    }
}



