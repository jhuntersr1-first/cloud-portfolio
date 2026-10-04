variable "environment" {
  description = "Which environment this stack builds"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "zone_name" {
  description = "The registered domain whose Route 53 hosted zone holds this environment's records"
  type        = string
}

variable "domain_names" {
  description = "Names this environment answers to; the first is the certificate's main name"
  type        = list(string)

  validation {
    condition     = length(var.domain_names) > 0
    error_message = "domain_names needs at least one name."
  }

  validation {
    condition     = alltrue([for name in var.domain_names : name == var.zone_name || endswith(name, ".${var.zone_name}")])
    error_message = "Every domain name must be the zone itself or a subdomain of it."
  }
}
