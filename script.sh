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
remote_cmd() {
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "$@"
}

remote_cp() {
    ./sshpass -p 'alpine' scp -o StrictHostKeyChecking=no -P2222 $@
}
_kill_if_running() {
    if (pgrep -u root -xf "$1" &> /dev/null > /dev/null); then
        # yes, it's running as root. kill it
        sudo killall $1
    else
        if (pgrep -x "$1" &> /dev/null > /dev/null); then
            killall $1
        fi
    fi
}
for cmd in curl python3 ssh scp killall sudo grep; do
    if ! command -v "${cmd}" > /dev/null; then
        if [ "$cmd" = "python3" ]; then
            echo "[-] Command '${cmd}' not installed, please install it!";
            if [ "$os" = 'Darwin' ]; then
                if [ ! -e python-3.7.6-macosx10.6.pkg ]; then
                    curl -k https://www.python.org/ftp/python/3.7.6/python-3.7.6-macosx10.6.pkg -o python-3.7.6-macosx10.6.pkg
                fi
                open -W python-3.7.6-macosx10.6.pkg
            fi
            if ! command -v "${cmd}" > /dev/null; then
                cmd_not_found=1
            fi
        else
            if ! command -v "${cmd}" > /dev/null; then
                echo "[-] Command '${cmd}' not installed, please install it!";
                cmd_not_found=1
            fi
        fi
    fi
done
if [ "$cmd_not_found" = "1" ]; then
    exit 1
fi
# Check for autodecrypt
if ! python3 -c 'import pkgutil; exit(not pkgutil.find_loader("autodecrypt"))'; then
    python3 -m pip install autodecrypt
fi
if [ ! -e apticket.der ]; then
    echo "you need to turn on ssh&sftp over wifi on ur phone now"
    echo "https://github.com/y08wilm/a7-ios7-downgrader?tab=readme-ov-file#preparing-your-device"
    read -p "what is the local ip of ur ios device on your wifi?" ip
    echo "$ip"
    ./sshpass -p "alpine" scp -P 2222 root@$ip:/System/Library/Caches/apticket.der ./apticket.der
    ./sshpass -p "alpine" scp -P 2222 root@$ip:/usr/standalone/firmware/sep-firmware.img4 ./sep-firmware.img4
    ./sshpass -p "alpine" scp -r -P 2222 root@$ip:/usr/local/standalone/firmware/Baseband ./Baseband
    ./sshpass -p "alpine" scp -r -P 2222 root@$ip:/var/keybags ./keybags
fi
if [ ! -e apticket.der ]; then
    exit
fi
_wait_for_dfu
check=$(./irecovery -q | grep CPID | sed 's/CPID: //')
deviceid=$(./irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
ipswurl1=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'7.1.2'")' | ./jq -s '.[0] | .url' --raw-output)
ipswurl2=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'8.4.1'")' | ./jq -s '.[0] | .url' --raw-output)
ipswurl3=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'9.3.2'")' | ./jq -s '.[0] | .url' --raw-output)
ipswurl4=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'7.0.6'")' | ./jq -s '.[0] | .url' --raw-output)
echo $deviceid
echo $ipswurl1
echo $ipswurl2
echo $ipswurl3
echo $ipswurl4
read -p "what ios version would you like to downgrade to? " iosversion
if [ "$iosversion" = '8.4.1' ]; then
    echo "this version is known to get stuck on the slide to upgrade screen"
    read -p "would you like to use this version anyway? " response6
    if [[ "$response6" = 'yes' || "$response6" = 'y' ]]; then
        echo "ok"
    else
        exit
    fi
elif [ "$iosversion" = '7.1.2' ]; then
    echo "good choice"
elif [ "$iosversion" = '7.0.6' ]; then
    echo "good choice"
elif [ "$iosversion" = '9.3.2' ]; then
    echo "this version is known to get on a progress bar on first boot"
    read -p "would you like to use this version anyway? " response6
    if [[ "$response6" = 'yes' || "$response6" = 'y' ]]; then
        echo "ok"
    else
        exit
    fi
else
    echo "that version is not supported"
    exit
fi
# if we already have installed ios using this script we can just boot the existing kernelcache
if [ -e work/iBSS.img4 ]; then
    _wait_for_dfu
    cd work
    ../ipwnder -p
    ../irecovery -f iBSS.img4
    ../irecovery -f iBSS.img4
    ../irecovery -f iBEC.img4
    ../irecovery -f devicetree.img4
    ../irecovery -c devicetree
    ../irecovery -f kernelcache.img4
    ../irecovery -c bootx &
    exit
fi
# we need a shsh file that we can use in order to boot the ios 8 ramdisk
# in this case we are going to use the ones from SSHRD_Script https://github.com/verygenericname/SSHRD_Script
./img4tool -e -s other/shsh/"${check}".shsh -m IM4M
# as of the time im writing this, i have only tested this script on iPhone6,1 not iPhone6,2
# pls let me know if it works on iPhone6,2 as is, and if it doesnt ill fix it
if [[ "$deviceid" = 'iPhone6,1' || "$deviceid" = 'iPhone6,2' ]]; then
    echo "ok"
else
    echo "this device is not supported"
fi
if [ "$iosversion" = '8.4.1' ]; then
    # we need to download ios 8.4.1 root fs and decrypt it and put it into a tar file
    if [ ! -e 058-24099-024.dmg ]; then
        ./pzb -g 058-24099-024.dmg "$ipswurl2"
        rm -rf rw.dmg
        ./dmg extract 058-24099-024.dmg rw.dmg -k e8427cfcf8ff5c79b43453784eec6fead8ca780a7500fe8c17187c9919c9b51800512daf
        ./dmg build rw.dmg ios8.dmg
        hdiutil attach -mountpoint /tmp/ios8 ios8.dmg
        sudo diskutil enableOwnership /tmp/ios8
        sudo ./gnutar -cvf ios8.tar -C /tmp/ios8 .
    fi
elif [ "$iosversion" = '7.0.6' ]; then
    # we need to download ios 7.0.6 root fs and decrypt it and put it into a tar file
    if [ ! -e 058-2384-003.dmg ]; then
        ./pzb -g 058-2384-003.dmg "$ipswurl4"
        rm -rf rw.dmg
        ./dmg extract 058-2384-003.dmg rw.dmg -k a0d2c1d5ce091c62dcf28f1ac953e58a6a66c112184d125e177a1285b7e991262e3c5917
        ./dmg build rw.dmg ios706.dmg
        hdiutil attach -mountpoint /tmp/ios7 ios706.dmg
        sudo diskutil enableOwnership /tmp/ios7
        sudo ./gnutar -cvf ios706.tar -C /tmp/ios7 .
    fi
elif [ "$iosversion" = '7.1.2' ]; then
    # we need to download ios 7.1.2 root fs and decrypt it and put it into a tar file
    if [ ! -e 058-4438-009.dmg ]; then
        ./pzb -g 058-4438-009.dmg "$ipswurl1"
        rm -rf rw.dmg
        ./dmg extract 058-4438-009.dmg rw.dmg -k ff95d392a307dfd6bb4f6d9ad4ef5db2ab50e015cee5366b5195090a1b4f4c84a86f30f5
        ./dmg build rw.dmg ios7.dmg
        hdiutil attach -mountpoint /tmp/ios7 ios7.dmg
        sudo diskutil enableOwnership /tmp/ios7
        sudo ./gnutar -cvf ios712.tar -C /tmp/ios7 .
    fi
elif [ "$iosversion" = '9.3.2' ]; then
    # we need to download ios 9.3.2 root fs and decrypt it and put it into a tar file
    if [ ! -e 058-36981-072.dmg ]; then
        ./pzb -g 058-36981-072.dmg "$ipswurl3"
        rm -rf rw.dmg
        ./dmg extract 058-36981-072.dmg rw.dmg -k ca08477e9fdba12761bf5fbe2466f3028df6debe633b87cb2d66911c2826646fc3cbfc3c
        ./dmg build rw.dmg ios9.dmg
        hdiutil attach -mountpoint /tmp/ios9 ios9.dmg
        sudo diskutil enableOwnership /tmp/ios9
        sudo ./gnutar -cvf ios9.tar -C /tmp/ios9 .
    fi
else
    echo "that version is not supported"
fi
# we need to download restore ramdisk for ios 8.4.1
# in this example we are using a modified copy of the ssh tar from SSHRD_Script https://github.com/verygenericname/SSHRD_Script
# this modified copy of the ssh tar fixes a few issues on ios 8 and adds some executables we need
if [ ! -e 058-24442-023.dmg ]; then
    ./pzb -g 058-24442-023.dmg "$ipswurl2"
    ./img4 -i 058-24442-023.dmg -o ramdisk.dmg -k 5f72aa47ded95dd5f3504c44db082240a8faf901c15014e99c6bf50a63c407c82846f07750b12fa5737ede556b226619
    hdiutil resize -size 60M ramdisk.dmg
    hdiutil attach -mountpoint /tmp/ramdisk ramdisk.dmg
    sudo diskutil enableOwnership /tmp/ramdisk
    sudo ./gnutar -xvf iram.tar -C /tmp/ramdisk
    #sudo ./gnutar -xvf dualbootstuff.tar -C /tmp/ramdisk
    hdiutil detach /tmp/ramdisk
    ./img4tool -c ramdisk.im4p -t rdsk ramdisk.dmg
    ./img4tool -c ramdisk.img4 -p ramdisk.im4p -m IM4M
fi
# if the ramdisk does not exist, exit
if [ ! -e ramdisk.img4 ]; then
    exit
fi
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
mkdir work
cp IM4M work
cd work
if [ ! -e devicetree.img4 ]; then
    echo $iosversion
    if [ "$iosversion" = '8.4.1' ]; then
        ../pzb -g Firmware/dfu/iBSS.n51.RELEASE.im4p "$ipswurl2"
        ../pzb -g Firmware/dfu/iBEC.n51.RELEASE.im4p "$ipswurl2"
        ../pzb -g kernelcache.release.n51 "$ipswurl2"
        ../pzb -g Firmware/all_flash/all_flash.n51ap.production/DeviceTree.n51ap.im4p "$ipswurl2"
        ../img4 -i iBSS.n51.RELEASE.im4p -o iBSS.dec -k 46c3abc7147db7e9c06aae801b13a91238b9f71efaaa02e48731471ac1fc506ab1e4e9716eac2207037778d9f62648d9
        ../img4 -i iBEC.n51.RELEASE.im4p -o iBEC.dec -k c52d431c7fbc85b67307c2c7297f919f5fd45b3e2717b75e9ef1816f6afa2aa9e92fb8c7f1b1403600943a8bd637b62d
        #../ipatcher iBSS.dec iBSS.patched
        #../ipatcher iBEC.dec iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1"
        ../iBoot64Patcher iBSS.dec iBSS.patched
        ../iBoot64Patcher iBEC.dec iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1"
        ../img4 -i iBSS.patched -o iBSS.img4 -M IM4M -A -T ibss
        ../img4 -i iBEC.patched -o iBEC.img4 -M IM4M -A -T ibec
        ../img4 -i kernelcache.release.n51 -o kernelcache.im4p -k 03447866614ec7f0e083eba37b31f1a75484c5ab65e00e895b95db81b873d1292f766e614c754ec523b62a48d33664e1 -D
        ../img4 -i kernelcache.release.n51 -o kcache.raw -k 03447866614ec7f0e083eba37b31f1a75484c5ab65e00e895b95db81b873d1292f766e614c754ec523b62a48d33664e1
        ../seprmvr64lite kcache.raw kcache.patched
        ../kerneldiff kcache.raw kcache.patched kc.bpatch
        ../img4 -i kernelcache.im4p -o kernelcache.img4 -M IM4M -T rkrn -P kc.bpatch
        ../img4 -i kernelcache.im4p -o kernelcache -M IM4M -T krnl -P kc.bpatch
        ../img4 -i DeviceTree.n51ap.im4p -o dtree.raw -k 2f744c5a6cda23c30eccb2fcac9aff2222ad2b37ed96f14a3988102558e0920905536622b1e78288c2533a7de5d01425
        ../dtree_patcher dtree.raw dree.patched -n
        ../img4 -i dtree.patched -o devicetree.img4 -A -M IM4M -T rdtr
    elif [ "$iosversion" = '7.1.2' ]; then
        ../pzb -g Firmware/dfu/iBSS.n51ap.RELEASE.im4p "$ipswurl1"
        ../pzb -g Firmware/dfu/iBEC.n51ap.RELEASE.im4p "$ipswurl1"
        ../pzb -g kernelcache.release.n51 "$ipswurl1"
        ../pzb -g Firmware/all_flash/all_flash.n51ap.production/DeviceTree.n51ap.im4p "$ipswurl1"
        ../img4 -i iBSS.n51ap.RELEASE.im4p -o iBSS.dec -k b4c6843dddc7c7e3727077aee6e62c4c42d112d57eeb50505c1e7be26f4d580982839da4e75cc0eb1314ecc464ec4779
        ../img4 -i iBEC.n51ap.RELEASE.im4p -o iBEC.dec -k f800c184406ae951847b5e0207f78c89058cd17ac2e346dd315a3bdbe8b43565962896ed8bd28bfbd201c94ba94b6afb
        ../ipatcher iBSS.dec iBSS.patched
        ../ipatcher iBEC.dec iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1"
        ../img4 -i iBSS.patched -o iBSS.img4 -M IM4M -A -T ibss
        ../img4 -i iBEC.patched -o iBEC.img4 -M IM4M -A -T ibec
        ../img4 -i kernelcache.release.n51 -o kernelcache.im4p -k 315af5407859bf02143283deaa31e92e46c6ca6cb9799a6018c94d2cebb6579345f8496d5a0e72cf783e4bd4dbabc59c -D
        ../img4 -i kernelcache.release.n51 -o kcache.raw -k 315af5407859bf02143283deaa31e92e46c6ca6cb9799a6018c94d2cebb6579345f8496d5a0e72cf783e4bd4dbabc59c
        ../seprmvr64lite kcache.raw kcache.patched
        ../kerneldiff kcache.raw kcache.patched kc.bpatch
        ../img4 -i kernelcache.im4p -o kernelcache.img4 -M IM4M -T rkrn -P kc.bpatch
        ../img4 -i kernelcache.im4p -o kernelcache -M IM4M -T krnl -P kc.bpatch
        ../img4 -i DeviceTree.n51ap.im4p -o dtree.raw -k 4955c27b46e5eaf7e7b3829da15fefcf83f82bb816d59b13451b1fbc21332b730f5138e40148f8815767f1f92b0f16cb
        ../img4 -i dtree.raw -o devicetree.img4 -A -M IM4M -T rdtr
    elif [ "$iosversion" = '7.0.6' ]; then
        ../pzb -g Firmware/dfu/iBSS.n51ap.RELEASE.im4p "$ipswurl4"
        ../pzb -g Firmware/dfu/iBEC.n51ap.RELEASE.im4p "$ipswurl4"
        ../pzb -g kernelcache.release.n51 "$ipswurl4"
        ../pzb -g Firmware/all_flash/all_flash.n51ap.production/DeviceTree.n51ap.im4p "$ipswurl4"
        ../img4 -i iBSS.n51ap.RELEASE.im4p -o iBSS.dec -k 5841c33639bcf387bd2b72e111d4de6bb3b9eefee0d3f5f3a2f6a0ead7ebc4624fdd532a8e234dda60a0f6b0648bd28e
        ../img4 -i iBEC.n51ap.RELEASE.im4p -o iBEC.dec -k a49c5193c3f67574f83d477f5a330b4e9110c4fce69d97abee13dd632e3bb485b9d0e30c51b63f3dd56871d6e7793ef7
        ../ipatcher iBSS.dec iBSS.patched
        ../ipatcher iBEC.dec iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1"
        ../img4 -i iBSS.patched -o iBSS.img4 -M IM4M -A -T ibss
        ../img4 -i iBEC.patched -o iBEC.img4 -M IM4M -A -T ibec
        ../img4 -i kernelcache.release.n51 -o kernelcache.im4p -k 64059127bd207cc0e7a86c1fd7395554cdc5fb1fd3e4da5022b5c4865d6b0fa93d3db59da1f9c1de0f1e77d736f2e0a6 -D
        ../img4 -i kernelcache.release.n51 -o kcache.raw -k 64059127bd207cc0e7a86c1fd7395554cdc5fb1fd3e4da5022b5c4865d6b0fa93d3db59da1f9c1de0f1e77d736f2e0a6
        ../seprmvr64lite kcache.raw kcache.patched
        ../kerneldiff kcache.raw kcache.patched kc.bpatch
        ../img4 -i kernelcache.im4p -o kernelcache.img4 -M IM4M -T rkrn -P kc.bpatch
        ../img4 -i kernelcache.im4p -o kernelcache -M IM4M -T krnl -P kc.bpatch
        ../img4 -i DeviceTree.n51ap.im4p -o dtree.raw -k d14f7f0634d9e1e8e6b581729e056574354a1c1eed8444a2e5f9ab47e5d2308e52f938f456d54a59fad695d3904138a8
        ../img4 -i dtree.raw -o devicetree.img4 -A -M IM4M -T rdtr
    elif [ "$iosversion" = '9.3.2' ]; then
        ../pzb -g Firmware/dfu/iBSS.n51.RELEASE.im4p "$ipswurl3"
        ../pzb -g Firmware/dfu/iBEC.n51.RELEASE.im4p "$ipswurl3"
        ../pzb -g kernelcache.release.n51 "$ipswurl3"
        ../pzb -g Firmware/all_flash/all_flash.n51ap.production/DeviceTree.n51ap.im4p "$ipswurl3"
        ../img4 -i iBSS.n51.RELEASE.im4p -o iBSS.dec -k fcd5ce2c70f483d50add94d63cc718724618dc046b4c6e432c81243e6f94cdff2f9b0b899a050f0870bb913860f97951
        ../img4 -i iBEC.n51.RELEASE.im4p -o iBEC.dec -k e73bf307e7f8783ead2a6cbed9a2aea3ebf3b332e5dda4e94f88fe0899e30731dcbb1e5e03a5b6757a4c32cc298a018f
        ../iBoot64Patcher iBSS.dec iBSS.patched
        ../iBoot64Patcher iBEC.dec iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1"
        ../img4 -i iBSS.patched -o iBSS.img4 -M IM4M -A -T ibss
        ../img4 -i iBEC.patched -o iBEC.img4 -M IM4M -A -T ibec
        ../img4 -i kernelcache.release.n51 -o kernelcache.im4p -k 1794b612cf3a4781cebd976c55f5c23abef2d346023dee0e7154673d4adfdee7d6ca1854e7107648a1e3f004f9add1be -D
        ../img4 -i kernelcache.release.n51 -o kcache.raw -k 1794b612cf3a4781cebd976c55f5c23abef2d346023dee0e7154673d4adfdee7d6ca1854e7107648a1e3f004f9add1be
        ../seprmvr64lite kcache.raw kcache.patched
        ../kerneldiff kcache.raw kcache.patched kc.bpatch
        ../img4 -i kernelcache.im4p -o kernelcache.img4 -M IM4M -T rkrn -P kc.bpatch
        ../img4 -i kernelcache.im4p -o kernelcache -M IM4M -T krnl -P kc.bpatch
        ../img4 -i DeviceTree.n51ap.im4p -o dtree.raw -k dc34b39adb91850be325246269da6c12eaed50c730a90bb566c638644fef398412a1b552d97aa8e764df0a30a700d05b
        ../img4 -i dtree.raw -o devicetree.img4 -A -M IM4M -T rdtr
    fi
fi
cd ..
_wait_for_dfu
./ipwnder -p
./irecovery -f iBSS.img4
./irecovery -f iBSS.img4
./irecovery -f iBEC.img4
./irecovery -f ramdisk.img4
./irecovery -c ramdisk
./irecovery -f devicetree.img4
./irecovery -c devicetree
./irecovery -f kernelcache.img4
./irecovery -c bootx &
read -p "pls press the enter key once device is in the ramdisk " pause1
./iproxy 2222 22 &
sleep 2
read -p "would you like to delete all the partitions and start over? " response1
if [[ "$response1" = 'yes' || "$response1" = 'y' ]]; then
    # this command erases the nand so we can create new partitions
    remote_cmd "lwvm init"
    sleep 2
    $(./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" &)
    _kill_if_running iproxy
    echo "device should now reboot into recovery, pls wait"
    echo "once in recovery you should follow instructions online to go back into dfu"
    _wait_for_dfu
    ./ipwnder -p
    ./irecovery -f iBSS.img4
    ./irecovery -f iBSS.img4
    ./irecovery -f iBEC.img4
    ./irecovery -f ramdisk.img4
    ./irecovery -c ramdisk
    ./irecovery -f devicetree.img4
    ./irecovery -c devicetree
    ./irecovery -f kernelcache.img4
    ./irecovery -c bootx &
    read -p "pls press the enter key once device is in the ramdisk" pause1
    ./iproxy 2222 22 &
    echo "https://ios7.iarchive.app/downgrade/installing-filesystem.html"
    echo "partition 1"
    echo "step 1, press the letter n on your keyboard and then press enter"
    echo "step 2, press number 1 on your keyboard and press enter"
    echo "step 3, press enter again"
    if [ "$iosversion" = '7.1.2' ]; then
        echo "step 4, type 786438 and then press enter"
    elif [ "$iosversion" = '7.0.6' ]; then
        echo "step 4, type 786438 and then press enter"
    else
        echo "step 4, type 1548290 and then press enter"
    fi
    echo "step 5, press enter one last time"
    echo "partition 2"
    echo "step 1, press the letter n on your keyboard and then press enter"
    echo "step 2, press number 2 on your keyboard and press enter"
    echo "step 3, press enter 3 more times"
    echo "last steps"
    echo "step 1, press the letter w on your keyboard and then press enter"
    echo "step 2, press y on your keyboard and press enter"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "gptfdisk /dev/rdisk0s1"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/sync"
    sleep 2
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/sync"
    sleep 2
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/sync"
    sleep 2
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/sync"
    sleep 2
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_hfs -s -v System -J -b 4096 -n a=4096,c=4096,e=4096 /dev/disk0s1s1"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_hfs -s -v Data -J -b 4096 -n a=4096,c=4096,e=4096 /dev/disk0s1s2"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_hfs /dev/disk0s1s1 /mnt1"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_hfs /dev/disk0s1s2 /mnt2"
    if [ "$iosversion" = '8.4.1' ]; then
        ./sshpass -p "alpine" scp -P 2222 ios8.tar root@localhost:/mnt2
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/ios8.tar -C /mnt1"
    elif [ "$iosversion" = '7.1.2' ]; then
        ./sshpass -p "alpine" scp -P 2222 ios712.tar root@localhost:/mnt2
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/ios712.tar -C /mnt1"
    elif [ "$iosversion" = '7.0.6' ]; then
        ./sshpass -p "alpine" scp -P 2222 ios706.tar root@localhost:/mnt2
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/ios706.tar -C /mnt1"
    elif [ "$iosversion" = '9.3.2' ]; then
        ./sshpass -p "alpine" scp -P 2222 ios9.tar root@localhost:/mnt2
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/ios9.tar -C /mnt1"
    fi
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv -v /mnt1/private/var/* /mnt2"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt1/usr/local/standalone/firmware/Baseband"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir /mnt2/keybags"
    ./sshpass -p "alpine" scp -r -P 2222 ./keybags root@localhost:/mnt2
    ./sshpass -p "alpine" scp -r -P 2222 ./Baseband root@localhost:/mnt1/usr/local/standalone/firmware
    ./sshpass -p "alpine" scp -P 2222 ./apticket.der root@localhost:/mnt1/System/Library/Caches/
    ./sshpass -p "alpine" scp -P 2222 ./sep-firmware.img4 root@localhost:/mnt1/usr/standalone/firmware/
    ./sshpass -p "alpine" scp -P 2222 ./fstab root@localhost:/mnt1/etc/
    read -p "would you like to also delete Setup.app? " response2
    if [[ "$response2" = 'yes' || "$response2" = 'y' ]]; then
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/Applications/Setup.app"
        ./sshpass -p "alpine" scp -P 2222 ./data_ark.plist.tar root@localhost:/mnt2/
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist.tar -C /mnt2"
    fi
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/ios706.tar"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/ios712.tar"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/ios8.tar"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/ios9.tar"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/log/asl/SweepStore"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/Library/PreinstalledAssets/*"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/Library/Preferences/.GlobalPreferences.plist"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/.forward"
    ./sshpass -p "alpine" scp -P 2222 ./fixkeybag root@localhost:/mnt1/usr/libexec/
    ./sshpass -p "alpine" scp -P 2222 ./work/kernelcache root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches
    if [ "$iosversion" = '9.3.2' ]; then
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram oblit-inprogress=5"
    fi
    if [ "$iosversion" = '7.1.2' ]; then
        echo "reboot"
    elif [ "$iosversion" = '7.0.6' ]; then
        echo "reboot"
    else
        ssh -p2222 root@localhost
    fi
    $(./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" &)
else
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s2 /mnt2"
    ./sshpass -p "alpine" scp -P 2222 ./work/kernelcache root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches
    ssh -p2222 root@localhost
    $(./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" &)
fi
mkdir work
cp IM4M work
cd work
if [ -e devicetree.img4 ]; then
    _wait_for_dfu
    ../ipwnder -p
    ../irecovery -f iBSS.img4
    ../irecovery -f iBSS.img4
    ../irecovery -f iBEC.img4
    ../irecovery -f devicetree.img4
    ../irecovery -c devicetree
    ../irecovery -f kernelcache.img4
    ../irecovery -c bootx &
fi
