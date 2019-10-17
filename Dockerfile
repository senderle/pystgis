FROM python:3.6-alpine3.9

ENV PYTHONUNBUFFERED 1

RUN apk update \
  # psycopg2 dependencies
  && apk add --virtual build-deps gcc python3-dev musl-dev \
  && apk add postgresql-dev \
  # Pillow dependencies
  && apk add jpeg-dev zlib-dev freetype-dev lcms2-dev openjpeg-dev tiff-dev tk-dev tcl-dev \
  # CFFI dependencies
  && apk add libffi-dev py-cffi \
  # Translations dependencies
  && apk add gettext \
  # https://docs.djangoproject.com/en/dev/ref/django-admin/#dbshell
  && apk add postgresql-client

## Build Postgis and dependencies

# Unfortunately the alpine postgis packages are broken at the moment
# due to an ABI incompatibility of some kind, so we have to compile a
# bunch of dependencies. This will be very slow.

ENV PROJ_VERSION 6.2.0
ENV PROJ_MD5 5cde556545828beaffbe50b1bb038480
ENV GDAL_VERSION 3.0.1
ENV GDAL_MD5 2b397c041e6b0b10ec7c49fd76e9fa99
ENV POSTGIS_VERSION 2.5.3
ENV POSTGIS_SHA256 402323c83d97f3859bc9083345dd687f933c261efe0830e1262c20c12671f794

# Fetch source for proj, gdal, postgis
RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
       ca-certificates \
       openssl \
       tar \
    \
    && wget -O proj.tar.gz "https://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz" \
    && echo "$PROJ_MD5 *proj.tar.gz" | md5sum -c - \
    && mkdir -p /usr/src/proj \
    && tar \
        --extract \
        --file proj.tar.gz \
        --directory /usr/src/proj \
        --strip-components 1 \
    && rm proj.tar.gz \
    \
    && wget -O gdal.tar.gz "https://github.com/OSGeo/gdal/releases/download/v$GDAL_VERSION/gdal-$GDAL_VERSION.tar.gz" \
    && echo "$GDAL_MD5 *gdal.tar.gz" | md5sum -c - \
    && mkdir -p /usr/src/gdal \
    && tar \
        --extract \
        --file gdal.tar.gz \
        --directory /usr/src/gdal \
        --strip-components 1 \
    && rm gdal.tar.gz \
    \ 
    && wget -O postgis.tar.gz "https://github.com/postgis/postgis/archive/$POSTGIS_VERSION.tar.gz" \
    && echo "$POSTGIS_SHA256 *postgis.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/postgis \
    && tar \
        --extract \
        --file postgis.tar.gz \
        --directory /usr/src/postgis \
        --strip-components 1 \
    && rm postgis.tar.gz \
    \
    && apk del .fetch-deps

# Build and install proj, gdal, postgis
RUN apk add --no-cache --virtual .build-deps \
        autoconf \
        automake \
        g++ \
        json-c-dev \
        libtool \
        libxml2-dev \
        make \
        perl \
        linux-headers \
    \
    # Proj
    && apk add --no-cache --virtual .build-deps-testing \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        sqlite-dev \
        sqlite \
        geos-dev \
        protobuf-c-dev \
    \
    && cd /usr/src/proj \
    && ./configure \
    && make \
    && make install \
    && cd / \
    \
    # add libcrypto from (edge:main) for gdal
    && apk add --no-cache --virtual .crypto-rundeps \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
        libressl2.7-libcrypto \
    \
    # GDAL
    && cd /usr/src/gdal \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install \
    && cd / \
    \
    # Postgis
    && cd /usr/src/postgis \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install \
    && cd / \
    \
    # Postgis runtime dependencies
    && apk add --no-cache --virtual .postgis-rundeps \
        json-c \
    \
    && apk add --no-cache --virtual .postgis-run \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \    
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \        
        geos \
        protobuf-c \
    \
    # Cleanup
    && cd / \
    && rm -rf /usr/src/proj \
    && rm -rf /usr/src/gdal \
    && rm -rf /usr/src/postgis \
    && apk del .build-deps .build-deps-testing
