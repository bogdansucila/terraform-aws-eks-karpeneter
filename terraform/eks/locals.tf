locals {
  cluster_name = "${var.environment}-${var.project}-eks"

  tags = {
    Project     = var.project
    Environment = var.environment
    Region      = var.region
  }
}