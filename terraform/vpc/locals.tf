locals {
  vpc_name = "${var.environment}-${var.project}-vpc"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Project     = var.project
    Environment = var.environment
    Region      = var.region
  }
}