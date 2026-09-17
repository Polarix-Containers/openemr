ARG FULL_VERSION=8.2.0.0
ARG MAJOR_VERSION=8.2.0
ARG UID=200007
ARG GID=200007
# https://github.com/openemr/openemr/actions/runs/28976847649/job/86019853872#step:11:380
ARG NODE=24
# https://github.com/openemr/openemr/blob/rel-820/docker/release/Dockerfile#L30
ARG PHP=php85



FROM alpine:latest AS openemr-source
ARG MAJOR_VERSION
RUN apk -U upgrade \
	&& apk add git perl \
	&& cd / \
	&& git clone https://github.com/openemr/openemr.git --branch "rel-$(printf '%s' "$MAJOR_VERSION" | perl -pe 's/\.//g;')" --depth 1 \
	&& rm -rf openemr/.git



FROM node:${NODE}-alpine AS openemr-assets
COPY --from=openemr-source /openemr /openemr
RUN apk -U upgrade \
	&& apk add git \
	&& npm update -g npm \
	&& cd /openemr \
	&& echo 'Installing Node.js dependencies' \
	&& npm install \
	&& npm audit fix --audit-level=none \
	&& npm run build \
	&& echo 'Installing CCDA service' \
	&& cd ccdaservice \
	&& npm install --allow-git=root \
	&& npm audit fix --audit-level=none --allow-git=root



FROM alpine:latest AS production
ARG INSTALL_DIR=/var/www/localhost/htdocs/openemr
ARG UID
ARG GID
ARG PHP

ENV APACHE_LOG_DIR=/var/log/apache2

# Import from build context
COPY --chmod=755 workaround-date.sh /usr/local/bin/date

# Import from previous build stages
COPY --from=openemr-source /openemr ${INSTALL_DIR}
COPY --from=openemr-assets --parents /openemr/./public /openemr/./ccdaservice ${INSTALL_DIR}/

# Install Composer
COPY --from=docker.io/composer/composer:latest-bin /composer /usr/bin/composer

WORKDIR ${INSTALL_DIR}

# Install dependencies
RUN apk -U upgrade \
	&& echo 'Installing dependencies via apk' \
	&& apk add libstdc++ \
		apache2 apache2-proxy apache2-ssl apache2-utils bash curl dcron imagemagick mariadb-client \
		mariadb-connector-c ncurses openssl openssl-dev perl rsync shadow tar \
		${PHP} \
		${PHP}-apache2 \
		${PHP}-bcmath \
		${PHP}-calendar \
		${PHP}-ctype \
		${PHP}-curl \
		${PHP}-dom \
		${PHP}-fileinfo \
		${PHP}-fpm \
		${PHP}-gd \
		${PHP}-iconv \
		${PHP}-intl \
		${PHP}-ldap \
		${PHP}-mbstring \
		${PHP}-mysqli \
		${PHP}-openssl \
		${PHP}-pdo \
		${PHP}-pdo_mysql \
		${PHP}-pecl-apcu \
		${PHP}-pecl-imagick \
		${PHP}-phar \
		${PHP}-redis \
		${PHP}-session \
		${PHP}-simplexml \
		${PHP}-soap \
		${PHP}-sockets \
		${PHP}-sodium \
		${PHP}-tokenizer \
		${PHP}-xml \
		${PHP}-xmlreader \
		${PHP}-xmlwriter \
		${PHP}-xsl \
		${PHP}-zip \
		${PHP}-zlib \
	&& rm -rf /var/cache/apk/* \
	# Recreate the /usr/bin/php symlink for our desired PHP version (Alpine points it to one
	# specific PHP version per Alpine release)
	&& rm -f /usr/bin/php && ln -s /usr/bin/${PHP} /usr/bin/php \
	&& echo 'Installing dependencies via Composer' \
	&& composer install --no-dev --optimize-autoloader --apcu-autoloader \
	&& composer clearcache

RUN --network=none \
	echo 'Setting up OpenEMR and Apache' \
	&& usermod -u ${UID} apache \
	&& groupmod -g ${GID} apache \
	&& sed -i 's/^Listen 80$/Listen 0.0.0.0:80/' /etc/apache2/httpd.conf \
	&& cd ${INSTALL_DIR}/docker/release/ \
	&& chmod 644 php.ini && mv php.ini /etc/$PHP/ \
	&& chmod 644 openemr.conf && mv openemr.conf /etc/apache2/conf.d/ \
	&& mv openemr.sh ssl.sh xdebug.sh auto_configure.php ${INSTALL_DIR}/ \
	&& mv utilities/* upgrade/* /root/ \
	&& cd ${INSTALL_DIR}/ \
	&& mkdir -p /etc/ssl/certs /etc/ssl/private \
	&& sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/httpd.conf \
	&& sed -i 's/^ *ErrorLog/#ErrorLog/' /etc/apache2/httpd.conf \
	&& sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/conf.d/ssl.conf \
	&& sed -i 's/^ *TransferLog/#TransferLog/' /etc/apache2/conf.d/ssl.conf \
	&& mkdir -p /run/apache2 \
	&& echo 'Setting file and directory permissions' \
	&& chown -R apache . \
	&& find . -type d -not -path "./sites/default/documents/*" -not -perm 500 -exec chmod 500 {} \+ \
	&& find . -type f -not -path "./sites/default/documents/*" -not -perm 400 -exec chmod 400 {} \+ \
	&& find sites/default/documents -not -perm 700 -exec chmod 700 {} \+ \
	&& chmod 666 sites/default/sqlconf.php \
	&& chmod 000 auto_configure.php /root/unlock_admin.php \
	&& chmod 555 *.sh /root/*.sh \
	&& chmod 755 /root/ \
	&& chmod 444 /root/devtoolsLibrary.source /root/docker-version \
	&& echo 'Installing Swarm templates' \
	&& mkdir /swarm-pieces \
	&& rsync --owner --group --perms --delete --recursive --links /etc/ssl /swarm-pieces/ \
	&& rsync --owner --group --perms --delete --recursive --links /var/www/localhost/htdocs/openemr/sites /swarm-pieces/ \
	&& rm -rf /tmp # Clean up trash

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

VOLUME [ "/etc/ssl" ]
CMD [ "./openemr.sh" ]

LABEL maintainer="Thien Tran contact@tommytran.io"
