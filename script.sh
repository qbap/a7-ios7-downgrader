#/bin/bash

os=$(uname)
oscheck=$(uname)
version="$1"
dir="$(pwd)/"

_wait_for_dfu() {
    if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi
    
    while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
}

check="0x8960"
deviceid="iPhone6,1"
ipswurl1=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'7.1.2'")' | ./jq -s '.[0] | .url' --raw-output)
ipswurl2=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'8.4.1'")' | ./jq -s '.[0] | .url' --raw-output)

echo $deviceid
echo $ipswurl1
echo $ipswurl2

./img4tool -e -s other/shsh/"${check}".shsh -m IM4M

if [ "$deviceid" = 'iPhone6,1' ]; then

if [ ! -e 058-4438-009.dmg ]; then
./pzb -g 058-4438-009.dmg "$ipswurl1"
./dmg extract 058-4438-009.dmg rw.dmg -k ff95d392a307dfd6bb4f6d9ad4ef5db2ab50e015cee5366b5195090a1b4f4c84a86f30f5
./dmg build rw.dmg ios7.dmg
hdiutil attach -mountpoint /tmp/ios7 ios7.dmg
sudo diskutil enableOwnership /tmp/ios7
sudo ./gnutar -cvf ios7.tar -C /tmp/ios7 .
fi

if [ -e ios7.dmg ]; then

if [ ! -e apticket.der ]; then
echo "you need to turn on ssh&sftp over wifi on ur phone now"
echo "pls install dropbear on cydia"
echo "and then go back and install openssh as well"
echo "dropbear enables ssh on ios 10 and openssh enables sftp on ios 10"
echo "you'll also need to download mterminal from cydia"
echo "open mterminal and type su -"
echo "it will ask for password, the password is alpine"
echo "then you should type dropbear -R -p 2222"
echo "this will then enable dropbear ssh to work over wifi"
read -p "what is the local ip of ur ios device on your wifi?" ip
echo "$ip"
./sshpass -p "alpine" scp -P 2222 root@$ip:/System/Library/Caches/apticket.der ./apticket.der
./sshpass -p "alpine" scp -P 2222 root@$ip:/usr/standalone/firmware/sep-firmware.img4 ./sep-firmware.img4
./sshpass -p "alpine" scp -r -P 2222 root@$ip:/usr/local/standalone/firmware/Baseband ./Baseband
./sshpass -p "alpine" scp -r -P 2222 root@$ip:/var/keybags ./keybags
fi



if [ ! -e 058-24442-023.dmg ]; then
./pzb -g 058-24442-023.dmg "$ipswurl2"
./img4 -i 058-24442-023.dmg -o ramdisk.dmg -k 5f72aa47ded95dd5f3504c44db082240a8faf901c15014e99c6bf50a63c407c82846f07750b12fa5737ede556b226619
hdiutil resize -size 50M ramdisk.dmg
hdiutil attach ramdisk.dmg
./gnutar -xvf iram.tar -C /Volumes/ramdisk
hdiutil detach /Volumes/ramdisk
./img4tool -c ramdisk.im4p -t rdsk ramdisk.dmg
./img4tool -c ramdisk.img4 -p ramdisk.im4p -m IM4M
fi

if [ -e ramdisk.img4 ]; then
if [ ! -e devicetree.img4 ]; then

./pzb -g Firmware/dfu/iBSS.n51.RELEASE.im4p "$ipswurl2"
./pzb -g Firmware/dfu/iBEC.n51.RELEASE.im4p "$ipswurl2"
./pzb -g kernelcache.release.n51 "$ipswurl2"
./pzb -g Firmware/all_flash/all_flash.n51ap.production/DeviceTree.n51ap.im4p "$ipswurl2"
./img4 -i iBSS.n51.RELEASE.im4p -o iBSS.dec -k 46c3abc7147db7e9c06aae801b13a91238b9f71efaaa02e48731471ac1fc506ab1e4e9716eac2207037778d9f62648d9
./img4 -i iBEC.n51.RELEASE.im4p -o iBEC.dec -k c52d431c7fbc85b67307c2c7297f919f5fd45b3e2717b75e9ef1816f6afa2aa9e92fb8c7f1b1403600943a8bd637b62d
./ipatcher iBSS.dec iBSS.patched
./ipatcher iBEC.dec iBEC.patched -b "amfi=0xff cs_enforcement_disable=1 -v rd=md0 nand-enable-reformat=1 -progress"
./img4 -i iBSS.patched -o iBSS.img4 -M IM4M -A -T ibss
./img4 -i iBEC.patched -o iBEC.img4 -M IM4M -A -T ibec
./img4 -i kernelcache.release.n51 -o kernelcache.im4p -k 03447866614ec7f0e083eba37b31f1a75484c5ab65e00e895b95db81b873d1292f766e614c754ec523b62a48d33664e1 -D
./img4 -i kernelcache.im4p -o kernelcache.img4 -M IM4M -T rkrn
./img4 -i DeviceTree.n51ap.im4p -o dtree.raw -k 2f744c5a6cda23c30eccb2fcac9aff2222ad2b37ed96f14a3988102558e0920905536622b1e78288c2533a7de5d01425
./img4 -i dtree.raw -o devicetree.img4 -A -M IM4M -T rdtr
fi
./ipwnder -p

./irecovery -f iBSS.img4
./irecovery -f iBSS.img4

./irecovery -f iBEC.img4

./irecovery -f ramdisk.img4

./irecovery -c ramdisk

./irecovery -f devicetree.img4

./irecovery -c devicetree

./irecovery -f kernelcache.img4

./irecovery -c bootx

fi

fi

_wait_for_dfu

echo "meow!"

fi
