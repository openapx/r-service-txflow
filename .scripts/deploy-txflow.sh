#! /bin/bash

#
# Deploy txflow service
#
#
#

# -- define some constants
APP_HOME=/opt/openapx/apps/txflow 


REPO_URL=https://cran.r-project.org


# -- iniitate install logs directory

mkdir -p /logs/openapx/txflow


# -- local vault

echo "-- local vault"

addgroup --system --quiet vaultuser

mkdir /.vault

chgrp vaultuser /.vault 
chmod g+rs,o-rwx /.vault




# -- txflow service account

echo "-- txflow service account"

adduser --system --group --shell /bin/bash --no-create-home --comment "txflow service user account" --quiet txflow

usermod -a -G vaultuser txflow




# -- initiate app home

echo "-- initiate application install directory"

mkdir -p ${APP_HOME}



# -- configure local R session

echo "-- app R session configurations"

mkdir -p ${APP_HOME}/library

DEFAULT_SITELIB=$(Rscript -e "cat( .Library.site, sep = .Platform\$path.sep )")

cat > ${APP_HOME}/.Renviron << EOF
R_LIBS_SITE=${APP_HOME}/library:${DEFAULT_SITELIB}
EOF


cat > ${APP_HOME}/.Rprofile << EOF

# -- CRAN repo

local( {
  options( "repos" = c( "CRAN" = "https://cloud.r-project.org") )
})

EOF





# -- service install source

echo "-- deploy R packages"

mkdir -p /sources/R-packages


# - cxapp

echo "   - downloading R package cxapp"

SOURCE_ASSET=$(curl -s -H "Accept: application/vnd.github+json" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/cxlib/r-package-cxapp/releases/latest )

SOURCE_URL=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^cxapp_\\d+.\\d+.\\d+.tar.gz$") ) | .browser_download_url' )
CXAPP_SOURCE=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^cxapp_\\d+.\\d+.\\d+.tar.gz$") ) | .name' )

curl -sL -o /sources/R-packages/${CXAPP_SOURCE} ${SOURCE_URL}


_MD5=($(md5sum /sources/R-packages/${CXAPP_SOURCE}))
_SHA256=($(sha256sum /sources/R-packages/${CXAPP_SOURCE}))

echo "      ${CXAPP_SOURCE}   (MD5 ${_MD5} / SHA-256 ${_SHA256})"

unset _MD5
unset _SHA256

unset SOURCE_URL
unset SOURCE_ASSET



# - cxaudit

echo "   - downloading R package cxaudit"

SOURCE_ASSET=$(curl -s -H "Accept: application/vnd.github+json" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/cxlib/r-package-cxaudit/releases/latest )

SOURCE_URL=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^cxaudit_\\d+.\\d+.\\d+.tar.gz$") ) | .browser_download_url' )
CXAUDIT_SOURCE=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^cxaudit_\\d+.\\d+.\\d+.tar.gz$") ) | .name' )

curl -sL -o /sources/R-packages/${CXAUDIT_SOURCE} ${SOURCE_URL}


_MD5=($(md5sum /sources/R-packages/${CXAUDIT_SOURCE}))
_SHA256=($(sha256sum /sources/R-packages/${CXAUDIT_SOURCE}))

echo "      ${CXAUDIT_SOURCE}   (MD5 ${_MD5} / SHA-256 ${_SHA256})"

unset _MD5
unset _SHA256

unset SOURCE_URL
unset SOURCE_ASSET



# - txflow service

echo "   - downloading txflow service"

SOURCE_ASSET=$(curl -s -H "Accept: application/vnd.github+json" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/openapx/r-service-txflow/releases/latest )

SOURCE_URL=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^txflow.service_\\d+.\\d+.\\d+.tar.gz$") ) | .browser_download_url' )
TXFLOW_SOURCE=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^txflow.service_\\d+.\\d+.\\d+.tar.gz$") ) | .name' )

curl -sL -o /sources/R-packages/${TXFLOW_SOURCE} ${SOURCE_URL}


_MD5=($(md5sum /sources/R-packages/${TXFLOW_SOURCE}))
_SHA256=($(sha256sum /sources/R-packages/${TXFLOW_SOURCE}))

echo "      ${TXFLOW_SOURCE}   (MD5 ${_MD5} / SHA-256 ${_SHA256})"

unset _MD5
unset _SHA256

unset SOURCE_URL
unset SOURCE_ASSET



# - install dependencies and service

#   temporarily change workind directory to pick up environ and profile
CURRENT_WD=${pwd}

cd ${APP_HOME}

echo "   - install locations (first in list)"
Rscript -e "cat( c( paste0( \"   \", .libPaths()), \"   --\"), sep = \"\n\" )"

echo "   - install R package dependencies"
Rscript -e "install.packages( c( \"sodium\", \"openssl\", \"plumber\", \"jsonlite\",  \"digest\", \"uuid\", \"httr2\"), type = \"source\", destdir = \"/sources/R-packages\" )" >> /logs/openapx/txflow/install-r-packages.log 2>&1

echo "   - install R package cxapp"
Rscript -e "install.packages( \"/sources/R-packages/${CXAPP_SOURCE}\", type = \"source\", INSTALL_opts = \"--install-tests\" )" >> /logs/openapx/txflow/install-r-packages.log 2>&1

echo "   - install R package cxaudit"
Rscript -e "install.packages( \"/sources/R-packages/${CXAUDIT_SOURCE}\", type = \"source\", INSTALL_opts = \"--install-tests\" )" >> /logs/openapx/txflow/install-r-packages.log 2>&1


echo "   - install R package txflow service"
Rscript -e "install.packages( \"/sources/R-packages/${TXFLOW_SOURCE}\", type = \"source\", INSTALL_opts = \"--install-tests\" )" >> /logs/openapx/txflow/install-r-packages.log 2>&1


#   restore working directory
cd ${CURRENT_WD}



echo "   - R package install sources"

find /sources/R-packages -maxdepth 1 -type f -exec bash -c '_MD5=($(md5sum $1)); _SHA256=($(sha256sum $1)); echo "      $(basename $1)   (MD-5 ${_MD5} / SHA-256 ${_SHA256})"' _ {} \;

echo "   - (end of R package install sources)"




echo "   - remove deployment profile"
rm -f ${APP_HOME}/.Rprofile


# -- Logging area

echo "-- set up logging area"
mkdir -p /data/txflow/logs

chgrp -R txflow /data/txflow
chmod -R g+rws /data/txflow



# -- application example configuration

echo "-- example application configuration"


# -- txflow as a local file system store
mkdir -p /data/txflow/repos /data/txflow/work

chgrp -R txflow /data/txflow
chmod -R g+rws /data/txflow


cat <<\EOF > ${APP_HOME}/app.properties 

# -- default service configuration


# -- txflow 

# - local storage enabled
TXFLOW.STORE = LOCAL

# - txflow repositories
TXFLOW.DATA = /data/txflow/repos

# - txflow work area
TXFLOW.WORK = /data/txflow/work



# -- logging 
LOG.PATH = /data/txflow/logs
LOG.NAME = txflow
LOG.ROTATION = month


# -- vault configuration

#    note: using a local vault
#    note: Azure Key Vault also supported
VAULT = LOCAL
VAULT.DATA = /.vault


# -- API authorization
#    note: access tokens should be created 
#    note: see reference section Authentication in the txflow service API reference
#    note: see section API Authentication in the cxapp package https://github.com/cxlib/r-package-cxapp 
#    note: service - utility /opt/openapx/utilities/vault-apitoken-service.sh <service name>
API.AUTH.SECRETS = /api/auth/txflow/services/*


# - named list of users and services acting as admins
#   note: a value of '*' permits all authorized connections to perform admin tasks 
#   note: restrict using spaced delimited list of principals associated with access tokens
#   note: see section API Authentication in the cxapp package https://github.com/cxlib/r-package-cxapp 
API.ADMINS = *


EOF



# -- application example configuration

echo "-- example service configuration"
echo "   - enable local database"
echo "   - enable 5 worker sessions"


cat <<\EOF > ${APP_HOME}/service.properties 

# -- default service configuration

# -- number of parallel R session to serve requests
WORKERS=5

EOF



# -- clean-up

echo "-- clean-up"

rm -Rf /sources