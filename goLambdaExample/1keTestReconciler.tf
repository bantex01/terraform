provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "oneke-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
	Name = "oneke-vpc"
  }
}

resource "aws_subnet" "oneke-private-1" {
  vpc_id = aws_vpc.oneke-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  tags = {
	Name = "oneke-subnet-private1"
  }
}

resource "aws_subnet" "oneke-private-2" {
  vpc_id = aws_vpc.oneke-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"
  tags = {
        Name = "oneke-subnet-private2"
  }
}

resource "aws_subnet" "oneke-public" {
  vpc_id = aws_vpc.oneke-vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-west-2a"
  tags = {
        Name = "oneke-subnet-public"
  }
}

resource "aws_internet_gateway" "oneke-igw" {
  vpc_id = aws_vpc.oneke-vpc.id
  tags = {
    Name = "oneke-igw"
  }
}

resource "aws_eip" "oneke-eip" {
  vpc = "true"
}

resource "aws_nat_gateway" "oneke-natgw" {
  subnet_id = aws_subnet.oneke-public.id
  allocation_id = aws_eip.oneke-eip.id
  tags = {
	Name = "oneke-natgw"
  }
}

resource "aws_route_table" "oneke-public-rt" {
  vpc_id = aws_vpc.oneke-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.oneke-igw.id
  }
  tags = {
    Name = "oneke-public-rt"
  }
}

resource "aws_route_table_association" "oneke-public-rt" {
  subnet_id      = aws_subnet.oneke-public.id
  route_table_id = aws_route_table.oneke-public-rt.id
}

resource "aws_route_table" "oneke-private-rt" {
  vpc_id = aws_vpc.oneke-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.oneke-natgw.id
  }
  tags = {
    Name = "oneke-private-rt"
  }
}

resource "aws_route_table_association" "oneke-private1-rt" {
  subnet_id      = aws_subnet.oneke-private-1.id
  route_table_id = aws_route_table.oneke-private-rt.id
}

resource "aws_route_table_association" "oneke-private2-rt" {
  subnet_id      = aws_subnet.oneke-private-2.id
  route_table_id = aws_route_table.oneke-private-rt.id
}

resource "aws_iam_role" "oneke-role" {
  name = "oneke-role"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "attach-secrets-manager-2-role" {
  role      = aws_iam_role.oneke-role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "attach-s3access-2-role" {
  role      = aws_iam_role.oneke-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "attach-lambda-basic-execution-2-role" {
  role      = aws_iam_role.oneke-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "attach-lambda-vpc-access-2-role" {
  role      = aws_iam_role.oneke-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_security_group" "selected" {
  vpc_id = aws_vpc.oneke-vpc.id
  name = "default"
}

resource "aws_lambda_function" "oneke-lambda" {
  filename = "lambda/1keTestReconciler.zip"
  function_name = "onekeTestReconciler"
  role = aws_iam_role.oneke-role.arn
  handler = "1keTestReconciler"
  source_code_hash = filebase64sha256("lambda/1keTestReconciler.zip")
  runtime = "go1.x"
  timeout = "15"
  memory_size = "512"
  vpc_config {
	subnet_ids = [aws_subnet.oneke-private-1.id,aws_subnet.oneke-private-2.id]
	security_group_ids = [data.aws_security_group.selected.id]
  }
  environment {
	variables = {
		SOME_AUTH_TOKEN = "some_token"
		SOME_SEND_TIMEOUT_SECONDS	 = "5"
	}
  }
}

resource "aws_lambda_permission" "oneke-allow-bucket-notification" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name =  aws_lambda_function.oneke-lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::cloud-dev-terraform-state"
}

resource "aws_s3_bucket_notification" "oneke-bucket-notification" {
  bucket = "cloud-dev-terraform-state"

  lambda_function {
    lambda_function_arn = aws_lambda_function.oneke-lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "stacks/dev/"
    filter_suffix       = ".tfstate"
  }
}

resource "aws_secretsmanager_secret" "oneke-secret" {
  name                = "oneke-api"
  description = "User and token to access Thousand Eyes API"
}

variable "oneke-kv" {
  default = {
    "somebdody@somewhere.com" = "some_token"
  }

  type = "map"
}

resource "aws_secretsmanager_secret_version" "oneke-secret-kv" {
  secret_id     = aws_secretsmanager_secret.oneke-secret.id
  secret_string = "${jsonencode(var.oneke-kv)}"
}
