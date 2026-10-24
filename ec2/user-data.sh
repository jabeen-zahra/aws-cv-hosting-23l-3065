#!/bin/bash
# Install web server
dnf install -y httpd awscli
systemctl enable httpd
systemctl start httpd

# Create sync script location
mkdir -p /opt/cv
cat > /opt/cv/sync-cv.sh << 'SCRIPT_END'
#!/bin/bash
BUCKET="cv-23l-3065"
PREFIX="site/"
WEBROOT="/var/www/html"
LOGFILE="/var/log/cv-sync.log"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

aws s3 sync "s3://${BUCKET}/${PREFIX}" "${WEBROOT}" --delete

if [ $? -eq 0 ]; then
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
  sed -i "s/{{HOSTED_ON}}/EC2 ${INSTANCE_ID}/g" "${WEBROOT}/index.html"
  echo "${TIMESTAMP} - sync OK" >> "${LOGFILE}"
else
  echo "${TIMESTAMP} - sync FAILED" >> "${LOGFILE}"
fi
SCRIPT_END

chmod +x /opt/cv/sync-cv.sh

# Run once immediately
/opt/cv/sync-cv.sh

# Set up systemd timer to run every 5 minutes
cat > /etc/systemd/system/cv-sync.service << 'SERVICE_END'
[Unit]
Description=Sync CV from S3

[Service]
Type=oneshot
ExecStart=/opt/cv/sync-cv.sh
SERVICE_END

cat > /etc/systemd/system/cv-sync.timer << 'TIMER_END'
[Unit]
Description=Run CV sync every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
TIMER_END

systemctl daemon-reload
systemctl enable cv-sync.timer
systemctl start cv-sync.timer