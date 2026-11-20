locals {
  kind = var.scope == "" ? "" : element(split("/", var.scope), 0)
}
