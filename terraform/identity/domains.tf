# The domain's DNS "phone book" (created automatically when the domain was registered)
data "aws_route53_zone" "site" {
  name = var.zone_name
}
