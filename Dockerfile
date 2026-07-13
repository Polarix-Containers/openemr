ARG FULL_VERSION=8.0.0.3
ARG MAJOR_VERSION=8.0.0
ARG UID=200007
ARG GID=200007
# https://github.com/openemr/openemr/actions/runs/22974229834/job/66698628011#step:6:370
ARG NODE=22
# https://github.com/openemr/openemr/blob/rel-800/docker/release/Dockerfile#L11
ARG PHP=php84

FROM node:${NODE}-alpine
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
        apache2 apache2-proxy apache2-ssl apache2-utils curl dcron git imagemagick mariadb-client \
        mariadb-connector-c ncurses openssl openssl-dev perl rsync shadow tar \
        ${PHP} ${PHP}-apache2 ${PHP}-bcmath ${PHP}-calendar ${PHP}-ctype ${PHP}-curl ${PHP}-dom \
        ${PHP}-fileinfo ${PHP}-fpm ${PHP}-gd ${PHP}-iconv ${PHP}-intl ${PHP}-json ${PHP}-ldap \
        ${PHP}-mbstring ${PHP}-mysqli ${PHP}-opcache ${PHP}-openssl ${PHP}-pdo ${PHP}-pdo_mysql \
        ${PHP}-pecl-apcu ${PHP}-pecl-imagick ${PHP}-phar ${PHP}-redis ${PHP}-session \
        ${PHP}-simplexml ${PHP}-soap ${PHP}-sockets ${PHP}-sodium ${PHP}-tokenizer ${PHP}-xml \
        ${PHP}-xmlreader ${PHP}-xmlwriter ${PHP}-xsl ${PHP}-zip ${PHP}-zlib \
        # Adding make separately from build-base here cuz we wanna keep it later
        build-base make \
    && sed -i 's/^Listen 80$/Listen 0.0.0.0:80/' /etc/apache2/httpd.conf \
    && rm -rf /var/cache/apk/* \
    && npm update -g npm

RUN --network=none \
    usermod -u ${UID} apache \
    && groupmod -g ${GID} apache

# Alpine hard coded the symlink only for specific php version on specific Alpine release, which is not very nice.
# We are just removing the symlink and create it here so the code is easy to copy-paste.

RUN rm -f /usr/bin/php \
    && ln -s /usr/bin/${PHP} /usr/bin/php \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \
    && git clone https://github.com/openemr/openemr.git --branch "rel-$(printf '%s' "$MAJOR_VERSION" | perl -pe 's/\.//g;')" --depth 1 \
    && rm -rf openemr/.git \
    && cd openemr \
    && composer install --no-dev \
    && npm install \
    && npm audit fix --audit-level=none \
    && npm run build \
    && cd ccdaservice \
    && npm install \
    && npm audit fix --audit-level=none \
    && cd ../ \
    && composer global require phing/phing \
    && /root/.composer/vendor/bin/phing vendor-clean \
    && /root/.composer/vendor/bin/phing assets-clean \
    && composer global remove phing/phing \
    && composer dump-autoload --optimize --apcu \
    && composer clearcache \
    && npm cache clear --force \
    && rm -fr node_modules \
    && cd docker/release/ \
    && chmod 644 php.ini && mv php.ini /etc/$PHP/ \
    && chmod 644 openemr.conf && mv openemr.conf /etc/apache2/conf.d/ \
    && mv openemr.sh ssl.sh xdebug.sh auto_configure.php ../../ \
    && mv utilities/* upgrade/* /root/ \
    && cd ../../../ \
    && mv openemr /var/www/localhost/htdocs/ \
    && mkdir -p /etc/ssl/certs /etc/ssl/private \
    && apk del --no-cache build-base \
    && sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/httpd.conf \
    && sed -i 's/^ *ErrorLog/#ErrorLog/' /etc/apache2/httpd.conf \
    && sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/conf.d/ssl.conf \
    && sed -i 's/^ *TransferLog/#TransferLog/' /etc/apache2/conf.d/ssl.conf

WORKDIR /var/www/localhost/htdocs/openemr

#Fix issue with apache2 dying prematurely
RUN mkdir -p /run/apache2

#Set file and directory permissions
RUN chown -R apache . \
    && find . -type d -not -path "./sites/default/documents/*" -not -perm 500 -exec chmod 500 {} \+ \
    && find . -type f -not -path "./sites/default/documents/*" -not -perm 400 -exec chmod 400 {} \+ \
    && find sites/default/documents -not -perm 700 -exec chmod 700 {} \+ \
    && chmod 666 sites/default/sqlconf.php \
    && chmod 000 auto_configure.php /root/unlock_admin.php \
    && chmod 500 *.sh /root/*.sh \
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
