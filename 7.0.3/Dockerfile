ARG FULL_VERSION=7.0.3.4
ARG MAJOR_VERSION=7.0.3
ARG UID=200007
ARG GID=200007
#ARG NODE=20
ARG PHP=php83

#FROM node:${NODE}-alpine
FROM alpine
ARG FULL_VERSION
ARG MAJOR_VERSION
ARG UID
ARG GID
ARG PHP

ENV APACHE_LOG_DIR=/var/log/apache2

LABEL maintainer="Thien Tran contact@tommytran.io"

#Install dependencies and fix issue in apache
RUN apk -U upgrade \
    && apk add libstdc++ \
        apache2 apache2-ssl apache2-utils apache2-proxy git ${PHP} ${PHP}-tokenizer ${PHP}-ctype ${PHP}-session ${PHP}-apache2 \
        ${PHP}-json ${PHP}-pdo ${PHP}-pdo_mysql ${PHP}-curl ${PHP}-ldap ${PHP}-openssl ${PHP}-iconv \
        ${PHP}-xml ${PHP}-xsl ${PHP}-gd ${PHP}-zip ${PHP}-soap ${PHP}-mbstring ${PHP}-zlib \
        ${PHP}-mysqli ${PHP}-sockets ${PHP}-xmlreader ${PHP}-redis ${PHP}-simplexml ${PHP}-xmlwriter ${PHP}-phar ${PHP}-fileinfo \
        ${PHP}-sodium ${PHP}-calendar ${PHP}-intl ${PHP}-opcache ${PHP}-pecl-apcu ${PHP}-fpm \
        perl mysql-client mariadb-connector-c tar curl imagemagick \
        openssl openssl-dev dcron \
        rsync shadow ncurses \
        # Adding make separately from build-base here cuz we wanna keep it later
        build-base make \
    && sed -i 's/^Listen 80$/Listen 0.0.0.0:80/' /etc/apache2/httpd.conf \
    && rm -rf /var/cache/apk/*
#    && npm update -g npm

RUN --network=none \
    usermod -u ${UID} apache \
    && groupmod -g ${GID} apache

# Alpine hard coded the symlink only for specific php version on specific Alpine release, which is not very nice.
# We are just removing the symlink and create it here so the code is easy to copy-paste.

RUN rm -f /usr/bin/php \
    && ln -s /usr/bin/${PHP} /usr/bin/php \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \
    && git clone https://github.com/openemr/openemr.git --branch v$(echo $FULL_VERSION | sed 's/\./_/g') --depth 1 \
    && rm -rf openemr/.git \
    && cd openemr \
    && composer install --no-dev \
#    && npm install --unsafe-perm \
#    && npm audit fix --audit-level=none \
#    && npm run build \
#    && cd ccdaservice \
#    && npm install --unsafe-perm \
#    && npm audit fix --audit-level=none \
#    && cd ../ \
    && composer global require phing/phing \
    && /root/.composer/vendor/bin/phing vendor-clean \
    && /root/.composer/vendor/bin/phing assets-clean \
    && composer global remove phing/phing \
    && composer dump-autoload --optimize --apcu \
    && composer clearcache \
#    && npm cache clear --force \
    && rm -fr node_modules \
    && cd ../ \
    && mv openemr /var/www/localhost/htdocs/ \
    && mkdir -p /etc/ssl/certs /etc/ssl/private \
    && apk del --no-cache git build-base \
    && sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/httpd.conf \
    && sed -i 's/^ *ErrorLog/#ErrorLog/' /etc/apache2/httpd.conf \
    && sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/conf.d/ssl.conf \
    && sed -i 's/^ *TransferLog/#TransferLog/' /etc/apache2/conf.d/ssl.conf

WORKDIR /var/www/localhost/htdocs/openemr

#configure apache & php properly
ADD --chmod=644 https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/php.ini /etc/${PHP}/php.ini
ADD --chmod=644 https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/openemr.conf /etc/apache2/conf.d/

#add runner and auto_configure and prevent auto_configure from being run w/o being enabled
ADD https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/openemr.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/ssl.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/xdebug.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/auto_configure.php .

ADD https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/utilities/devtoolsLibrary.source \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/utilities/unlock_admin.php \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/utilities/unlock_admin.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/ssl.sh /root
    
RUN chmod 500 *.sh /root/unlock_admin.sh \
    && chmod 000 auto_configure.php /root/unlock_admin.php

#Bring in pieces used for automatic upgrade process
ADD https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/upgrade/docker-version \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/upgrade/fsupgrade-1.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/upgrade/fsupgrade-2.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/upgrade/fsupgrade-3.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/upgrade/fsupgrade-4.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/upgrade/fsupgrade-5.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/upgrade/fsupgrade-6.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${MAJOR_VERSION}/upgrade/fsupgrade-7.sh /root

RUN chmod 500 /root/fs*

#Fix issue with apache2 dying prematurely
RUN mkdir -p /run/apache2

#Set file and directory permissions
RUN chown -R apache /var/www/localhost/htdocs/openemr/ \
    && find . -type d -not -path "./sites/default/documents/*" -not -perm 500 -exec chmod 500 {} \+ \
    && find . -type f -not -path "./sites/default/documents/*" -not -path './openemr.sh' -not -perm 400 -exec chmod 400 {} \+ \
    && chmod 500 openemr.sh /root/ssl.sh \
    && find sites/default/documents -not -perm 700 -exec chmod 700 {} \+ \
    && chmod 666 sites/default/sqlconf.php \
    && chmod 755 /root/ \
    && chmod 444 /root/devtoolsLibrary.source /root/docker-version

#Ensure swarm/orchestration pieces are available if needed
RUN mkdir /swarm-pieces \
    && rsync --owner --group --perms --delete --recursive --links /etc/ssl /swarm-pieces/ \
    && rsync --owner --group --perms --delete --recursive --links /var/www/localhost/htdocs/openemr/sites /swarm-pieces/

#Clean up trash
RUN rm -rf /tmp

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

VOLUME [ "/etc/ssl" ]
CMD [ "./openemr.sh" ]
