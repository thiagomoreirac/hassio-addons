#!/usr/bin/env bashio
# shellcheck shell=bash

####################
# GLOBAL VARIABLES #
####################

bashio::log.info "Setting variables"

ENVFILE="/.env"
ln -sf /.env /opt/seafile/.env

cp /defaults/.env.example "$ENVFILE"

sed -i "s|NOSWAG=0|NOSWAG=1|g" "$ENVFILE"
sed -i "s|USE_HTTPS=1|USE_HTTPS=0|g" "$ENVFILE"
if bashio::config.has_value "PUID"; then sed -i "s|PUID=1000|PUID=$(bashio::config 'PUID')|g" "$ENVFILE"; fi
if bashio::config.has_value "PGID"; then sed -i "s|PGID=1000|PGID=$(bashio::config 'PGID')|g" "$ENVFILE"; fi
if bashio::config.has_value "TZ"; then sed -i "s|TZ=Europe/Zurich|TZ=$(bashio::config 'TZ')|g" "$ENVFILE"; fi
if bashio::config.has_value "URL"; then sed -i "s|URL=your.domain|URL=$(bashio::config 'URL')|g" "$ENVFILE"; fi
if bashio::config.has_value "SEAFILE_ADMIN_EMAIL"; then sed -i "s|SEAFILE_ADMIN_EMAIL=you@your.email|SEAFILE_ADMIN_EMAIL=$(bashio::config 'SEAFILE_ADMIN_EMAIL')|g" "$ENVFILE"; fi
if bashio::config.has_value "SEAFILE_ADMIN_PASSWORD"; then sed -i "s|SEAFILE_ADMIN_PASSWORD=secret|SEAFILE_ADMIN_PASSWORD=$(bashio::config 'SEAFILE_ADMIN_PASSWORD')|g" "$ENVFILE"; fi

#################
# DATA_LOCATION #
#################

bashio::log.info "Setting data location"
DATA_LOCATION=$(bashio::config 'data_location')

echo "Check $DATA_LOCATION folder exists"
mkdir -p "$DATA_LOCATION"

echo "Setting permissions"
chown -R "$(bashio::config 'PUID'):$(bashio::config 'PGID')" "$DATA_LOCATION"
chmod -R 755 "$DATA_LOCATION"

echo "Creating symlink"
ln -sf "$DATA_LOCATION" /shared

sed -i "s|SEAFILE_CONF_DIR=./seafile/conf|SEAFILE_CONF_DIR=$DATA_LOCATION/conf|g" "$ENVFILE"
sed -i "1a export SEAFILE_CONF_DIR=$DATA_LOCATION/conf" /opt/seafile/sea*/*.sh
sed -i "s|SEAFILE_LOGS_DIR=./seafile/logs|SEAFILE_LOGS_DIR=$DATA_LOCATION/logs|g" "$ENVFILE"
sed -i "1a export SEAFILE_LOGS_DIR=$DATA_LOCATION/logs" /opt/seafile/sea*/*.sh
sed -i "s|SEAFILE_DATA_DIR=./seafile/seafile-data|SEAFILE_DATA_DIR=$DATA_LOCATION/seafile-data|g" "$ENVFILE"
sed -i "1a export SEAFILE_DATA_DIR=$DATA_LOCATION/seafile-data" /opt/seafile/sea*/*.sh
sed -i "s|SEAFILE_SEAHUB_DIR=./seafile/seahub-data|SEAFILE_SEAHUB_DIR=$DATA_LOCATION/seahub-data|g" "$ENVFILE"
sed -i "1a export SEAFILE_SEAHUB_DIR=$DATA_LOCATION/seahub-data" /opt/seafile/sea*/*.sh
sed -i "s|SEAFILE_SQLITE_DIR=./seafile/sqlite|SEAFILE_SQLITE_DIR=$DATA_LOCATION/sqlite|g" "$ENVFILE"
sed -i "1a export SEAFILE_SQLITE_DIR=$DATA_LOCATION/sqlite" /opt/seafile/sea*/*.sh
sed -i "s|DATABASE_DIR=./db|DATABASE_DIR=$DATA_LOCATION/db|g" "$ENVFILE"
sed -i "1a export DATABASE_DIR=$DATA_LOCATION/db" /opt/seafile/sea*/*.sh

###################
# Define database #
###################

bashio::log.info "Defining database"

case $(bashio::config 'database') in
    
    # Use sqlite
    sqlite)
        sed -i "s|SQLITE=0|SQLITE=1|g" "$ENVFILE"
        sed -i "1a export SQLITE=1" *.sh
    ;;
    
    # Use mariadb
    mariadb_addon)
        bashio::log.info "Using MariaDB addon. Requirements : running MariaDB addon. Discovering values..."
        if ! bashio::services.available 'mysql'; then
            bashio::log.fatal \
            "Local database access should be provided by the MariaDB addon"
            bashio::exit.nok \
            "Please ensure it is installed and started"
        fi
        
        # Use values
        sed -i "s|MYSQL_HOST=db|MYSQL_HOST=$(bashio::services "mysql" "host")|g" "$ENVFILE"
        sed -i "s|MYSQL_PORT=3306|MYSQL_PORT=$(bashio::services "mysql" "port")|g" "$ENVFILE"
        sed -i "s|MYSQL_ROOT_PASSWD=secret|MYSQL_USER_PASSWD=$(bashio::services "mysql" "password")|g" "$ENVFILE"
        sed -i "1a export MYSQL_HOST=$(bashio::services 'mysql' 'host')" /opt/seafile/sea*/*.sh
        sed -i "1a export MYSQL_PORT=$(bashio::services 'mysql' 'port')" /opt/seafile/sea*/*.sh
        sed -i "1a export MYSQL_USER_PASSWD=$(bashio::services "mysql" "password")" /opt/seafile/sea*/*.sh

        bashio::log.warning "This addon is using the Maria DB addon"
        bashio::log.warning "Please ensure this is included in your backups"
        bashio::log.warning "Uninstalling the MariaDB addon will remove any data"
    ;;
esac

##############
# LAUNCH APP #
##############

bashio::log.info "Starting app"
/./docker_entrypoint.sh
