#!/bin/bash

. /functions.sh

wait_for_db

print_info "Starting \e[${ZNUNY_ASCII_COLOR_BLUE}m Znuny\e[0m \e[31m${ZNUNY_VERSION}\e[0m \e[${ZNUNY_ASCII_COLOR_BLUE}mCommunity Edition\e[0m \e[0m\n"

# Ensure configuration is up to date with latest defaults and environment variables
setup_znuny_config

if [ -e "${ZNUNY_ROOT}var/tmp/firsttime" ]; then
    #Load default install
    load_defaults
    #Set default admin user password
    print_info "Setting password for default admin account \e[${ZNUNY_ASCII_COLOR_BLUE}mroot@localhost\e[0m to: \e[31m**********\e[0m"
    ${ZNUNY_ROOT}bin/znuny.Console.pl Admin::User::SetPassword root@localhost ${ZNUNY_ROOT_PASSWORD}
fi

# Only adjust permissions if ZNUNY_SET_PERMISSIONS == yes
if [ "${ZNUNY_SET_PERMISSIONS}" == "yes" ]; then
    print_info "Setting Znuny permissions"
    ${ZNUNY_ROOT}bin/znuny.SetPermissions.pl --znuny-user=znuny --web-group=www-data ${ZNUNY_ROOT}
elif [ "${ZNUNY_SET_PERMISSIONS}" == "skip-article-dir" ]; then
    # Adjust permissions but skip articles directory if ZNUNY_SET_PERMISSIONS == skip-article-dir
    print_info "Setting permissions but skipping articles directory"
    ${ZNUNY_ROOT}bin/znuny.SetPermissions.pl --znuny-user=znuny --web-group=www-data ${ZNUNY_ROOT} --skip-article-dir
else
    print_info "ZNUNY_SET_PERMISSIONS set to \e[${ZNUNY_ASCII_COLOR_RED}mno\e[0m, Skipping setting permissions"
fi

# Enable/disable the installation of not allowed packages
not_allowed_pkgs_install
# Install any new modules found in ${ZNUNY_ADDONS_PATH}
install_modules ${ZNUNY_ADDONS_PATH}
set_ticket_counter
rm -fr ${ZNUNY_ROOT}var/tmp/firsttime

# Create self-signed SSL certificate for Znuny if missing
ZNUNY_SSL_DIR=/etc/ssl/znuny
mkdir -p "${ZNUNY_SSL_DIR}"
chmod 700 "${ZNUNY_SSL_DIR}"
if [ ! -f "${ZNUNY_SSL_DIR}/znuny.key" ] || [ ! -f "${ZNUNY_SSL_DIR}/znuny.crt" ]; then
    print_info "Creating self-signed SSL certificate in ${ZNUNY_SSL_DIR}"
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "${ZNUNY_SSL_DIR}/znuny.key" \
        -out "${ZNUNY_SSL_DIR}/znuny.crt" \
        -subj "/C=US/ST=Unknown/L=Unknown/O=Znuny/OU=IT/CN=localhost" \
        -addext "subjectAltName = DNS:localhost,IP:127.0.0.1"
    chmod 600 "${ZNUNY_SSL_DIR}/znuny.key"
    chmod 644 "${ZNUNY_SSL_DIR}/znuny.crt"
fi

#Start Znuny
${ZNUNY_ROOT}bin/Cron.sh start
${ZNUNY_ROOT}bin/znuny.Daemon.pl start
${ZNUNY_ROOT}bin/znuny.Console.pl Maint::Config::Rebuild
${ZNUNY_ROOT}bin/znuny.Console.pl Maint::Cache::Delete
set_skins

# Check if storage type needs to be changed
switch_article_storage_type

# Delete default configuration
rm -fr ${ZNUNY_CONFIG_MOUNT_DIR}

#Launch supervisord
print_info "Starting supervisord..."
supervisord&
print_info "Restarting Znuny daemon..."
${ZNUNY_ROOT}bin/znuny.Daemon.pl stop
sleep 2
${ZNUNY_ROOT}bin/znuny.Daemon.pl start

print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mZnuny\e[0m Ready !"

# setup handlers
# on callback, kill the background process,
# which is `tail -f /dev/null` and execute the specified handler
trap 'kill ${!}; term_handler' SIGTERM

# wait forever
while true
do
 tail -f /dev/null & wait ${!}
done