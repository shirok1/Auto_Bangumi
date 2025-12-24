#!/bin/bash
# shellcheck shell=bash

umask ${UMASK}

if [ -f /config/bangumi.json ]; then
    mv /config/bangumi.json /app/data/bangumi.json
fi

# Fix permissions if PUID/PGID are set
if [ -n "${PGID}" ] && [ "${PGID}" != "$(id -g ab)" ]; then
    groupmod -o -g "${PGID}" ab
fi
if [ -n "${PUID}" ] && [ "${PUID}" != "$(id -u ab)" ]; then
    usermod -o -u "${PUID}" ab
fi

chown ab:ab -R /app /home/ab

exec gosu "${PUID}:${PGID}" python3 main.py
