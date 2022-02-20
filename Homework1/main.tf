
provider "aws" {
    region =  "us-west-1"
}
resource "aws_security_group" "ssh-http"{
    name = "ssh-http"
    description = "allowing ssh and http traffic"
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
     ingress {
        from_port = 80
        to_port = 80
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


resource "aws_instance" "whiskey"{
  ami                         = "ami-0573b70afecda915d"
  instance_type               = "t3.micro"
  count = 2
  availability_zone           = "us-west-1c"
  security_groups = ["${aws_security_group.ssh-http.name}"]
  key_name = "whiskey"
    user_data = <<-EOF
  #! /bin/bash
    sudo amazon-linux-extras install nginx1
    sudo systemctl enable nginx
    sudo systemctl start nginx
    echo "<h1>Welcome to Grandpa's Whiskey</h1>" >> /usr/share/nginx/html/index.html
EOF
 
    tags = {
        Terraform   = "true"
        Name = "whiskey-web-${count.index +1}"
        Owner = "grandpa"
        purpose = "webderver"
  }
}

resource "aws_ebs_volume" "whiskey-vol" {
    count = "${length(aws_instance.whiskey)}"
    availability_zone = "us-west-1c"
    size              = 10
    encrypted         = "true"
  
  }

resource "aws_volume_attachment" "whiskey" {
  device_name = "/dev/sdh"
  count = "${length(aws_instance.whiskey)}"
  volume_id   = "${aws_ebs_volume.whiskey-vol.*.id[count.index]}"
  instance_id = "${aws_instance.whiskey.*.id[count.index]}"
}
