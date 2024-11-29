ARG VERSION=7.0.3
ARG UID=3006
ARG GID=3006

FROM openemr/openemr:${VERSION}
ARG UID
ARG GID

LABEL maintainer="Thien Tran contact@tommytran.io"

RUN apk -U upgrade \
    && apk add libstdc++ \
    && rm -rf /var/cache/apk/*

RUN usermod -u ${UID} apache \
    && groupmod -g ${GID} apache \
    && find / -user 1000 -exec chown -h apache {} \; \
    && find / -group 1000 -exec chgrp -h apache {} \;

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"