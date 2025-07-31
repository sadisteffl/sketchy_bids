
resource "aws_security_group" "bastion_sg" {
  name        = "sketchy-bids-bastion-sg"
  description = "Allow SSH access to the bastion host"
  vpc_id      = aws_vpc.sketchy_bids.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["69.216.110.193/32"]
    description = "Allow SSH from Sadis IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # "-1" means all protocols
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

resource "aws_instance" "bastion_host" {
  ami           = "ami-08a6efd148b1f7504"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_az1.id

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  key_name = "mongo"
    ebs_optimized = true
  monitoring    = true

  root_block_device {
    encrypted  = true
    kms_key_id = aws_kms_key.mainkey.arn
  }
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

}

resource "aws_security_group_rule" "allow_bastion_to_eks_control_plane" {
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  security_group_id        = aws_eks_cluster.sketchy_bids_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.bastion_sg.id
  description              = "Allow kubectl from bastion to EKS control plane"
}