data "aws_route53_zone" "domains" {
  for_each = toset(var.domain_names)
  name     = each.value
}


# Create local for all zone IDs
locals {
  all_zone_ids = [for zone in data.aws_route53_zone.domains : zone.zone_id]
}
