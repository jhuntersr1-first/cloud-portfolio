variable "account_id" {
  description = "AWS account ID (kept out of the repo via terraform.tfvars)"
  type        = string
}

variable "prod_site_bucket_name" {
  description = "Name of the prod site bucket the content-deploy role may write to"
  type        = string
}

variable "prod_distribution_id" {
  description = "ID of the prod CloudFront distribution the content-deploy role may refresh"
  type        = string
}
