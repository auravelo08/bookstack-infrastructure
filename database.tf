resource "postgresql_database" "bookstack_staging" {
  name = "bookstack_staging"
}

resource "postgresql_database" "bookstack_production" {
  name = "bookstack_production"
}

resource "postgresql_database" "keycloak_staging" {
  name = "keycloak_staging"
}

resource "postgresql_database" "keycloak_production" {
  name = "keycloak_production"
}
