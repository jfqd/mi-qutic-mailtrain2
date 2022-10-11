#!/bin/bash

HOSTNAME=$(/native/usr/sbin/mdata-get mailtrain_host)
MYSQL_HOST=$(/native/usr/sbin/mdata-get mysql_host)
MYSQL_USER=$(/native/usr/sbin/mdata-get mysql_user)
MYSQL_DB=$(/native/usr/sbin/mdata-get mysql_db)
MYSQL_PWD=$(/native/usr/sbin/mdata-get mysql_password)
SECRET=$(pwgen -1 128)

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

IFS=. read -r sub domain tld <<< "${HOSTNAME}"

cat > server/config/production.yaml <<EOT
user: mailtrain
group: mailtrain
roUser: nobody
roGroup: nobody

defaultLanguage: de-DE

www:
  host: 0.0.0.0
  secret: "${SECRET}"
  trustedUrlBase: https://${sub}-adm.${domain}.${tld}
  sandboxUrlBase: https://${sub}-sbx.${domain}.${tld}
  publicUrlBase: https://${HOSTNAME}
  proxy: true
  postSize: 5MB

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
  enabled: false
  log:
    level: warn

queue:
  processes: 2
EOT
    
cat > server/services/workers/reports/config/production.yaml <<EOT
log:
  level: warn
  
defaultLanguage: de-DE

mysql:
  host: "${MYSQL_HOST}"
  user: "${MYSQL_USER}"
  database: "${MYSQL_DB}"
  password: "${MYSQL_PWD}"
EOT

echo "* Import basic sql cause mailtrain has issues with its own sql-files (on mysql 8)"
mysql -h "${MYSQL_HOST}" -u "${MYSQL_USER}" -p "${MYSQL_PWD}" < /usr/local/var/tmp/mailtrain.sql

echo "* Fix git usage"
git config --global url."https://".insteadOf git://
git config url."https://".insteadOf git://

echo "* Fix mailtrain layout"
sed -i \
    -e "s|<a href=\"https://mailtrain.org\">Mailtrain.org</a>, <a href=\"mailto:info@mailtrain.org\">info@mailtrain.org</a>. <a href=\"https://github.com/Mailtrain-org/mailtrain\">{t('sourceOnGitHub')}</a>|Mailtrain.org, <a href=\"https://qutic.com/de/loesungen/mailtrain-hosting/\">Mailtrain-Hosting</a>|g" \
    client/src/lib/page.js

sed -i \
    -e "s*@import url('https://fonts.googleapis.com/css?family=Ubuntu+Mono:400,400i,700,700i|Ubuntu:300,300i,400,400i,700,700i&subset=latin-ext');*@font-face {font-family: 'Ubuntu';font-style: normal;font-weight: 400;src: url('https://qutic.com/fonts/ubuntu/400/ubuntu.eot'); src: local('Ubuntu Regular'), local('Ubuntu-Regular'),url('https://qutic.com/fonts/ubuntu/400/ubuntu.eot?#iefix') format('embedded-opentype'),url('https://qutic.com/fonts/ubuntu/400/ubuntu.woff2') format('woff2'),url('https://qutic.com/fonts/ubuntu/400/ubuntu.woff') format('woff'),url('https://qutic.com/fonts/ubuntu/400/ubuntu.ttf') format('truetype'), url('https://qutic.com/fonts/ubuntu/400/ubuntu.svg#Ubuntu') format('svg');}\n\n@font-face {font-family: 'Ubuntu';font-style: bold;font-weight: 700;src: url('https://qutic.com/fonts/ubuntu/700/ubuntu.eot'); src: local('Ubuntu Bold'), local('Ubuntu-Bold'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.eot?#iefix') format('embedded-opentype'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.woff2') format('woff2'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.woff') format('woff'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.ttf') format('truetype'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.svg#Ubuntu') format('svg');}\n\n@font-face {font-family: 'Ubuntu Mono';font-style: normal;font-weight: 400;src: url('https://qutic.com/fonts/ubuntu-mono-mono/400/ubuntu-mono.eot'); src: local('Ubuntu Mono Regular'), local('Ubuntu Mono-Regular'),url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.eot?#iefix') format('embedded-opentype'),url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.woff2') format('woff2'),url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.woff') format('woff'),url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.ttf') format('truetype'), url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.svg#Ubuntu%20Mono') format('svg');}\n\n@font-face {font-family: 'Ubuntu Mono';font-style: bold;font-weight: 700;src: url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.eot'); src: local('Ubuntu Mono Bold'), local('Ubuntu Mono-Bold'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.eot?#iefix') format('embedded-opentype'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.woff2') format('woff2'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.woff') format('woff'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.ttf') format('truetype'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.svg#Ubuntu%20Mono') format('svg');}*" \
    client/src/scss/mailtrain.scss

sed -i \
    -e "s#<mj-font name=\"Lato\" href=\"https://fonts.googleapis.com/css?family=Lato:400,700,400italic\" />##" \
    server/views/subscription/layout.mjml.hbs 

echo "* Install node modules and build client"
reinstallAllModules
(cd client && npm run build || true)

echo "* Fix utf8mb4 conversion"
sed -i \
    -e "s|tablas[i].table_name|tablas[i].TABLE_NAME|" \
    server/setup/knex/migrations/20200824160149_convert_to_utf8mb4.js

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

# zonemta dependency
# systemctl start mongod
# systemctl enable mongod

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
