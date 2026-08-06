FROM python:3.14-slim
ARG AA_VERSION=4.13.1
ARG AA_CHARLINK_VERSION=1.14.0
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
    libmariadb-dev gcc supervisor git htop pkg-config \
    libffi-dev libnacl-dev python3-dev

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
ENV SITE_PACKAGES_PATH="$VIRTUAL_ENV/lib/python3.12/site-packages/"

# Install AA extension apps
RUN pip install allianceauth==${AA_VERSION} \
                aa-freight==2.0.0 aa-corpstats-two==1.1.7 allianceauth-signal-pings==0.0.12 \
                allianceauth-securegroups==0.10.1 aa-esi-status==3.3.5 fittings==2.3.2 \
                django-eveuniverse==2.0.0 aa-structures==4.0.0  allianceauth-afat==5.1.0 \
                aa-moonmining==3.0.0 aa-charlink==${AA_CHARLINK_VERSION} aa-taskmonitor==1.0.0 discordproxy==1.4.0 \
                aa-discordnotify==3.0.0 ts3==1.0.11 aa-srp==4.3.0 aa-structuretimers==3.0.0 aa-package-monitor==3.0.0 \
                allianceauth-invoices==0.1.9 pyjwt==2.13.0 django-cors-headers==4.9.0 py-cord==2.8.0 py-cord[voice]==2.8.0 django-eveonline-sde==0.0.1b9 \
                allianceauth-app-utils==1.31.0 django-esi==8.4.0
RUN pip install allianceauth==${AA_VERSION} git+https://github.com/pvyParts/allianceauth-corp-tools.git@3.0.0
RUN pip install allianceauth==${AA_VERSION} git+https://github.com/fnt-eve/allianceauth-oidc-provider@6a9a6c661ea002890e1e6a8889acec550af31f23

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
