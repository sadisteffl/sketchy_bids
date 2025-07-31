resource "aws_ecr_repository" "sketchy_bids_frontend_app" {
  name                 = "sketchy-bids-frontend-app"
  image_tag_mutability = "IMMUTABLE"
      encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.mainkms.arn
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "sketchy_bids_backend_app" {
  name                 = "sketchy-bids-backend-app"
  image_tag_mutability = "IMMUTABLE"
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.mainkms.arn
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id            = aws_vpc.sketchy_bids.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}

resource "aws_vpc_endpoint" "ecr_api_endpoint" {
  vpc_id              = aws_vpc.sketchy_bids.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
  security_group_ids  = [aws_security_group.k8s_cluster.id]
}

resource "aws_vpc_endpoint" "ecr_dkr_endpoint" {
  vpc_id              = aws_vpc.sketchy_bids.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
  security_group_ids  = [aws_security_group.k8s_cluster.id] #
}


