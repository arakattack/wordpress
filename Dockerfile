FROM wordpress:6.4.3-php8.2-fpm

RUN apt-get update && apt dist-upgrade -y && apt-get install gnupg2 -y
RUN touch /etc/apt/sources.list.d/pgdg.list
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" >> /etc/apt/sources.list.d/pgdg.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8

RUN apt-get update && apt dist-upgrade -y --allow-unauthenticated && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated

# PHP pdo extensions
RUN docker-php-ext-configure pdo_mysql \
    && docker-php-ext-configure mysqli \
    && docker-php-ext-install pdo pdo_mysql \
    && docker-php-ext-enable pdo_mysql

# tweak php-fpm config
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/pm.max_children = 5/pm.max_children = 40/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/pm.start_servers = 2/pm.start_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 25/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/;pm.max_requests = 500/pm.max_requests = 900/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/;pm.status_path/pm.status_path/g" /usr/local/etc/php-fpm.d/www.conf

# Install phpredis
RUN pecl install redis && docker-php-ext-enable redis

# Memory Limit
RUN echo "memory_limit=256M" > $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "max_execution_time=900" >> $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "post_max_size=20M" >> $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "upload_max_filesize=20M" >> $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "max_input_vars=8000" > $PHP_INI_DIR/conf.d/max-input-vars.ini

# Time Zone
RUN echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini
# Display errors in stderr
RUN echo "display_errors=stderr" > $PHP_INI_DIR/conf.d/display-errors.ini

RUN curl -Os https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    unzip && \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/*

# HACK: `101` is the user id of `nginx` user in `nginx:x.x.x-alpine` Docker image
# https://stackoverflow.com/questions/36824222/how-to-change-the-nginx-process-user-of-the-official-docker-image-nginx
RUN usermod -u 101 www-data && \
    groupmod -g 101 www-data

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
