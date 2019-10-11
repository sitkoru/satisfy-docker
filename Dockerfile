FROM php:7.2-fpm

ENV SATISFY_VERSION=dev-master
ENV APP_ROOT=/app
ENV APP_USER=satisfy
ENV PHP_INI_PATH=/usr/local/etc/php/php.ini

RUN apt update && \
    apt install -y nginx procmail libxml2-dev inotify-tools jq zip curl openssh-client git gosu

RUN curl https://getcomposer.org/installer -o composer-setup.php && php composer-setup.php --install-dir=/usr/bin --filename=composer && rm composer-setup.php

WORKDIR ${APP_ROOT}

RUN composer create-project playbloom/satisfy --no-dev . ${SATISFY_VERSION}

RUN rm /usr/local/etc/php-fpm.d/www.conf.default && rm /usr/local/etc/php-fpm.d/www.conf
COPY conf/php-fpm.conf /usr/local/etc/php-fpm.conf

RUN groupadd ${APP_USER} && useradd -d ${APP_ROOT} -g ${APP_USER} ${APP_USER};
RUN chown -R ${APP_USER}:${APP_USER} ${APP_ROOT}
RUN rm ${APP_ROOT}/app/config/parameters.yml
RUN mkdir ${APP_ROOT}/.ssh
COPY scripts/*.sh /
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/php.conf /etc/nginx/php.conf
EXPOSE 80

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "satisfy" ]
