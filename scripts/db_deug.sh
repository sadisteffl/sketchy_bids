#!/bin/bash

# This command makes the script print every command it runs
set -x

# --- Define Variables ---
BACKUP_NAME="backup1"
BACKUP_DIR="/tmp/${BACKUP_NAME}"
BACKUP_ARCHIVE="/tmp/${BACKUP_NAME}.tar.gz"
SECRET_ID="sketchybids/mongodb/admin"

# --- 1. Get Password ---
echo "INFO: Getting password from Secrets Manager..."
ADMIN_PASS=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query SecretString --output text)
if [ -z "$ADMIN_PASS" ]; then
    echo "ERROR: Failed to retrieve password from secret '$SECRET_ID'."
    exit 1
fi

# --- 2. Create Database Dump ---
echo "INFO: Running mongodump..."
mongodump --username "admin" --password "$ADMIN_PASS" --authenticationDatabase "admin" --out "$BACKUP_DIR"

# --- 3. Verify Dump ---
if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR)" ]; then
    echo "ERROR: mongodump failed. The backup directory '$BACKUP_DIR' is missing or empty."
    exit 1
fi
echo "INFO: mongodump successful. Backup directory created."

# --- 4. Archive the Backup ---
echo "INFO: Creating tar archive..."
tar -czvf "$BACKUP_ARCHIVE" -C /tmp "$BACKUP_NAME"

# --- 5. Find S3 Bucket ---
echo "INFO: Searching for S3 bucket..."
S3_BUCKET_NAME=$(aws s3 ls | grep 'sketchy-bids-mongodb-backup' | awk '{print $3}')
if [ -z "$S3_BUCKET_NAME" ]; then
    echo "ERROR: Could not find an S3 bucket with 'sketchy-bids-mongodb-backup' in the name."
    exit 1
fi
echo "INFO: Found S3 Bucket: $S3_BUCKET_NAME"

# --- 6. Upload to S3 ---
echo "INFO: Uploading '$BACKUP_ARCHIVE' to 's3://${S3_BUCKET_NAME}/backups/'..."
aws s3 cp "$BACKUP_ARCHIVE" "s3://${S3_BUCKET_NAME}/backups/${BACKUP_NAME}.tar.gz"

# --- 7. Clean Up ---
echo "INFO: Cleaning up local files..."
rm -rf "$BACKUP_DIR" "$BACKUP_ARCHIVE"

# Stop printing commands
set +x

echo "✅ Script finished."