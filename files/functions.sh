#!/bin/bash
. /util_functions.sh

function random_string() {
  echo `cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
}

# Default ZNUNY values
DEFAULT_ZNUNY_ROOT_PASSWORD="changeme"
DEFAULT_ZNUNY_DB_PASSWORD="changeme"
DEFAULT_ZNUNY_DB_NAME="znuny"
DEFAULT_ZNUNY_DB_USER="app_znuny"
DEFAULT_MYSQL_ROOT_USER="root"
DEFAULT_ZNUNY_DB_HOST="localhost"
DEFAULT_ZNUNY_DB_PORT="3306"
ZNUNY_ROOT_DIR="/opt/znuny"
ZNUNY_CONFIG_DIR="$ZNUNY_ROOT_DIR/Kernel"
ZNUNY_CONFIG_FILE="$ZNUNY_CONFIG_DIR/Config.pm"
ZNUNY_ASCII_COLOR_BLUE="38;5;31"
ZNUNY_ASCII_COLOR_RED="31"
WAIT_TIMEOUT=2
ZNUNY_ADDONS_PATH="${ZNUNY_ROOT}/addons/"
INSTALLED_ADDONS_DIR="${ZNUNY_ADDONS_PATH}/installed"

[ -z "${ZNUNY_INSTALL}" ] && ZNUNY_INSTALL="no"
[ -z "${ZNUNY_DB_NAME}" ] && print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mZNUNY_DB_NAME\e[0m not set, setting value to \e[${ZNUNY_ASCII_COLOR_RED}m${DEFAULT_ZNUNY_DB_NAME}\e[0m" && ZNUNY_DB_NAME=${DEFAULT_ZNUNY_DB_NAME}
[ -z "${ZNUNY_DB_USER}" ] && print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mZNUNY_DB_USER\e[0m not set, setting value to \e[${ZNUNY_ASCII_COLOR_RED}m${DEFAULT_ZNUNY_DB_USER}\e[0m" && ZNUNY_DB_USER=${DEFAULT_ZNUNY_DB_USER}
[ -z "${ZNUNY_DB_HOST}" ] && print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mZNUNY_DB_HOST\e[0m not set, setting value to \e[${ZNUNY_ASCII_COLOR_RED}m${DEFAULT_ZNUNY_DB_HOST}\e[0m" && ZNUNY_DB_HOST=${DEFAULT_ZNUNY_DB_HOST}
[ -z "${ZNUNY_DB_PORT}" ] && print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mZNUNY_DB_PORT\e[0m not set, setting value to \e[${ZNUNY_ASCII_COLOR_RED}m${DEFAULT_ZNUNY_DB_PORT}\e[0m" && ZNUNY_DB_PORT=${DEFAULT_ZNUNY_DB_PORT}
[ -z "${SHOW_ZNUNY_LOGO}" ] && SHOW_ZNUNY_LOGO="yes"
[ -z "${ZNUNY_HOSTNAME}" ] && ZNUNY_HOSTNAME="znuny-`random_string`" && print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mZNUNY_HOSTNAME\e[0m not set, setting hostname to '${ZNUNY_HOSTNAME}'"
[ -z "${ZNUNY_DB_PASSWORD}" ]  && print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mZNUNY_DB_PASSWORD\e[0m not set, setting password to \e[${ZNUNY_ASCII_COLOR_RED}m${DEFAULT_ZNUNY_DB_PASSWORD}\e[0m" && ZNUNY_DB_PASSWORD=${DEFAULT_ZNUNY_DB_PASSWORD}
[ -z "${ZNUNY_ROOT_PASSWORD}" ] && print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mZNUNY_ROOT_PASSWORD\e[0m not set, setting password to \e[${ZNUNY_ASCII_COLOR_RED}m${DEFAULT_ZNUNY_ROOT_PASSWORD}\e[0m" && ZNUNY_ROOT_PASSWORD=${DEFAULT_ZNUNY_ROOT_PASSWORD}
[ -z "${MYSQL_ROOT_PASSWORD}" ] && print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mMYSQL_ROOT_PASSWORD\e[0m not set, setting password to \e[${ZNUNY_ASCII_COLOR_RED}m${DEFAULT_MYSQL_ROOT_PASSWORD}\e[0m" && MYSQL_ROOT_PASSWORD=${DEFAULT_MYSQL_ROOT_PASSWORD}
[ -z "${MYSQL_ROOT_USER}" ] && print_info "\e[${ZNUNY_ASCII_COLOR_BLUE}mMYSQL_ROOT_USER\e[0m not set, setting user to \e[${ZNUNY_ASCII_COLOR_RED}m${DEFAULT_MYSQL_ROOT_USER}\e[0m" && MYSQL_ROOT_USER=${DEFAULT_MYSQL_ROOT_USER}

mysqlcmd="mysql -u${MYSQL_ROOT_USER} -h ${ZNUNY_DB_HOST} -P ${ZNUNY_DB_PORT} -p${MYSQL_ROOT_PASSWORD} "

function wait_for_db() {
  while [ ! "$(mysqladmin ping -h ${ZNUNY_DB_HOST} -P ${ZNUNY_DB_PORT} -u ${MYSQL_ROOT_USER} \
              --password="${MYSQL_ROOT_PASSWORD}" --silent --connect_timeout=3)" ]; do
    print_info "Database server is not available. Waiting ${WAIT_TIMEOUT} seconds..."
    sleep ${WAIT_TIMEOUT}
  done
  print_info "Database server is up !"
}

function create_db() {
  print_info "Creating ZNUNY database..."
  $mysqlcmd -e "CREATE DATABASE IF NOT EXISTS ${ZNUNY_DB_NAME};"
  [ $? -gt 0 ] && print_error "Couldn't create ZNUNY database !!" && exit 1
  $mysqlcmd -e " GRANT ALL ON ${ZNUNY_DB_NAME}.* to '${ZNUNY_DB_USER}'@'%' identified by '${ZNUNY_DB_PASSWORD}'";
  [ $? -gt 0 ] && print_error "Couldn't create database user !!" && exit 1
}

function add_config_value() {
  local key=${1}
  local value=${2}
  local mask=${3:-false}

  local value_perl_escaped="${value//\\/\\\\}"
  value_perl_escaped="${value_perl_escaped//\'/\\\'}"

  local value_sed_escaped="${value_perl_escaped//&/\\&}"
  value_sed_escaped="${value_sed_escaped//\//\\\/}"

  if [ "${mask}" == true ]; then
    print_value="**********"
  else
    print_value=${value}
  fi

  grep -qE "${key}" ${ZNUNY_CONFIG_FILE}
  if [ $? -eq 0 ]
  then
    print_info "Updating configuration option \e[${ZNUNY_ASCII_COLOR_BLUE}m${key}\e[0m with value: \e[31m${print_value}\e[0m"
    sed  -i -r "s/(\\\$Self->\{['\"]*${key}['\"]*\} *= *).*/\1'${value_sed_escaped}';/" ${ZNUNY_CONFIG_FILE}
  else
    print_info "Adding configuration option \e[${ZNUNY_ASCII_COLOR_BLUE}m${key}\e[0m with value: \e[31m${print_value}\e[0m"
    sed -i "/\\\$Self->{Home} = '\/opt\/znuny';/a \
    \$Self->{${key}} = '${value_perl_escaped}';" ${ZNUNY_CONFIG_FILE}
  fi
}

# Sets default configuration options on $ZNUNY_ROOT/Kernel/Config.pm. Options set
# here can't be modified via sysConfig later.
function setup_znuny_config() {
  #Set database configuration
  add_config_value "DatabaseUser" ${ZNUNY_DB_USER}
  add_config_value "DatabasePw" ${ZNUNY_DB_PASSWORD} true
  add_config_value "DatabaseHost" ${ZNUNY_DB_HOST}
  add_config_value "DatabasePort" ${ZNUNY_DB_PORT}
  add_config_value "Database" ${ZNUNY_DB_NAME}
  #Set general configuration values
  [ ! -z "${ZNUNY_LANGUAGE}" ] && add_config_value "DefaultLanguage" ${ZNUNY_LANGUAGE}
  [ ! -z "${ZNUNY_TIMEZONE}" ] && add_config_value "ZNUNYTimeZone" ${ZNUNY_TIMEZONE} && add_config_value "UserDefaultTimeZone" ${ZNUNY_TIMEZONE}
  add_config_value "FQDN" ${ZNUNY_HOSTNAME}
  add_config_value "Separator" "&"
  #Set email SMTP configuration

  [ ! -z "${ZNUNY_SENDMAIL_MODULE}" ] && add_config_value "SendmailModule" "Kernel::System::Email::${ZNUNY_SENDMAIL_MODULE}"
  [ ! -z "${ZNUNY_SMTP_SERVER}" ] && add_config_value "SendmailModule::Host" "${ZNUNY_SMTP_SERVER}"
  [ ! -z "${ZNUNY_SMTP_PORT}" ] && add_config_value "SendmailModule::Port" "${ZNUNY_SMTP_PORT}"
  [ ! -z "${ZNUNY_SMTP_USERNAME}" ] && add_config_value "SendmailModule::AuthUser" "${ZNUNY_SMTP_USERNAME}"
  [ ! -z "${ZNUNY_SMTP_PASSWORD}" ] && add_config_value "SendmailModule::AuthPassword" "${ZNUNY_SMTP_PASSWORD}" true
  add_config_value "SecureMode" "1"
  # Configure automatic backups
  #setup_backup_cron
  # Reinstall any existing addons
  reinstall_modules
}

function load_defaults() {
  #Check if a host-mounted volume for configuration storage was added to this
  #container
  check_host_mount_dir
  check_custom_skins_dir

  local current_version_file="${ZNUNY_CONFIG_DIR}/current_version"

  # Check if ZNUNY minor version changed and do a minor version upgrade

  #Check if database doesn't exists yet (it could if this is a container redeploy)
  $mysqlcmd -e "use ${ZNUNY_DB_NAME}"
  if [ $? -gt 0 ]; then
    create_db

    #Check that a backup isn't being restored
    if [ "$ZNUNY_INSTALL" == "no" ]; then
      print_info "Loading default db schemas..."
      $mysqlcmd ${ZNUNY_DB_NAME} < ${ZNUNY_ROOT}scripts/database/schema.mysql.sql
      [ $? -gt 0 ] && print_error "\n\e[1;31mERROR:\e[0m Couldn't load schema.mysql.sql schema !!\n" && exit 1
      print_info "Loading initial db inserts..."
      $mysqlcmd ${ZNUNY_DB_NAME} < ${ZNUNY_ROOT}scripts/database/initial_insert.mysql.sql
      [ $? -gt 0 ] && print_error "\n\e[1;31mERROR:\e[0m Couldn't load ZNUNY database initial inserts !!\n" && exit 1
      print_info "Loading initial schema constraints..."
      $mysqlcmd ${ZNUNY_DB_NAME} < ${ZNUNY_ROOT}scripts/database/schema-post.mysql.sql
      [ $? -gt 0 ] && print_error "\n\e[1;31mERROR:\e[0m Couldn't load schema-post.mysql.sql schema !!\n" && exit 1
    fi
  else
    print_warning "znuny database already exists, Ok."
  fi
}

function check_host_mount_dir() {
  #Copy the configuration from /Kernel (put there by the Dockerfile) to $ZNUNY_CONFIG_DIR
  #to be able to use host-mounted volumes. copy only if ${ZNUNY_CONFIG_DIR} doesn't exist
  if ([ "$(ls -A ${ZNUNY_CONFIG_MOUNT_DIR})" ] && [ ! "$(ls -A ${ZNUNY_CONFIG_DIR})" ]) || [ "${ZNUNY_UPGRADE}" == "yes" ] || [ ${_MINOR_VERSION_UPGRADE} == true ];
  then
    print_info "Found empty \e[${ZNUNY_ASCII_COLOR_BLUE}m${ZNUNY_CONFIG_DIR}\e[0m, copying default configuration to it..."
    mkdir -p ${ZNUNY_CONFIG_DIR}
    cp -rfp ${ZNUNY_CONFIG_MOUNT_DIR}/* ${ZNUNY_CONFIG_DIR}
    if [ $? -eq 0 ];
      then
        print_info "Done."
      else
        print_error "Can't move ZNUNY configuration directory to ${ZNUNY_CONFIG_DIR}" && exit 1
    fi
  else
    print_info "Found existing configuration directory, Ok."
  fi
}

function install_modules () {
  location=${1}
  mkdir -p ${INSTALLED_ADDONS_DIR}

  print_info "Installing ZNUNY addons..."
  if [ "${location}" != "" ]; then
    packages="$(ls ${location}/*.opm 2> /dev/null)"
    if [ "${packages}" != "" ]; then

      for i in ${packages}; do
        print_info "Installing addon: ${i}"
        $ZNUNY_ROOT/bin/otrs.Console.pl Admin::Package::Install ${i}> /dev/null 2>&1
        if [ $? -gt 0 ]; then
          print_error "Could not install ZNUNY addon: ${i}, try to do it manually with the Package Manager in the admin section of the web interface."
        else
          mv ${i} ${INSTALLED_ADDONS_DIR}
        fi
      done
      print_info "Done."
    else
      print_info "No addons found to install."
    fi
  else
    print_info "No directory with addons to install."
  fi
}

function reinstall_modules () {
  if [ "${ZNUNY_UPGRADE}" != "yes" ]; then
    print_info "Reinstalling ZNUNY addons..."
    $ZNUNY_ROOT/bin/otrs.Console.pl Admin::Package::ReinstallAll > /dev/null 2>&1

    if [ $? -gt 0 ]; then
      print_error "Could not reinstall ZNUNY addons, try to do it manually with the Package Manager in the admin section of the web interface."
    else
      print_info "Done."
    fi
  fi
}

function set_ticket_counter() {
  if [ ! -z "${ZNUNY_TICKET_COUNTER}" ]; then
    print_info "Setting the start of the ticket counter to: \e[${ZNUNY_ASCII_COLOR_BLUE}m'${ZNUNY_TICKET_COUNTER}'\e[0m"
    echo "${ZNUNY_TICKET_COUNTER}" > ${ZNUNY_ROOT}var/log/TicketCounter.log
  fi
  if [ ! -z $ZNUNY_NUMBER_GENERATOR ]; then
    add_config_value "Ticket::NumberGenerator" "Kernel::System::Ticket::Number::${ZNUNY_NUMBER_GENERATOR}"
  fi
}

function not_allowed_pkgs_install() {
  local _allow=0
  print_info "Setting the installation of \e[${ZNUNY_ASCII_COLOR_BLUE}mPackage::AllowNotVerifiedPackages\e[0m to: \e[${ZNUNY_ASCII_COLOR_RED}m${ZNUNY_ALLOW_NOT_VERIFIED_PACKAGES}\e[0m"  | tee -a ${upgrade_log}
  if [ "${ZNUNY_ALLOW_NOT_VERIFIED_PACKAGES}" == "yes" ]; then
    _allow=1
  fi
  ${ZNUNY_ROOT}bin/otrs.Console.pl Admin::Config::Update --setting-name Package::AllowNotVerifiedPackages --value=${_allow}
  if [ $? -gt 0  ]; then
    print_warning "Cannot enable Package::AllowNotVerifiedPackages"  | tee -a ${upgrade_log}
  fi
}
