#!/bin/bash

MYSQL_HOST=$(/native/usr/sbin/mdata-get mysql_host)
MYSQL_USER=$(/native/usr/sbin/mdata-get mysql_user)
MYSQL_DB=$(/native/usr/sbin/mdata-get mysql_db)
MYSQL_PWD=$(/native/usr/sbin/mdata-get mysql_password)
SECRET=$(pwgen -1)

function doForAllModules {
  # Install required node packages
  for idx in client shared server zone-mta mvis/client mvis/server mvis/test-embed mvis/ivis-core/client mvis/ivis-core/server mvis/ivis-core/shared mvis/ivis-core/embedding; do
    if [ -d $idx ]; then
      ($1 $idx)
    fi
  done
}

function reinstallModules {
  local idx=$1
  echo Reinstalling modules in $idx
  cd $idx && rm -rf node_modules && npm install
}

function reinstallAllModules {
  doForAllModules reinstallModules
}

echo "* Setup installation configuration"
cd /var/www/mailtrain
cat > server/config/production.yaml <<EOT
user: mailtrain
group: mailtrain
roUser: nobody
roGroup: nobody

www:
  host: 0.0.0.0
  secret: "${SECRET}"
  trustedUrlBase: http://localhost:3000
  sandboxUrlBase: http://localhost:3003
  publicUrlBase: http://localhost:3004

mysql:
  host: "${MYSQL_HOST}"
  user: "${MYSQL_USER}"
  database: "${MYSQL_DB}"
  password: "${MYSQL_PWD}"

redis:
  enabled: true

log:
  level: info

builtinZoneMTA:
  log:
    level: warn

queue:
  processes: 5
EOT
    
cat >> server/services/workers/reports/config/production.yaml <<EOT
log:
  level: warn

mysql:
  host: "${MYSQL_HOST}"
  user: "${MYSQL_USER}"
  database: "${MYSQL_DB}"
  password: "${MYSQL_PWD}"
EOT

echo "* Install node modules"
reinstallAllModules
(cd client && npm run build || true)

chown -R mailtrain:mailtrain .
chmod o-rwx server/config

echo "* Start mailtrain service and dependencies"
mv /usr/local/var/tmp/mailtrain_service /etc/systemd/system/mailtrain.service || true
mv /usr/local/var/tmp/nginx_service /lib/systemd/system/nginx.service || true
systemctl daemon-reload

systemctl restart nginx
systemctl enable nginx

systemctl start redis-server
systemctl enable redis-server

systemctl start mongod
systemctl enable mongod

systemctl start mailtrain
systemctl enable mailtrain

echo "* Cleanup"
rm -rf /usr/local/var/tmp
mdata-delete mail_smarthost || true
mdata-delete mail_auth_user || true
mdata-delete mail_auth_pass || true
mdata-delete mail_adminaddr || true
mdata-delete mysql_host || true
mdata-delete mysql_user || true
mdata-delete mysql_db || true
mdata-delete mysql_password || true
