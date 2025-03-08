FROM python:3.11-slim
ARG AA_VERSION=4.6.4
ENV VIRTUAL_ENV=/opt/venv
ENV AUTH_USER=allianceserver
ENV AUTH_GROUP=allianceserver
ENV AUTH_USERGROUP=${AUTH_USER}:${AUTH_GROUP}
ENV STATIC_BASE=/var/www
ENV AUTH_HOME=/home/allianceserver

# Setup user and directory permissions
SHELL ["/bin/bash", "-c"]
RUN groupadd -g 61000 ${AUTH_GROUP}
RUN useradd -g 61000 -l -M -s /bin/false -u 61000 ${AUTH_USER}
RUN mkdir -p ${VIRTUAL_ENV} \
    && chown ${AUTH_USERGROUP} ${VIRTUAL_ENV} \
    && mkdir -p ${STATIC_BASE} \
    && chown ${AUTH_USERGROUP} ${STATIC_BASE} \
    && mkdir -p ${AUTH_HOME} \
    && chown ${AUTH_USERGROUP} ${AUTH_HOME}

# Install build dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    libmariadb-dev gcc supervisor git htop pkg-config

# Copy migrate script
COPY migrate.sh $AUTH_HOME
RUN chown ${AUTH_USERGROUP} $AUTH_HOME/migrate.sh
RUN chmod u+x $AUTH_HOME/migrate.sh

# Switch to non-root user
USER ${AUTH_USER}
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
WORKDIR ${AUTH_HOME}

# Install python dependencies
RUN pip install --upgrade pip
RUN pip install wheel gunicorn flower gevent
RUN pip install allianceauth==${AA_VERSION}
ENV SITE_PACKAGES_PATH="$VIRTUAL_ENV/lib/python3.11/site-packages/"

# Install AA extension apps
RUN pip install aa-freight aa-corpstats-two allianceauth-signal-pings \
                allianceauth-securegroups aa-esi-status fittings \
                django-eveuniverse aa-structures  allianceauth-afat \
                aa-moonmining aa-charlink aa-taskmonitor discordproxy \
                aa-discordnotify ts3 aa-srp aa-structuretimers aa-package-monitor \
                allianceauth-oidc-provider allianceauth-invoices
RUN pip install -U git+https://github.com/pvyParts/allianceauth-corp-tools.git

COPY patches ${AUTH_HOME}
RUN for i in ${AUTH_HOME}/*.patch; do patch -p1 -d "$SITE_PACKAGES_PATH" < $i || exit 1; done

# Initialize auth
RUN allianceauth start myauth
RUN allianceauth update myauth
RUN mkdir -p ${STATIC_BASE}/myauth/static

# Switch to root
USER root

# Copy static
COPY static/ $AUTH_HOME/myauth/myauth/static/
RUN chown -R ${AUTH_USERGROUP} $AUTH_HOME/myauth/myauth/static/

# Copy custom templates
COPY templates/ $AUTH_HOME/myauth/myauth/templates/
RUN chown -R ${AUTH_USERGROUP} $AUTH_HOME/myauth/myauth/templates/

# Switch to non-root user
USER ${AUTH_USER}

COPY /conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN echo 'alias auth="python $AUTH_HOME/myauth/manage.py"' >> ~/.bashrc && \
    echo 'alias supervisord="supervisord -c /etc/supervisor/conf.d/supervisord.conf"' >> ~/.bashrc && \
    echo "source ${VIRTUAL_ENV}/bin/activate" >> ~/.bashrc && \
    source ~/.bashrc


WORKDIR /home/allianceserver/myauth
EXPOSE 8000
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
