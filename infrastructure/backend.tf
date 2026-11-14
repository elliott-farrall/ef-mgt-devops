terraform {
  # Deliberately partial backend: organization and workspace are supplied at
  # init during bootstrap (bootstrap/04-import.sh) and inferred from
  # the VCS connection for all TFC runs.
  backend "remote" {}
}
