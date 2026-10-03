# Random suffix so the bucket name is globally unique without exposing the account ID
resource "random_id" "suffix" {
  byte_length = 4
}
