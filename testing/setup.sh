#!/bin/bash

############################################################
#region removeStuff
systemctl stop tested.socket
systemctl stop tested.service
systemctl stop tested.path
rm /run/tested.sk
#endregion

############################################################
#region copyStuff
cp tested.service /etc/systemd/system/
cp tested.socket /etc/systemd/system/
cp tested.path /etc/systemd/system/
cp restart-tested.service /etc/systemd/system/
cp nginx-config /etc/nginx/servers/tested
#endregion

############################################################
#region reloadAnd(Re)start
systemctl daemon-reload
systemctl start tested.socket
systemctl start tested.path
nginx -s reload
#endregion