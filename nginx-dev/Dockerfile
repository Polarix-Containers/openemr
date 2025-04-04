ARG VERSION=7.0.3
ARG TAG=v7_0_3_1
ARG UID=200007
ARG GID=200007
ARG NODE=20
ARG PHP=php83

FROM node:${NODE}-alpine
ARG VERSION
ARG TAG
ARG UID
ARG GID
ARG PHP

LABEL maintainer="Thien Tran contact@tommytran.io"

#Install dependencies
RUN apk -U upgrade \
    && apk add libstdc++ \
        git ${PHP} ${PHP}-tokenizer ${PHP}-ctype ${PHP}-session \
        ${PHP}-json ${PHP}-pdo ${PHP}-pdo_mysql ${PHP}-curl ${PHP}-ldap ${PHP}-openssl ${PHP}-iconv \
        ${PHP}-xml ${PHP}-xsl ${PHP}-gd ${PHP}-zip ${PHP}-soap ${PHP}-mbstring ${PHP}-zlib \
        ${PHP}-mysqli ${PHP}-sockets ${PHP}-xmlreader ${PHP}-redis ${PHP}-simplexml ${PHP}-xmlwriter ${PHP}-phar ${PHP}-fileinfo \
        ${PHP}-sodium ${PHP}-calendar ${PHP}-intl ${PHP}-opcache ${PHP}-pecl-apcu ${PHP}-fpm \
        perl mysql-client mariadb-connector-c tar curl imagemagick \
        openssl openssl-dev dcron \
        rsync shadow ncurses \
        # Adding make separately from build-base here cuz we wanna keep it later
        build-base make \
    && rm -rf /var/cache/apk/* \
    && npm update -g npm

# Alpine hard coded the symlink only for specific php version on specific Alpine release, which is not very nice.
# We are just removing the symlink and create it here so the code is easy to copy-paste.

RUN rm -f /usr/bin/php \
    && ln -s /usr/bin/${PHP} /usr/bin/php \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \
    && git clone https://github.com/openemr/openemr.git --branch ${TAG} --depth 1 \
    && rm -rf openemr/.git \
    && cd openemr \
    && composer install --no-dev \
    && npm install --unsafe-perm \
    && npm audit fix --audit-level=none \
    && npm run build \
    && cd ccdaservice \
    && npm install --unsafe-perm \
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
    && cd ../ \
    && mv openemr /var/www/localhost/htdocs/ \
    && apk del --no-cache git build-base

WORKDIR /var/www/localhost/htdocs/openemr

#configure apache & php properly
ADD --chmod=644 https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/php.ini /etc/${PHP}/php.ini

#add runner and auto_configure and prevent auto_configure from being run w/o being enabled
ADD https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/openemr.sh \
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
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/upgrade/fsupgrade-6.sh \
    https://raw.githubusercontent.com/openemr/openemr-devops/refs/heads/master/docker/openemr/${VERSION}/upgrade/fsupgrade-7.sh /root

RUN chmod 500 /root/fs*

#Set file and directory permissions
RUN chown -R php-fpm /var/www/localhost/htdocs/openemr/ \
    && find . -type d -not -path "./sites/default/documents/*" -not -perm 500 -exec chmod 500 {} \+ \
    && find . -type f -not -path "./sites/default/documents/*" -not -path './openemr.sh' -not -perm 400 -exec chmod 400 {} \+ \
    && chmod 500 openemr.sh \
    && find sites/default/documents -not -perm 700 -exec chmod 700 {} \+ \
    && chmod 666 sites/default/sqlconf.php \
    && chmod 755 /root/ \
    && chmod 444 /root/devtoolsLibrary.source /root/docker-version

#Clean up trash
RUN rm -rf /tmp

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

CMD [ "./openemr.sh" ]
