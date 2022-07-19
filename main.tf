# I am creating a 3 tier architecture with a Load balancer and A public subnet which contains the frontend application 
#in the amazon linux server and a private subnet which contains the backend postgres RDS instance.





provider "aws" {
  region = "us-east-1"
  secret_key = "xxxxx6lzKIJ0R"
  access_key = "xxxxLJMR7PO"
}


resource "aws_vpc" "testvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Test-VPC"
  }
}


resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.testvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  

  tags = {
    Name = "public-subnet-1"
  }
}


resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.testvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet-1"
  }
}


resource "aws_internet_gateway" "testigw" {
  vpc_id = aws_vpc.testvpc.id

  tags = {
    Name = "test-igw"
  }
}


resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.testvpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.testigw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Create Web Subnet association with Web route table
resource "aws_route_table_association" "pub_route_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.routetable.id
}

resource "aws_route_table_association" "private_route_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.routetable.id
}

#Create EC2 Instance
resource "aws_instance" "frontend" {
  ami                    = "ami-02d1e544b84bf7502"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  subnet_id              = aws_subnet.public_subnet.id
 

  tags = {
    Name = "frontend"
  }

}






resource "aws_security_group" "frontend_sg" {
  name        = "frontend-SG"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.testvpc.id

  ingress {
    
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    
  }

  ingress {
    
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    
  }
  ingress {
    
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "frontend-SG"
  }
}


resource "aws_security_group" "backend_sg" {
  name        = "backend-SG"
  description = "Allow inbound traffic from application layer"
  vpc_id      = aws_vpc.testvpc.id

  ingress {
    description     = "Allow traffic from application layer"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-SG"
  }
}

resource "aws_lb" "elb" {
  name               = "frontend-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_sg.id]
  subnets            = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]
}

resource "aws_lb_target_group" "elb_tg" {
  name     = "ELB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.testvpc.id
}

resource "aws_lb_target_group_attachment" "elb_tg" {
  target_group_arn = aws_lb_target_group.elb_tg.arn
  target_id        = aws_instance.frontend.id
  port             = 80

  depends_on = [
    aws_instance.frontend,
  ]
}



resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.elb_tg.arn
  }
}

resource "aws_db_instance" "default" {
 
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "10.17"
  username               = "test"
  password               = "12345678"
  db_subnet_group_name   = aws_db_subnet_group.testing.name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

resource "aws_db_subnet_group" "testing" {
  name       = "testing"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.public_subnet.id]

  tags = {
    Name = "db-subnet-group"
  }
}

