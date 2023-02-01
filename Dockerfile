FROM python:3.10-alpine
RUN apk update && apk add \
    mariadb-dev \
    unzip \
    git \
    curl \
    openssl-dev \
    bzip2-dev \
    libffi-dev \
    gcc \
    musl-dev \
    linux-headers
RUN pip install --upgrade pip
RUN pip install wheel gunicorn flower
ARG AA_VERSION
RUN [[ -z "${AA_VERSION}" ]] && pip install allianceauth || pip install allianceauth==${AA_VERSION}
RUN mkdir -p /home/allianceserver
RUN cd /home/allianceserver && allianceauth start myauth
RUN cd /home/allianceserver && allianceauth update myauth
RUN mkdir -p /var/www/myauth/static
RUN pip install supervisor
RUN pip install -U git+https://github.com/shaib/supervisor-stdout.git@patch-1
COPY /conf/supervisord.conf /usr/local/etc/supervisord.conf
WORKDIR /home/allianceserver/myauth
EXPOSE 8000
EXPOSE 5555
CMD ["/usr/local/bin/supervisord"]
