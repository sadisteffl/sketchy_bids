resource "aws_eip" "nat_eip" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_az1.id

  depends_on = [aws_internet_gateway.gw]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "sketchy_bids" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

}

resource "aws_subnet" "private_az1" {
  vpc_id            = aws_vpc.sketchy_bids.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                                         = "sketchy-bids-private-subnet-az1"
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/sketchy-bids-cluster" = "shared"
  }
}

resource "aws_subnet" "private_az2" {
  vpc_id            = aws_vpc.sketchy_bids.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                                         = "sketchy-bids-private-subnet-az2"
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/sketchy-bids-cluster" = "shared"
  }
}

resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.sketchy_bids.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.sketchy_bids.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.sketchy_bids.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.sketchy_bids.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.sketchy_bids.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_az1" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "db_vm" {
  name        = "db-vm-sg"
  description = "Allow SSH from public and DB traffic from K8s"
  vpc_id      = aws_vpc.sketchy_bids.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH from Internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "allow_k8s_to_db_vm" {
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_vm.id
  source_security_group_id = aws_security_group.k8s_cluster.id
  description              = "Allow MongoDB traffic from K8s"
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb_sg" {
  name        = "sketchy-bids-alb-sg"
  description = "Security group for the Sketchy Bids ALB"
  vpc_id      = aws_vpc.sketchy_bids.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from anywhere"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group_rule" "allow_alb_to_eks_nodes" {
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.k8s_cluster.id
  description              = "Allow traffic from ALB to EKS NodePorts"
}


resource "aws_security_group_rule" "allow_db_vm_to_eks_nodeports" {
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db_vm.id
  security_group_id        = aws_security_group.k8s_cluster.id
  description              = "Allow NodePort traffic from db_vm"
}


resource "aws_security_group" "k8s_cluster" {
  name        = "k8s-cluster-sg"
  description = "Security group for K8s worker nodes"
  vpc_id      = aws_vpc.sketchy_bids.id


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH from Internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "sketchy_bids_alb" {
  name                       = "sketchy-bids-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
  enable_deletion_protection = true
  drop_invalid_header_fields = true
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "sketchy-bids-alb"
    enabled = true
  }
}

resource "aws_lb_target_group" "sketchy_bids_tg" {
  name        = "sketchy-bids-tg"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.sketchy_bids.id
  target_type = "instance"
  health_check {
    protocol            = "HTTP"
    path                = "/health"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.sketchy_bids_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sketchy_bids_tg.arn
  }
}

