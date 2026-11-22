terraform {
  backend "remote" {
    workspaces {
      name = "ef-mgt-devops"
    }
  }
}
