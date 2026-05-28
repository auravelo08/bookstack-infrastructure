#!/bin/bash

# Configuration synchronisée avec ton main.tf
DB_HOST="mon-rds-testdebdd.czc4ooi4cx9u.eu-west-3.rds.amazonaws.com" # TON VRAI ENDPOINT RDS
DB_NAME="test_bdd"
DB_USER="dbadmin"
export PGPASSWORD="bookstack" # Mot de passe de ta base rds

BUCKET_NAME="mon-unique-bucket-testdebdd-dumps" # Le nom exact de ton bucket S3
REGION="eu-west-3"

# Génération du nom de fichier unique avec date et heure
TIMESTAMP=$(date +%Y-%m-%d-%H-%M)
FILENAME="dump-${DB_NAME}-${TIMESTAMP}.sql.gz"
LOCAL_PATH="/tmp/${FILENAME}"
LOG_FILE="/var/log/rds_dump.log"

echo "[$(date)] Début du dump de la base ${DB_NAME}..." >> $LOG_FILE

# 1. Réalisation du Dump SQL compressé à la volée
pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" | gzip > "$LOCAL_PATH"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "[$(date)] Dump réussi localement dans ${LOCAL_PATH}. Envoi vers S3..." >> $LOG_FILE
    
    # 2. Copie du fichier compressé vers le Bucket S3
    aws s3 cp "$LOCAL_PATH" "s3://${BUCKET_NAME}/${FILENAME}" --region "$REGION" >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
        echo "[$(date)] Succès : Fichier ${FILENAME} sauvegardé sur S3." >> $LOG_FILE
    else
        echo "[$(date)] ERREUR : Échec de l'envoi vers S3." >> $LOG_FILE
    fi
    
    # 3. Nettoyage du fichier temporaire sur le disque de l'EC2
    rm -f "$LOCAL_PATH"
else
    echo "[$(date)] ERREUR : Échec du pg_dump." >> $LOG_FILE
    rm -f "$LOCAL_PATH"
fi