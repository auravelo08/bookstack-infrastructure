terraform {
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/82331652/terraform/state/bookstack-infra"
    lock_address   = "https://gitlab.com/api/v4/projects/82331652/terraform/state/bookstack-infra/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/82331652/terraform/state/bookstack-infra/lock"
  }
}
