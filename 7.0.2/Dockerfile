ARG VERSION=7.0.2
ARG UID=200007
ARG GID=200007
ARG NODE=18
ARG PHP=php82

FROM node:${NODE}-alpine
ARG VERSION
ARG UID
ARG GID
ARG PHP

ENV APACHE_LOG_DIR=/var/log/apache2

LABEL maintainer="Thien Tran contact@tommytran.io"

#Install dependencies and fix issue in apache
RUN apk -U upgrade \
    && apk add libstdc++ \
        apache2 apache2-ssl apache2-utils git ${PHP} ${PHP}-tokenizer ${PHP}-ctype ${PHP}-session ${PHP}-apache2 \
        ${PHP}-json ${PHP}-pdo ${PHP}-pdo_mysql ${PHP}-curl ${PHP}-ldap ${PHP}-openssl ${PHP}-iconv \
        ${PHP}-xml ${PHP}-xsl ${PHP}-gd ${PHP}-zip ${PHP}-soap ${PHP}-mbstring ${PHP}-zlib \
        ${PHP}-mysqli ${PHP}-sockets ${PHP}-xmlreader ${PHP}-redis ${PHP}-simplexml ${PHP}-xmlwriter ${PHP}-phar ${PHP}-fileinfo \
        ${PHP}-sodium ${PHP}-calendar ${PHP}-intl ${PHP}-opcache ${PHP}-pecl-apcu \
        perl mysql-client tar curl imagemagick \
        certbot openssl openssl-dev dcron \
        rsync shadow ncurses \
    && sed -i 's/^Listen 80$/Listen 0.0.0.0:80/' /etc/apache2/httpd.conf \
    && rm -rf /var/cache/apk/*


RUN --network=none \
    usermod -u ${UID} apache \
    && groupmod -g ${GID} apache \
    && find / -user 1000 -exec chown -h apache {} \; \
    && find / -group 1000 -exec chgrp -h apache {} \;
    
#BELOW LINE NEEDED TO SUPPORT PHP8 ON ALPINE 3.13+; SHOULD BE ABLE TO REMOVE THIS IN FUTURE ALPINE VERSIONS
RUN ln -s /usr/bin/${PHP} /usr/bin/php
# Install composer for openemr package building
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer
    
RUN apk add --no-cache git build-base \
    && git clone https://github.com/openemr/openemr.git --branch rel-703 --depth 1 \
    && rm -rf openemr/.git \
    && cd openemr \
    && composer install --no-dev \
    && npm install --unsafe-perm \
    && npm run build \
    && cd ccdaservice \
    && npm install --unsafe-perm \
    && cd ../ \
    && composer global require phing/phing \
    && /root/.composer/vendor/bin/phing vendor-clean \
    && /root/.composer/vendor/bin/phing assets-clean \
    && composer global remove phing/phing \
    && composer dump-autoload --optimize --apcu \
    && composer clearcache \
    && npm cache clear --force \
    && rm -fr node_modules \
    && cd ../ \
    && chmod 666 openemr/sites/default/sqlconf.php \
    && chown -R apache openemr/ \
    && mv openemr /var/www/localhost/htdocs/ \
    && mkdir -p /etc/ssl/certs /etc/ssl/private \
    && apk del --no-cache git build-base \
    && sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/httpd.conf \
    && sed -i 's/^ *ErrorLog/#ErrorLog/' /etc/apache2/httpd.conf \
    && sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/conf.d/ssl.conf \
    && sed -i 's/^ *TransferLog/#TransferLog/' /etc/apache2/conf.d/ssl.conf

WORKDIR /var/www/localhost/htdocs/openemr

#configure apache & php properly
ADD https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/php.ini /etc/${PHP}/php.ini
ADD https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/openemr.conf /etc/apache2/conf.d/

#add runner and auto_configure and prevent auto_configure from being run w/o being enabled
ADD https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/openemr.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/ssl.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/xdebug.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/auto_configure.php .

ADD https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/utilities/devtoolsLibrary.source \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/utilities/unlock_admin.php \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/utilities/unlock_admin.sh /root
    
RUN chmod 500 *.sh /root/unlock_admin.sh \
    && chmod 000 auto_configure.php /root/unlock_admin.php

#Bring in pieces used for automatic upgrade process
ADD https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/upgrade/docker-version \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/upgrade/fsupgrade-1.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/upgrade/fsupgrade-2.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/upgrade/fsupgrade-3.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/upgrade/fsupgrade-4.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/upgrade/fsupgrade-5.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/upgrade/fsupgrade-6.sh /root

RUN chmod 500 /root/fs*

#Fix issue with apache2 dying prematurely
RUN mkdir -p /run/apache2

#Ensure swarm/orchestration pieces are available if needed
RUN mkdir /swarm-pieces \
    && rsync --owner --group --perms --delete --recursive --links /etc/ssl /swarm-pieces/ \
    && rsync --owner --group --perms --delete --recursive --links /var/www/localhost/htdocs/openemr/sites /swarm-pieces/

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

VOLUME [ "/etc/letsencrypt/", "/etc/ssl" ]
CMD [ "./openemr.sh" ]
