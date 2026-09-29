# The edge, emulated honestly: ELBv2 (load balancer) is a LocalStack Pro
# feature, so the free-tier stack cannot create an ALB. What the community
# edition DOES exercise is the Route53 wiring and the security-group posture;
# the load balancer and listener are the one piece to add when this config
# runs against a real account (a standard aws_lb + target_group + listener
# block, six lines).
#
# The record below is a placeholder target for that reason: it proves the
# zone + record path Terraform drives. On real AWS the alias points at the ALB.
resource "aws_route53_zone" "app" {
  name = "askvault.pvt"
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.app.zone_id
  name    = "askvault"
  type    = "A"
  ttl     = 300
  records = ["10.9.9.9"]
}