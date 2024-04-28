#!/bin/bash
export PATH=$PATH:/usr/sbin:/usr/bin:/sbin:/bin

if [[ ! -e /var/lib/cydia/firmware.ver ]]; then
    cache=
fi

/usr/libexec/cydia/firmware.sh
rm -f /System/Library/LaunchDaemons/com.apple.mobile.softwareupdated.plist
rm -f /System/Library/LaunchDaemons/com.apple.softwareupdateservicesd.plist

debs=(/var/root/Media/Cydia/AutoInstall/*.deb)
if [[ ${#debs[@]} -ne 0 && -f ${debs[0]} ]]; then
    dpkg -i "${debs[@]}" 2>/tmp/dpkg.log 1>&2
    rm -f "${debs[@]}"
    cache=

    killall -9 Lowtide AppleTV
fi

if [[ ${cache+@} ]]; then
    sbdidlaunch
    su -c uicache mobile
fi

if [[ -e /etc/rc.d/substrate ]]; then
    /etc/rc.d/substrate
fi

/usr/libexec/Crashhousekeeping_o "$@"
