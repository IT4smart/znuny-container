FROM debian:bookworm-slim

LABEL maintainer="Raphael Lekies <raphael.lekies@it4smart.com> (IT4smart GmbH)"

ENV ZNUNY_VERSION 7.3.1
ENV ZNUNY_ROOT "/opt/znuny/"
ENV ZNUNY_CONFIG_MOUNT_DIR "/Kernel"
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV DEBIAN_FRONTEND noninteractive

WORKDIR /opt/znuny

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apache2 \
        tar \
        libapache2-mod-perl2 \
        libdbd-mysql-perl \
        libtimedate-perl \
        libnet-dns-perl \
        libnet-ldap-perl \
        libio-socket-ssl-perl \
        libpdf-api2-perl \
        libsoap-lite-perl \
        libtext-csv-xs-perl \
        libjson-xs-perl \
        libapache-dbi-perl \
        libxml-libxml-perl \
        libxml-libxslt-perl \
        libyaml-perl \
        libarchive-zip-perl \
        libcrypt-eksblowfish-perl \
        libencode-hanextra-perl \
        libmail-imapclient-perl \
        libtemplate-perl \
        libdatetime-perl \
        libmoo-perl \
        bash-completion \
        libyaml-libyaml-perl \
        libjavascript-minifier-xs-perl \
        libcss-minifier-xs-perl \
        libauthen-sasl-perl \
        libauthen-ntlm-perl \
        libhash-merge-perl \
        libical-parser-perl \
        libspreadsheet-xlsx-perl \
        libdata-uuid-perl \
        supervisor \
        cron \
        curl \
        openssl \
        libcap2-bin \
        mariadb-client \
        libxml2-dev \
        xmlsec1 \
        libxmlsec1-dev \
        cpanminus \
    && cpanm Net::SAML2 XML::Sec XML::LibXML \
    && curl -fsSL https://download.znuny.org/releases/znuny-${ZNUNY_VERSION}.tar.gz --output /tmp/znuny.tar.gz \
    && tar -xzf /tmp/znuny.tar.gz -C /opt/znuny --strip-components=1 \
    && cp /opt/znuny/Kernel/Config.pm.dist /opt/znuny/Kernel/Config.pm \
    && useradd -r -m -d /opt/znuny -c "ZNUNY user" -G www-data znuny \
    && /opt/znuny/bin/otrs.CheckModules.pl || true \
    && /opt/znuny/bin/znuny.SetPermissions.pl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && ln -s /opt/znuny/scripts/apache2-httpd.include.conf /etc/apache2/conf-available/znuny.conf \
    && sed -i 's/DirectoryIndex index.html/DirectoryIndex index.pl index.html/' /etc/apache2/mods-enabled/dir.conf \
    && a2dismod mpm_event \
    && a2enmod mpm_prefork headers filter perl \
    && a2enmod ssl rewrite \
    && a2enconf znuny \
    && sed -i -e 's/^[[:space:]]*Listen 80$/Listen 8080/' -e 's/^[[:space:]]*Listen 443$/Listen 8443/' /etc/apache2/ports.conf \
    && sed -i 's/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER=znuny/' /etc/apache2/envvars \
    && sed -i 's/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=znuny/' /etc/apache2/envvars \
    && setcap cap_net_bind_service=+ep /usr/sbin/apache2

COPY files/supervisord-main.conf /etc/supervisor/supervisord.conf
COPY files/supervisord.conf /etc/supervisor/conf.d/znuny.conf
COPY files/apache-logging.conf /etc/apache2/conf-available/apache-logging.conf
COPY files/znuny-site.conf /etc/apache2/sites-available/znuny-site.conf
COPY files/run.sh /run.sh
COPY files/functions.sh /functions.sh
COPY files/util_functions.sh /util_functions.sh

RUN a2enconf apache-logging \
    && a2dissite 000-default default-ssl || true \
    && a2ensite znuny-site \
    && touch ${ZNUNY_ROOT}var/tmp/firsttime \
    && mkdir -p /etc/ssl/znuny /etc/apache2/sites-available /etc/apache2/sites-enabled /tmp/supervisor \
    && chown -R znuny:znuny /etc/ssl/znuny /etc/apache2/sites-available /etc/apache2/sites-enabled /tmp/supervisor \
    && chmod 755 /etc/ssl/znuny /etc/apache2/sites-available /etc/apache2/sites-enabled /tmp/supervisor \
    && chmod 1777 /run \
    && mv /opt/znuny/Kernel /Kernel \
    && chown -R znuny:znuny /var/log/apache2 \
    && ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log \
    && chown -R znuny:znuny /var/run/apache2

USER znuny

WORKDIR /opt/znuny/var/cron

RUN for foo in *.dist; do cp $foo `basename $foo .dist`; done

WORKDIR /opt/znuny

CMD ["/run.sh"]
