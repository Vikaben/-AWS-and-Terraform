provider "aws" {
  region  = var.aws_region
}
data "aws_availability_zones" "available" {
     state = "available"
}

#------VPC------#
resource "aws_vpc" "whiskey" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "whiskey"
  }
}


#-----SUBNETS-----#
#-----Private-----#
resource "aws_subnet" "private" {
  count      = length(var.private_subnet)
  vpc_id     = "${aws_vpc.whiskey.id}"
  cidr_block = var.private_subnet[count.index]
  map_public_ip_on_launch = "true"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "whiskey-private-${count.index +1}"
  }
}


#----Public----#
resource "aws_subnet" "public" {
  count   = length(var.public_subnet)
  vpc_id     = "${aws_vpc.whiskey.id}"
  map_public_ip_on_launch = "true"
  cidr_block = var.public_subnet[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "whiskey-private-${count.index +1}"

  }
}



#-----Internet_Gateway-----#
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.whiskey.id}"

  tags = {
    Name = "Internet gateway"
  }
}

#----EIP---#
resource "aws_eip" "eip" {
  count = length(var.public_subnet)
  vpc      = true
}


#-----Public_NAT-----#
resource "aws_nat_gateway" "nat" {
  count         = length(var.public_subnet) 
  allocation_id = aws_eip.eip.*.id[count.index]
  subnet_id     = aws_subnet.public.*.id[count.index]
  

  tags = {
    Name = "gw NAT"
  }
}

#-----Routing-------#
resource "aws_route_table" "route_tables" {
  count  = length(var.route_tables_names)
  vpc_id = aws_vpc.whiskey.id

  tags = {
    "Name" = "route table"
  }
}

##Association
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet)
  subnet_id      = aws_subnet.public.*.id[count.index]
  route_table_id = aws_route_table.route_tables[0].id
}
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet)
  subnet_id      = aws_subnet.private.*.id[count.index]
  route_table_id = aws_route_table.route_tables[count.index + 1].id
}




#-----Security_Groups-----#
##For Web
resource "aws_security_group" "web-instances-access" {
  vpc_id = aws_vpc.whiskey.id
  name   = "web-access"

  tags = {
    "Name" = "web-access"
  }
}
resource "aws_security_group_rule" "ssh"{
    description = "allow ssh traffic"
    security_group_id = aws_security_group.web-instances-access.id
    type  = "ingress"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
resource "aws_security_group_rule" "http"{
     description = "allow http traffic"
     security_group_id = aws_security_group.web-instances-access.id
     type  = "ingress"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
resource "aws_security_group_rule" "outbound"{
    description = "allow outbound traffic"
    security_group_id = aws_security_group.web-instances-access.id
    type              = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }



##For DB
resource "aws_security_group" "ssh-only"{
    name = "ssh-only"
    vpc_id = aws_vpc.whiskey.id
    description = "allow ssh traffic"
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


#-----Instances-------#
##WEB
resource "aws_instance" "web-server"{
  ami                         = "ami-033b95fb8079dc481"
  instance_type               = "t3.micro"
  count = 2
  availability_zone           = data.aws_availability_zones.available.names[count.index]
  subnet_id                   = aws_subnet.public.*.id[count.index]
  associate_public_ip_address = true
  security_groups = ["${aws_security_group.web-instances-access.id}"]
  key_name = "whiskey"
    user_data = <<-EOF
  #! /bin/bash
    sudo amazon-linux-extras install nginx1
    sudo systemctl enable nginx
    sudo systemctl start nginx#
    echo "<h1>Welcome to Grandpa's Whiskey</h1>" >> /usr/share/nginx/html/index.html
EOF
 
    tags = {
        Terraform   = "true"
        Name = "whiskey-web-${count.index +1}"
        Owner = "grandpa"
        purpose = "web Server"
  }
}


##DB
resource "aws_instance" "DB-server"{
  ami                         = "ami-033b95fb8079dc481"
  instance_type               = "t3.micro"
  count = 2
  availability_zone           = data.aws_availability_zones.available.names[count.index]
  subnet_id                   = aws_subnet.private.*.id[count.index]
  security_groups = ["${aws_security_group.ssh-only.id}"]
  associate_public_ip_address = false
  key_name = "whiskey"

    tags = {
        Terraform   = "true"
        Name = "whiskey-DB-${count.index +1}"
        Owner = "grandpa"
        purpose = "DB Server"
  }
}



#---------ALB--------#
resource "aws_lb" "web" {
  name                       = "alb-${aws_vpc.whiskey.id}"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = aws_subnet.public.*.id
  security_groups            = [aws_security_group.web-instances-access.id]

  tags = {
    "Name" = "ALB"
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_target_group" "web" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.whiskey.id

  health_check {
    enabled = true
    path    = "/"
  }

  tags = {
    "Name" = "web target group"
  }
}

resource "aws_lb_target_group_attachment" "web_server" {
  count            = length(aws_instance.web-server)
  target_group_arn = aws_lb_target_group.web.id
  target_id        = aws_instance.web-server.*.id[count.index]
  port             = 80
}