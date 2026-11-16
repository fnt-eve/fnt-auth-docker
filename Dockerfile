FROM python:3.12-slim
ARG AA_VERSION=5.6.0
ARG AA_CHARLINK_VERSION=1.15.0
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
                aa-freight==3.1.0 allianceauth-signal-pings==0.0.12 \
                allianceauth-securegroups==0.10.2 aa-esi-status==4.3.0 fittings==2.3.3 \
                django-eveuniverse==2.2.0 aa-structures==4.1.0  allianceauth-afat==6.3.0 \
                aa-moonmining==3.2.0 aa-charlink==${AA_CHARLINK_VERSION} aa-taskmonitor==1.1.1 discordproxy==1.5.1 \
                aa-discordnotify==4.0.1 ts3==1.0.11 aa-srp==5.10.0 aa-structuretimers==3.2.0 aa-package-monitor==3.0.2 \
                allianceauth-invoices==0.1.9 pyjwt==2.15.1 django-cors-headers==4.9.0 py-cord==2.8.1 py-cord[voice]==2.8.1 django-eveonline-sde==1.0.0 \
                allianceauth-app-utils==1.33.2 django-esi==10.1.0
RUN pip install allianceauth==${AA_VERSION} allianceauth-corptools==3.5.1
RUN pip install allianceauth==${AA_VERSION} django-oauth-toolkit==3.4.0 oauthlib==3.3.1 git+https://github.com/fnt-eve/allianceauth-oidc-provider@6a9a6c661ea002890e1e6a8889acec550af31f23

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
