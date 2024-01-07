#/bin/bash
_wait_for_dfu() {
    if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi
    
    while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
}

_download_boot_files() {
    # deviceid arg 1
    # replacc arg 2
    # version arg 3
    # Copy required library for taco to work to /usr/bin
    sudo rm -rf /usr/bin/img4
    sudo cp ./img4 /usr/bin/img4
    sudo rm -rf /usr/local/bin/img4
    sudo cp ./img4 /usr/local/bin/img4
    # Copy required library for taco to work to /usr/bin
    sudo rm -rf /usr/bin/dmg
    sudo cp ./dmg /usr/bin/dmg
    sudo rm -rf /usr/local/bin/dmg
    sudo cp ./dmg /usr/local/bin/dmg

    rm -rf kernelcache.dec
    rm -rf iBSS.dec
    rm -rf iBEC.dec
    rm -rf DeviceTree.dec
    rm -rf OS.dec
    rm -rf RestoreRamDisk.dec

    rm -rf $1/$3

    mkdir -p $1/$3

    ./pzb -g BuildManifest.plist "$ipswurl"

    # Download kernelcache
    ./pzb -g "$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipswurl"
    # Decrypt kernelcache
    # note that as per src/decrypt.rs it will not rename the file
    cargo run decrypt $1 $3 $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) -l
    # so we shall rename the file ourselves
    mv $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) $1/$3/kernelcache.dec

    # Download iBSS
    ./pzb -g $(awk "/""$2""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
    # Decrypt iBSS
    ./gaster decrypt $(awk "/""$2""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//') $1/$3/iBSS.dec

    # Download iBEC
    ./pzb -g $(awk "/""$2""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
    # Decrypt iBEC
    ./gaster decrypt $(awk "/""$2""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//') $1/$3/iBEC.dec

    # Download DeviceTree
    ./pzb -g $(awk "/""$2""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
    # Decrypt DeviceTree
    ./gaster decrypt $(awk "/""$2""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash.*production[/]//') $1/$3/DeviceTree.dec

    # Download root fs
    ./pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
    # Decrypt root fs
    # note that as per src/decrypt.rs it will rename the file to OS.dmg by default
    cargo run decrypt $1 $3 "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -l
    osfn="$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)"
    mv $(echo $osfn | sed "s/dmg/bin/g") $1/$3/OS.dec

    # Download RestoreRamDisk
    ./pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
    # Decrypt RestoreRamDisk
    ./gaster decrypt "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" $1/$3/RestoreRamDisk.dec
}

_wait_for_dfu

check=$(./irecovery -q | grep CPID | sed 's/CPID: //')
replace=$(./irecovery -q | grep MODEL | sed 's/MODEL: //')
deviceid=$(./irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'$1'")' | ./jq -s '.[0] | .url' --raw-output)

# Copy required library for taco to work to /usr/bin
sudo rm -rf /usr/bin/img4
sudo cp ./img4 /usr/bin/img4
sudo rm -rf /usr/local/bin/img4
sudo cp ./img4 /usr/local/bin/img4
# Copy required library for taco to work to /usr/bin
sudo rm -rf /usr/bin/dmg
sudo cp ./dmg /usr/bin/dmg
sudo rm -rf /usr/local/bin/dmg
sudo cp ./dmg /usr/local/bin/dmg

rm -rf kernelcache.dec
rm -rf iBSS.dec
rm -rf iBEC.dec
rm -rf DeviceTree.dec
rm -rf OS.dec
rm -rf RestoreRamDisk.dec

rm -rf $deviceid/$1

mkdir -p $deviceid/$1

_download_boot_files $deviceid $replace $1