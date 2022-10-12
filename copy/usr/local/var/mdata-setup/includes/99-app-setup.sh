#!/bin/bash

HOSTNAME=$(/native/usr/sbin/mdata-get mailtrain_host)
MYSQL_INIT=$(/native/usr/sbin/mdata-get mysql_init)
MYSQL_HOST=$(/native/usr/sbin/mdata-get mysql_host)
MYSQL_USER=$(/native/usr/sbin/mdata-get mysql_user)
MYSQL_DB=$(/native/usr/sbin/mdata-get mysql_db)
MYSQL_PWD=$(/native/usr/sbin/mdata-get mysql_password)
SECRET=$(pwgen -1 128)

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

if [[ "${MYSQL_INIT}" = "true" ]]; then
  echo "* Import basic sql cause mailtrain has issues with its own sql-files (on mysql 8)"
  cat > /root/.my.cnf <<EOF
[client]
host = ${MYSQL_HOST}
user = "${MYSQL_USER}"
password = "${MYSQL_PWD}"
EOF
  chmod 0400 /root/.my.cnf

  /usr/bin/mysql --database="${MYSQL_DB}" --defaults-file=/root/.my.cnf < /usr/local/var/tmp/mailtrain.sql
else
  echo "* Skip sql import cause it was not requested"
fi

echo "* Fix mailtrain layout"
# HINT: rebuild client (with mailtrain-init) on changes
sed -i \
    -e "s|<a href=\"https://mailtrain.org\">Mailtrain.org</a>, <a href=\"mailto:info@mailtrain.org\">info@mailtrain.org</a>. <a href=\"https://github.com/Mailtrain-org/mailtrain\">{t('sourceOnGitHub')}</a>|Mailtrain.org, <a href=\"https://qutic.com/de/loesungen/mailtrain-hosting/\">hosted by qutic.com</a>|g" \
    client/src/lib/page.js

sed -i \
    -e "s|<div>{t('build').*</div>|<p>Leistungsfähiger Newsletter-Dienst für Ihre Kunden-Mailings.</p>|" \
    client/src/Home.js

sed -i \
    -e "s*@import url('https://fonts.googleapis.com/css?family=Ubuntu+Mono:400,400i,700,700i|Ubuntu:300,300i,400,400i,700,700i&subset=latin-ext');*@font-face {font-family: 'Ubuntu';font-style: normal;font-weight: 400;src: url('https://qutic.com/fonts/ubuntu/400/ubuntu.eot'); src: local('Ubuntu Regular'), local('Ubuntu-Regular'),url('https://qutic.com/fonts/ubuntu/400/ubuntu.eot?#iefix') format('embedded-opentype'),url('https://qutic.com/fonts/ubuntu/400/ubuntu.woff2') format('woff2'),url('https://qutic.com/fonts/ubuntu/400/ubuntu.woff') format('woff'),url('https://qutic.com/fonts/ubuntu/400/ubuntu.ttf') format('truetype'), url('https://qutic.com/fonts/ubuntu/400/ubuntu.svg#Ubuntu') format('svg');}\n\n@font-face {font-family: 'Ubuntu';font-style: bold;font-weight: 700;src: url('https://qutic.com/fonts/ubuntu/700/ubuntu.eot'); src: local('Ubuntu Bold'), local('Ubuntu-Bold'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.eot?#iefix') format('embedded-opentype'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.woff2') format('woff2'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.woff') format('woff'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.ttf') format('truetype'),url('https://qutic.com/fonts/ubuntu/700/ubuntu.svg#Ubuntu') format('svg');}\n\n@font-face {font-family: 'Ubuntu Mono';font-style: normal;font-weight: 400;src: url('https://qutic.com/fonts/ubuntu-mono-mono/400/ubuntu-mono.eot'); src: local('Ubuntu Mono Regular'), local('Ubuntu Mono-Regular'),url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.eot?#iefix') format('embedded-opentype'),url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.woff2') format('woff2'),url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.woff') format('woff'),url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.ttf') format('truetype'), url('https://qutic.com/fonts/ubuntu-mono/400/ubuntu-mono.svg#Ubuntu%20Mono') format('svg');}\n\n@font-face {font-family: 'Ubuntu Mono';font-style: bold;font-weight: 700;src: url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.eot'); src: local('Ubuntu Mono Bold'), local('Ubuntu Mono-Bold'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.eot?#iefix') format('embedded-opentype'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.woff2') format('woff2'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.woff') format('woff'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.ttf') format('truetype'),url('https://qutic.com/fonts/ubuntu-mono/700/ubuntu-mono.svg#Ubuntu%20Mono') format('svg');}*" \
    client/src/scss/mailtrain.scss

cat >> client/src/scss/mailtrain.scss << EOF
body {
  font-size: 100%
}

.bg-dark {
  background-color: #525c66 !important;
}

.navbar-dark .navbar-nav .nav-link {
  color: white;
}

body.mailtrain .navbar-dark .navbar-nav .active > .nav-link:hover {
  font-weight: bold;
  text-decoration: underline
}

.navbar-dark .navbar-nav .show > .nav-link,
.navbar-dark .navbar-nav .active > .nav-link,
.navbar-dark .navbar-nav .nav-link.show, 
.navbar-dark .navbar-nav .nav-link.active {
  font-weight: bold;
  text-decoration: underline
}

breadcrumb-item.active {
  color: #444;
}

.btn-primary {
  color: #fff;
  background-color: #525c66;
  border-color: #525c66;
}

.btn-primary:hover {
  color: #fff;
  background-color: #292e33;
  border-color: #292e33;
}

link.active, 
.nav-pills .show > .nav-link {
  background-color: #525c66;
}

nav-pills .nav-link.active, 
.nav-pills .show > .nav-link {
  background-color: #525c66;
}

a {
  color: #dd4814;
  text-decoration: none;
}

a:hover, a:focus {
  color: #97310e;
  text-decoration: underline;
}

code {
  color: #c7254e;
}

footer.app-footer {
  margin-top: 2rem;
}

@media (max-width: 1023px) {
  body.mailtrain .main .container-fluid {
    padding: 0 10px;
  }

  body.mailtrain .app-header .navbar {
    padding: 0 10px;
  }

  body.mailtrain .mt-breadcrumb-and-tertiary-navbar .breadcrumb {
    padding-left: 10px;
    padding-right: 10px;
  }
}

@media (min-width: 1024px) {
  body.mailtrain .main .container-fluid {
    padding: 0 25px;
  }

  body.mailtrain .app-header .navbar {
    padding: 0 25px;
  }

  body.mailtrain .mt-breadcrumb-and-tertiary-navbar .breadcrumb {
    padding-left: 25px;
    padding-right: 25px;
  }
}
EOF

sed -i \
    -e "s#<mj-font name=\"Lato\" href=\"https://fonts.googleapis.com/css?family=Lato:400,700,400italic\" />##" \
    server/views/subscription/layout.mjml.hbs 

sed -i \
    -e "s|<meta charset=\"utf-8\">|<meta charset=\"utf-8\"><meta name=\"robots\" content=\"noindex,nofollow,noarchive\" />|" \
    server/views/layout.hbs

echo "* Fix utf8mb4 conversion"
sed -i \
    -e "s|].table_name|].TABLE_NAME|" \
    server/setup/knex/migrations/20200824160149_convert_to_utf8mb4.js

echo "* Install node modules and build client"
chown -R mailtrain:mailtrain .
sudo -u mailtrain /usr/local/bin/mailtrain-init || true

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
# apt-get -y purge git make gcc g++ build-essential
# rm -rf /usr/local/var/tmp
mdata-delete mail_smarthost || true
mdata-delete mail_auth_user || true
mdata-delete mail_auth_pass || true
mdata-delete mail_adminaddr || true
mdata-delete mysql_host || true
mdata-delete mysql_user || true
mdata-delete mysql_db || true
mdata-delete mysql_password || true
