#!/bin/bash
# This should be executed from within the testing/ directory of the thingy
# To execute this we need root privileges!
set -euo pipefail

USER="services" # user for test-running the service
TARGETUID=$(id -u "$USER") # get uid = target uid
TARGETGID=$(id -g "$USER") # get gid = target gid

# service.js
SERVICEJS="../output/service.js"
REALUID=$(stat -c %u "$SERVICEJS")
REALGID=$(stat -c %g "$SERVICEJS")
# echo "File Owners ${REALUID}:${REALGID}"

BASEPATH="/opt/void/sentinel-datahub" 
MNTPATH="${BASEPATH}/service.js"


# ensure clean mountpount
if [ ! -d "$BASEPATH" ]; then
    mkdir -p "$BASEPATH" # create base path if it does not exist yet
fi

if mountpoint -q "$MNTPATH"; then
    umount "$MNTPATH" # unmount if something is mounted
fi
touch "$MNTPATH" # ensure we have something to mount on


# This id-mapped mount works as expected - but according to the manual it would be wrong
mount --bind -o "X-mount.idmap=u:${REALUID}:0:1 g:${REALGID}:0:1" "$SERVICEJS" "$MNTPATH"

# This would be the "correct" mapping according to the manual - but maps to "nobody:nobody"
    # Excert from the manual https://man7.org/linux/man-pages/man8/mount.8.html
    # Section: X-mount.idmap=id-type:id-mount:id-host:id-range
    #
    # The ID-mapping must be specified using the syntax
    # id-type:id-mount:id-host:id-range. Specifying u as the
    # id-type prefix creates a UID-mapping, g creates a
    # GID-mapping and omitting id-type or specifying b creates
    # both a UID- and GID-mapping. The id-mount parameter
    # indicates the starting ID in the new mount. The id-host
    # parameter indicates the starting ID in the filesystem. The
    # id-range parameter indicates how many IDs are to be
    # mapped. It is possible to specify multiple ID-mappings.

    # The individual ID mappings must be separated by spaces.
    # Please note that in the /etc/fstab file, spaces are
    # interpreted as separators between fields. To avoid this,
    # you must escape them using \040. For example,
    # X-mount.idmap=0:0:1\040500:1000:1.

    # For example, the ID-mapping X-mount.idmap=u:1000:0:1
    # g:1001:1:2 5000:1000:2 creates an idmapped mount where UID
    # 0 is mapped to UID 1000, GID 1 is mapped to GUID 1001, GID
    # 2 is mapped to GID 1002, UID and GID 1000 are mapped to
    # 5000, and UID and GID 1001 are mapped to 5001 in the
    # mount.

    # When an ID-mapping is specified directly a new user
    # namespace will be allocated with the requested ID-mapping.
    # The newly created user namespace will be attached to the
    # mount.
# mount --bind -o "X-mount.idmap=u:0:${REALUID}:1 g:0:${REALGID}:1" "$SERVICEJS" "$MNTPATH"

# Sidenote: using quotes around Variables ensures that they are passed to 
#    the command as one argument. If we use touch $MNTPATH and $MNTPATH is
#    "a b c" then without quotes touch would receive 3 arguments.
#    Without quotes bash would process the expression e.g. expanding a glob. 

# testing-wd
TESTWD="./testing-wd"
REALUID=$(stat -c %u "$TESTWD")
REALGID=$(stat -c %g "$TESTWD")

MNTPATH="/srv/srvcs/sentinel-datahub"

# ensure clean mountpount
if [ ! -d "$MNTPATH" ]; then
    mkdir -p "$MNTPATH" # mount path if it does not exist yet
fi

if mountpoint -q "$MNTPATH"; then
    umount "$MNTPATH" # unmount if something is mounted
fi
# echo "${REALUID}:${TARGETUID}"
# echo "${REALGID}:${TARGETGID}"

# This id-mapped mount works as expected - but according to the manual it would be wrong
mount --bind -o "X-mount.idmap=u:${REALUID}:${TARGETUID}:1 g:${REALGID}:${TARGETGID}:1" "$TESTWD" "$MNTPATH"

# mount --bind "$TESTWD" "$MNTPATH"
# setfacl -R -m "u:$USER:rwx" "$MNTPATH"
# setfacl -R -d -m "u:$USER:rwx" "$MNTPATH"