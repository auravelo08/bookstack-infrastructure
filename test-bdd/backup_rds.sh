#!/bin/bash

# Configuration à partir de ton main.tf
DB_IDENTIFIER="mon-rds-testdebdd"
REGION="eu-west-3"

# Génération d'un nom de snapshot unique (Ex: snapshot-mon-rds-testdebdd-2026-05-25-14-10)
TIMESTAMP=$(date +%Y-%m-%d-%H-%M)
SNAPSHOT_ID="snapshot-${DB_IDENTIFIER}-${TIMESTAMP}"

# Fichier de logs pour le suivi de la tâche Cron
LOG_FILE="/var/log/rds_snapshot.log"

echo "[$(date)] Début de la création du snapshot pour ${DB_IDENTIFIER}..." >> $LOG_FILE

# Appel de l'API AWS via le CLI
# L'authentification se fait de manière transparente grâce au rôle IAM de l'EC2
aws rds create-db-snapshot \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --region "$REGION" >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
    echo "[$(date)] Succès : Demande de création du snapshot '${SNAPSHOT_ID}' envoyée." >> $LOG_FILE
else
    echo "[$(date)] ERREUR : Échec de l'envoi de la demande de snapshot." >> $LOG_FILE
fi