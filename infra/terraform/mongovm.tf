
resource "aws_instance" "mongodb_server" {
  ami           = "ami-0073ec6a03faffa4c"
  instance_type = var.instance_type

  subnet_id              = aws_subnet.public_az1.id
  vpc_security_group_ids = [aws_security_group.db_vm.id]
  iam_instance_profile   = aws_iam_instance_profile.mongodb_instance_profile.name
  key_name               = "mongodb"
  monitoring             = true
  ebs_optimized          = true

  user_data = templatefile("${path.module}/user_data.sh", {
    db_user                = var.db_user
    s3_bucket_name         = aws_s3_bucket.sketchy_bids_mongodb_backup.bucket
    mongo_admin_secret_arn = aws_secretsmanager_secret.mongodb_admin_credentials.arn
    mongo_user_secret_arn  = aws_secretsmanager_secret.mongodb_app_user_credentials.arn
  })

  root_block_device {
    encrypted  = true
    kms_key_id = aws_kms_key.mainkey.arn
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # It's good practice to add tags
  tags = {
    Name = "mongodb-server"
  }
}



resource "random_password" "mongodb_admin_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "mongodb_admin_credentials" {
  name              = "sketchybids-mongodb-admin"
    kms_key_id = aws_kms_key.mainkms.arn
}

resource "aws_secretsmanager_secret_version" "mongodb_admin_credentials_version" {
  secret_id     = aws_secretsmanager_secret.mongodb_admin_credentials.id
  secret_string = random_password.mongodb_admin_password.result
}


resource "random_password" "mongodb_app_user_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "mongodb_app_user_credentials" {
  name              = "sketchybids-mongodb-app-user"
    kms_key_id = aws_kms_key.mainkms.arn
}

resource "aws_secretsmanager_secret_version" "mongodb_app_user_credentials_version" {
  secret_id     = aws_secretsmanager_secret.mongodb_app_user_credentials.id
  secret_string = random_password.mongodb_app_user_password.result
}

resource "aws_secretsmanager_secret" "sketchybidsbackendcredentials" {
  name              = "sketchybidsbackendcredentials"
    kms_key_id = aws_kms_key.mainkms.arn
  }

resource "aws_secretsmanager_secret_version" "backend_app_db_secret_version" {
  secret_id = aws_secretsmanager_secret.sketchybidsbackendcredentials.id
  secret_string = jsonencode({
    DB_USER = var.db_user
    DB_PASS = random_password.mongodb_app_user_password.result
  })
}



resource "aws_iam_role" "mongodb_instance_role_overly_permissive" {
  name = "mongodb-vm-overly-permissive-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mongodb_instance_admin_attachment" {
  role       = aws_iam_role.mongodb_instance_role_overly_permissive.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "mongodb_instance_profile" {
  name = "mongodb-instance-profile"
  role = aws_iam_role.mongodb_instance_role_overly_permissive.name
}