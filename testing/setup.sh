#!/bin/bash

############################################################
#region removeStuff
systemctl stop sentinel-datahub.socket
systemctl stop sentinel-datahub.service
systemctl stop sentinel-datahub.path

rm /run/sentinel-datahub.sk

#endregion

############################################################
#region copyStuff
cp sentinel-datahub.service /etc/systemd/system/
cp sentinel-datahub.socket /etc/systemd/system/
cp sentinel-datahub.path /etc/systemd/system/
cp restart-sentinel-datahub.service /etc/systemd/system/

cp nginx-config /etc/nginx/servers/sentinel-datahub

#endregion

############################################################
./mount-files.sh

############################################################
#region reloadAnd(Re)start
systemctl daemon-reload
systemctl start sentinel-datahub.socket
systemctl start sentinel-datahub.path

nginx -s reload

#endregion
