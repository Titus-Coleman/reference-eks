data "aws_route53_zone" "tituscoleman_dev" {
  name = "tituscoleman.dev."
}

# Local values for zone management
locals {
  # Include your tituscoleman.dev zone
  all_zone_ids = [
    data.aws_route53_zone.tituscoleman_dev.zone_id
    # Add other zones as needed
  ]

  # Zone mapping for easier reference
  zone_map = {
    "tituscoleman.dev" = data.aws_route53_zone.tituscoleman_dev.zone_id
  }
}
