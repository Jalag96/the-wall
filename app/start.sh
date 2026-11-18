#!/bin/sh

#Förhindrar Gunicorn från att starta om det blir fel i databas
set -e

#Databas init
python -c "from app import initialize; initialize()"

#Starta Gunicorn
exec gunicorn --bind 0.0.0.0:8080 app:app
