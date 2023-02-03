#!/bin/sh

. $VIRTUAL_ENV/bin/activate
python ${AUTH_HOME}/myauth/manage.py migrate
python ${AUTH_HOME}/myauth/manage.py collectstatic