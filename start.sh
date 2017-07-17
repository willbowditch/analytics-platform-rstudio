#!/bin/bash
set -ex

GROUP=staff
USER_UID=1001

if [ "$(id -u "$USER" 2>/dev/null)" != $USER_UID ]; then
    useradd -g $GROUP -u $USER_UID -d /home/$USER $USER
fi
echo "${USER}:${USER}" | chpasswd
if [ ! -d /home/$USER ]; then
    mkdir -p /home/$USER
fi
chown "${USER}:${GROUP}" /home/$USER

if [ -z "$PROXY_URL" ]; then
    PROXY_HOST="${USER}-rstudio.${TOOLS_DOMAIN}"
fi

echo "Proxy: $PROXY_URL"

#if [ -z "$NO_AUTH_PROXY" ]; then
    ##echo "auth-proxy=1" >> /etc/rstudio/rserver.conf
    ##echo "auth-proxy-sign-in-url=${PROXY_URL}/logout" >> /etc/rstudio/rserver.conf
#fi

echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" >> /etc/R/Renviron
echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" >> /etc/R/Renviron
echo "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}" >> /etc/R/Renviron

/usr/lib/rstudio-server/bin/rserver --server-daemonize 0
