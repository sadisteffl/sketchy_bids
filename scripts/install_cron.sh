# DB Backup
(crontab -l ; echo "0 */6 * * * /usr/local/bin/backup.sh") | crontab -
