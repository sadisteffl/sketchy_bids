#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y gnupg curl wget jq awscli


EC2_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# Securely fetch passwords from Secrets Manager using instance role
ADMIN_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "${mongo_admin_secret_arn}" --region $EC2_REGION --query SecretString --output text)
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "${mongo_user_secret_arn}" --region $EC2_REGION --query SecretString --output text)

# Install MongoDB
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

sudo apt-get update -y
sudo apt-get install -y mongodb-org=4.4.6 mongodb-org-server=4.4.6 mongodb-org-shell=4.4.6 mongodb-org-mongos=4.4.6 mongodb-org-tools=4.4.6

# Configure MongoDB
sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
sudo sed -i '/security/a\  authorization: enabled' /etc/mongod.conf

sudo systemctl start mongod
sudo systemctl enable mongod

# Wait for MongoDB to be ready
until mongosh --eval "print(\"waited for connection\")"
do
   sleep 2
done

# Create database users
mongosh <<EOC
use admin
db.createUser({
  user: "admin",
  pwd: "$ADMIN_PASSWORD",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
})
db.auth("admin", "$ADMIN_PASSWORD")
use sketchydb
db.createUser({
  user: "${db_user}",
  pwd: "$DB_PASSWORD",
  roles: [ { role: "readWrite", db: "sketchydb" } ]
})
EOC

sudo systemctl restart mongod

# --- Backup Script ---
cat <<EOT > /usr/local/bin/backup.sh
#!/bin/bash
TIMESTAMP=\$(date +%F-%H%M)
BUCKET_NAME="${s3_bucket_name}"
DB_NAME="sketchydb"
BACKUP_PATH="/tmp/mongo-backup-\$TIMESTAMP"
ARCHIVE_PATH="/tmp/\$DB_NAME-\$TIMESTAMP.tgz"

mongodump --db \$DB_NAME --out \$BACKUP_PATH
tar -czvf \$ARCHIVE_PATH -C \$BACKUP_PATH .
aws s3 cp \$ARCHIVE_PATH s3://\$BUCKET_NAME/ --acl public-read
rm -rf \$BACKUP_PATH \$ARCHIVE_PATH
EOT

chmod +x /usr/local/bin/backup.sh


(crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/backup.sh") | crontab -