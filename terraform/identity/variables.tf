variable "zone_name" {
  description = "The registered domain whose Route 53 hosted zone holds every environment's records"
  type        = string
}

variable "env_domains" {
  description = "Names each environment's pipeline may manage certificates and DNS records for"
  type        = map(list(string))

  validation {
    condition     = toset(keys(var.env_domains)) == toset(["dev", "test", "prod"])
    error_message = "env_domains must have exactly the keys dev, test, and prod."
  }

  validation {
    condition = alltrue(flatten([
      for env, names in var.env_domains : [
        for name in names : name == var.zone_name || endswith(name, ".${var.zone_name}")
      ]
    ]))
    error_message = "Every domain name must be the zone itself or a subdomain of it."
  }
}
