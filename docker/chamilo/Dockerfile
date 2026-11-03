# Imagen de Chamilo 1.11.x sobre php:<version>-apache
# La construye UNA sola vez Integrante 2; todas las replicas usan esta misma imagen.
ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-apache

ARG CHAMILO_URL
ARG CHAMILO_SHA256

# 1) Librerias y extensiones PHP que pide el instalador de Chamilo 1.11
#    (mbstring, curl, xml, fileinfo, iconv, session y zlib ya vienen en la imagen php)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl unzip \
        libpng-dev libjpeg-dev libfreetype6-dev libicu-dev libzip-dev libxml2-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" gd intl zip pdo_mysql mysqli opcache soap; \
    a2enmod rewrite headers; \
    rm -rf /var/lib/apt/lists/*

# 2) Descargar el paquete oficial, verificar su SHA-256 y copiarlo a /var/www/html
RUN set -eux; \
    : "${CHAMILO_URL:?Defina CHAMILO_URL en .env}"; \
    : "${CHAMILO_SHA256:?Defina CHAMILO_SHA256 en .env}"; \
    curl -fsSL "$CHAMILO_URL" -o /tmp/chamilo.zip; \
    echo "${CHAMILO_SHA256}  /tmp/chamilo.zip" | sha256sum -c -; \
    mkdir /tmp/chamilo; \
    unzip -q /tmp/chamilo.zip -d /tmp/chamilo; \
    RAIZ="$(dirname "$(dirname "$(find /tmp/chamilo -maxdepth 4 -type d -path '*/main/install' | head -n 1)")")"; \
    test -f "$RAIZ/main/install/index.php"; \
    cp -a "$RAIZ"/. /var/www/html/; \
    rm -rf /tmp/chamilo /tmp/chamilo.zip /var/www/html/tests; \
    chown -R www-data:www-data /var/www/html

# 3) Carpeta de sesiones PHP (se monta como volumen compartido entre replicas)
RUN mkdir -p /sessions && chown www-data:www-data /sessions && chmod 0770 /sessions

# 4) Configuracion de PHP y de Apache (dentro del contenedor)
COPY chamilo.ini /usr/local/etc/php/conf.d/chamilo.ini
COPY chamilo-apache.conf /etc/apache2/conf-available/chamilo.conf
RUN a2enconf chamilo

EXPOSE 80
