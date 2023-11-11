FROM python:3.10-slim
ARG AA_VERSION=3.8.0
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
RUN pip install wheel gunicorn
RUN pip install allianceauth==${AA_VERSION}
ENV AA_PACKAGE_PATH="$VIRTUAL_ENV/lib/python3.10/site-packages/allianceauth/"

# Install AA extension apps
RUN pip install aa-freight aa-corpstats-two allianceauth-signal-pings \
                allianceauth-securegroups aa-esi-status fittings \
                django-eveuniverse aa-structures  allianceauth-afat
RUN pip install -U git+https://github.com/pvyParts/allianceauth-corp-tools.git

COPY patches ${AUTH_HOME}
RUN find ${AUTH_HOME}/ -type f -name "*.patch" -exec sh -c "cat "{}" | patch -p2 -d $AA_PACKAGE_PATH" \;

# Initialize auth
RUN allianceauth start myauth
RUN allianceauth update myauth
RUN mkdir -p ${STATIC_BASE}/myauth/static

COPY /conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN echo 'alias auth="python $AUTH_HOME/myauth/manage.py"' >> ~/.bashrc && \
    echo 'alias supervisord="supervisord -c /etc/supervisor/conf.d/supervisord.conf"' >> ~/.bashrc && \
    echo "source ${VIRTUAL_ENV}/bin/activate" >> ~/.bashrc && \
    source ~/.bashrc


WORKDIR /home/allianceserver/myauth
EXPOSE 8000
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
