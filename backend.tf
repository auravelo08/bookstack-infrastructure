terraform {
  backend "gitlab" {
    project = "BookStack/Bookstack Infrastructure" # Nom complet avec le groupe
    path    = "bastion"
  }
}