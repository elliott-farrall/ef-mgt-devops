# Terraform Cloud remote backend. Deliberately partial: organization and
# workspace are supplied at init during bootstrap (scripts/bootstrap/04-import.sh)
# and inferred from the VCS connection for all TFC runs.
terraform {
  backend "remote" {}
}
