#/bin/bash
mkdir -p logs
verbose=1
sudo xattr -cr .
{
echo "[*] Command ran:`if [ $EUID = 0 ]; then echo " sudo"; fi` ./semaphorin.sh $@"
os=$(uname)
os_ver=$(sw_vers -productVersion)
maj_ver=$(echo "$os_ver" | awk -F. '{print $1}')
dir="$(pwd)"
bin="$(pwd)/$(uname)"
sshtars="$(pwd)/sshtars"
echo "Semaphorin | Version 1.0"
echo "Written by y08wilm and Mineek | Some code and ramdisk from Nathan"
echo ""
max_args=1
arg_count=0

# This would probably go better somewhere else, but I'm not sure where to put it since most of the script is just in functions.

if [[ $os =~ Darwin ]]; then
        echo "[*] Running on Darwin..."
elif [[ $os =~ Linux ]]; then
        echo "[!] This tool does not support Linux. Please use this with macOS High Sierra, Mojave, or Catalina to continue."
        exit 1
else
        echo "[!] What operating system are you even using..."
        exit 1
fi


if [[ $os_ver =~ ^10\.1[3-5]\.* ]]; then
        echo "[*] You are running macOS $os_ver. Continuing..."
elif (( $maj_ver >= 11 )); then
        echo "[!] macOS $os_ver is too new for this script. Please install macOS High Sierra, Mojave, or Catalina to continue if possible."
        read -p "[*] You can press the enter key on your keyboard to skip this warning  " r1
else    
        echo "[!] macOS/OS X $os_ver is not supported by this script. Please install macOS High Sierra, Mojave, or Catalina to continue if possible." 
        read -p "[*] You can press the enter key on your keyboard to skip this warning  " r1
fi


print_help() {
    cat << EOF
Usage: $0 [VERSION...] [OPTION...]
iOS 7.0.1-9.2.1 Downgrade & Jailbreak tool for older checkm8 devices using seprmvr64
Examples:
    $0 7.1.2 --restore
    $0 7.1.2 --boot

Main operation mode:
    --help                     Print this help
    --ramdisk                  Download& enter ramdisk
    --dump-blobs               Self explanatory
    --serial                   Enable serial debugging
    --ssh                      Tries to connect to ssh over usb interface to the connected device
    --restore                  Wipe device and downgrade ios
    --dump-nand                Backs up the entire contents of your iOS device to disk0.gz
    --NoMoreSIGABRT            Adds the "protect" flag to /dev/disk0s1s2
    --disable-NoMoreSIGABRT    Removes the "protect" flag from /dev/disk0s1s2
    --restore-nand             Copies the contents of disk0.gz to /dev/disk0 of the iOS device
    --restore-mnt1             Copies the contents of disk0s1s1.gz to /dev/disk0s1s1 of the iOS device
    --restore-mnt2             Copies the contents of disk0s1s2.gz to /dev/disk0s1s2 of the iOS device
    --boot                     Don't enter ramdisk or wipe device, just boot
    --clean                    Delete all the created boot files for your device
    --fix-activation           Fixes activation on iOS 10.3.3-11.1 so you can navigate through Setup.app
    --fix-auto-boot            Fixes booting into the main OS on A11 devices such as the iPhone X

The iOS version argument should be the iOS version you are downgrading to.
EOF
}
remote_cmd() {
    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "$@"
}
parse_opt() {
    case "$1" in
        --)
            no_more_opts=1
            ;;
        --ramdisk)
            ramdisk=1
            ;;
        --dump-blobs)
            dump_blobs=1
            ;;
        --serial)
            serial=1
            ;;
        --dump-nand)
            dump_nand=1
            ;;
        --NoMoreSIGABRT)
            NoMoreSIGABRT=1
            ;;
        --disable-NoMoreSIGABRT)
            disable_NoMoreSIGABRT=1
            ;;
        --restore-nand)
            restore_nand=1
            ;;
        --restore-mnt1)
            restore_mnt1=1
            ;;
        --restore-mnt2)
            restore_mnt2=1
            ;;
        --fix-activation)
            fix_activation=1
            ;;
        --ssh)
            _kill_if_running iproxy
            "$bin"/iproxy 2222 22 &
            ssh -o StrictHostKeyChecking=no -p2222 root@localhost
            exit 0
            ;;
        --restore)
            restore=1
            ;;
        --boot)
            boot=1
            ;;
        --clean)
            clean=1
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "[-] Unknown option $1. Use $0 --help for help."
            exit 1;
    esac
}

parse_arg() {
    arg_count=$((arg_count + 1))
    case "$1" in
        clean)
            clean=1
            hit=1
            ;;
        ssh)
            _kill_if_running iproxy
            "$bin"/iproxy 2222 22 &
            ssh -o StrictHostKeyChecking=no -p2222 root@localhost
            exit 0
            ;;
        *)
            if [ -z "$version" ]; then
                version="$1"
            fi
            if [[ "$version" == "8.0b4" ]]; then
                version="8.0"
            fi
            if [[ "$version" == "11.0b1" ]]; then
                version="11.0"
            fi
            if [[ "$version" == "11.4.1" ]]; then
                version="11.4"
            fi
            ;;
    esac
}
parse_cmdline() {
    if [ -z "$1" ]; then
        print_help
        exit 0
    fi
    hit=0
    for arg in $@; do
        if [[ "$arg" == --* ]] && [ -z "$no_more_opts" ]; then
            parse_opt "$arg";
            hit=1
        elif [ "$arg_count" -lt "$max_args" ]; then
            parse_arg "$arg";
        else
            echo "[-] Too many arguments. Use $0 --help for help.";
            exit 1;
        fi
    done
    if [[ "$hit" == 0 ]]; then
        print_help
        exit 0
    fi
    if [ -z "$version" ]; then
        print_help
        exit 0
    fi
}
_wait_for_dfu() {
    if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi
    
    while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
}
_download_ramdisk_boot_files() {
    ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'$3'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
    rm -rf BuildManifest.plist
    mkdir -p "$dir"/$1/$cpid/ramdisk/$3
    rm -rf "$dir"/work
    mkdir "$dir"/work
    cd "$dir"/work
    "$bin"/img4tool -e -s "$dir"/other/shsh/"${check}".shsh -m IM4M
    if [ ! -e "$dir"/$1/$cpid/ramdisk/$3/ramdisk.img4 ]; then
        if [[ "$3" == "10."* ]]; then
            if [[ "$deviceid" == "iPhone8,1" || "$deviceid" == "iPhone8,2" ]]; then
                ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'11.1'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
            else
                ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'10.3.3'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
            fi
        fi
        "$bin"/pzb -g BuildManifest.plist "$ipswurl"
        if [ ! -e "$dir"/$1/$cpid/ramdisk/$3/iBSS.dec ]; then
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
            fn="$(awk "/""$replace""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')"
            if [[ "$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -e $3 $1)" == "true" ]]; then
                if [[ "$3" == "10."* ]]; then
                    if [[ "$deviceid" == "iPhone8,1" || "$deviceid" == "iPhone8,2" ]]; then
                        ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 11.1 $1)"
                    else
                        ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 10.3.3 $1)"
                    fi
                else
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                fi
            else
                fn2="$fn.dec"
                "$bin"/gaster decrypt $fn $fn2
                fn="$fn2"
            fi
            "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/ramdisk/$3/iBSS.dec -k $ivkey
        fi
        if [ ! -e "$dir"/$1/$cpid/ramdisk/$3/iBEC.dec ]; then
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
            fn="$(awk "/""$replace""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')"
            if [[ "$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -e $3 $1)" == "true" ]]; then
                if [[ "$3" == "10."* ]]; then
                    if [[ "$deviceid" == "iPhone8,1" || "$deviceid" == "iPhone8,2" ]]; then
                        ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 11.1 $1)"
                    else
                        ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 10.3.3 $1)"
                    fi
                else
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                fi
            else
                fn2="$fn.dec"
                "$bin"/gaster decrypt $fn $fn2
                fn="$fn2"
            fi
            "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/ramdisk/$3/iBEC.dec -k $ivkey
        fi
        if [[ "$3" == "10."* ]]; then
            rm -rf BuildManifest.plist
            ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'$3'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
            "$bin"/pzb -g BuildManifest.plist "$ipswurl"
        fi
        if [ ! -e "$dir"/$1/$cpid/ramdisk/$3/kernelcache.dec ]; then
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) "$ipswurl"
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                fn="$(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)"
                ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/ramdisk/$3/kcache.raw -k $ivkey
                "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/ramdisk/$3/kernelcache.dec -k $ivkey -D
            else
                "$bin"/img4 -i $(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) -o "$dir"/$1/$cpid/ramdisk/$3/kcache.raw
                "$bin"/img4 -i $(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) -o "$dir"/$1/$cpid/ramdisk/$3/kernelcache.dec -D
            fi
        fi
        if [ ! -e "$dir"/$1/$cpid/ramdisk/$3/DeviceTree.dec ]; then
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                fn="$(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash.*production[/]//' | sed 's/Firmware[/]all_flash[/]//')"
                ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/ramdisk/$3/DeviceTree.dec -k $ivkey
            else
                mv $(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash.*production[/]//' | sed 's/Firmware[/]all_flash[/]//') "$dir"/$1/$cpid/ramdisk/$3/DeviceTree.dec
            fi
        fi
        if [ ! -e "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg ]; then
            "$bin"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                fn="$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)"
                ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg -k $ivkey
            else
                "$bin"/img4 -i "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg
            fi
        fi
        if [[ ! "$3" == "7."* && ! "$3" == "8."* && ! "$3" == "9."* && ! "$3" == "10."* && ! "$3" == "11."* ]]; then
            if [ ! -e "$dir"/$1/$cpid/ramdisk/$3/trustcache.img4 ]; then
                "$bin"/pzb -g Firmware/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$ipswurl"
                 mv "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$dir"/$1/$cpid/ramdisk/$3/trustcache.im4p
            fi
        fi
        rm -rf BuildManifest.plist
        if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
            if [[ "$3" == "9."* ]]; then
                hdiutil resize -size 80M "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg
            else
                hdiutil resize -size 60M "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg
            fi
            hdiutil attach -mountpoint /tmp/ramdisk "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg
            sudo diskutil enableOwnership /tmp/ramdisk
            sudo "$bin"/gnutar -xzvf "$sshtars"/ssh.tar.gz -C /tmp/ramdisk
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* || "$3" == "10."* || "$3" == "11."* ]]; then
                # fix scp
                sudo "$bin"/gnutar -xvf "$dir"/jb/libcharset.1.dylib_libiconv.2.dylib.tar -C /tmp/ramdisk/usr/lib
            fi
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* || "$3" == "10."* || "$3" == "11."* || "$3" == "12."* || "$3" == "13.0"* || "$3" == "13.1"* || "$3" == "13.2"* || "$3" == "13.3"* ]]; then
                # fix scp
                sudo "$bin"/gnutar -xvf "$dir"/jb/libresolv.9.dylib.tar -C /tmp/ramdisk/usr/lib
            fi
            # gptfdisk automation shenanigans
            sudo "$bin"/gnutar -xvf "$dir"/jb/gpt.txt.tar -C /tmp/ramdisk
            hdiutil detach /tmp/ramdisk
            "$bin"/img4tool -c "$dir"/$1/$cpid/ramdisk/$3/ramdisk.im4p -t rdsk "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg
            "$bin"/img4tool -c "$dir"/$1/$cpid/ramdisk/$3/ramdisk.img4 -p "$dir"/$1/$cpid/ramdisk/$3/ramdisk.im4p -m IM4M
            if [[ "$3" == "9."* ]]; then
                "$bin"/iBoot64Patcher "$dir"/$1/$cpid/ramdisk/$3/iBSS.dec "$dir"/$1/$cpid/ramdisk/$3/iBSS.patched
                "$bin"/iBoot64Patcher "$dir"/$1/$cpid/ramdisk/$3/iBEC.dec "$dir"/$1/$cpid/ramdisk/$3/iBEC.patched -b "amfi=0xff cs_enforcement_disable=1 $boot_args rd=md0 nand-enable-reformat=1 -progress"
            else
                "$bin"/ipatcher "$dir"/$1/$cpid/ramdisk/$3/iBSS.dec "$dir"/$1/$cpid/ramdisk/$3/iBSS.patched
                "$bin"/ipatcher "$dir"/$1/$cpid/ramdisk/$3/iBEC.dec "$dir"/$1/$cpid/ramdisk/$3/iBEC.patched -b "amfi=0xff cs_enforcement_disable=1 $boot_args rd=md0 nand-enable-reformat=1 -progress"
            fi
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/iBSS.patched -o "$dir"/$1/$cpid/ramdisk/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/iBEC.patched -o "$dir"/$1/$cpid/ramdisk/$3/iBEC.img4 -M IM4M -A -T ibec
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/kernelcache.dec -o "$dir"/$1/$cpid/ramdisk/$3/kernelcache.img4 -M IM4M -T rkrn
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/devicetree.dec -o "$dir"/$1/$cpid/ramdisk/$3/devicetree.img4 -A -M IM4M -T rdtr
        else
            hdiutil resize -size 120M "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg
            hdiutil attach -mountpoint /tmp/ramdisk "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg
            sudo diskutil enableOwnership /tmp/ramdisk
            sudo "$bin"/gnutar -xzvf "$sshtars"/ssh.tar.gz -C /tmp/ramdisk
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* || "$3" == "10."* || "$3" == "11."* ]]; then
                # fix scp
                sudo "$bin"/gnutar -xvf "$dir"/jb/libcharset.1.dylib_libiconv.2.dylib.tar -C /tmp/ramdisk/usr/lib
            fi
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* || "$3" == "10."* || "$3" == "11."* || "$3" == "12."* || "$3" == "13.0"* || "$3" == "13.1"* || "$3" == "13.2"* || "$3" == "13.3"* ]]; then
                # fix scp
                sudo "$bin"/gnutar -xvf "$dir"/jb/libresolv.9.dylib.tar -C /tmp/ramdisk/usr/lib
            fi
            # gptfdisk automation shenanigans
            sudo "$bin"/gnutar -xvf "$dir"/jb/gpt.txt.tar -C /tmp/ramdisk
            hdiutil detach /tmp/ramdisk
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/RestoreRamDisk.dmg -o "$dir"/$1/$cpid/ramdisk/$3/ramdisk.img4 -M IM4M -A -T rdsk
            "$bin"/iBoot64Patcher "$dir"/$1/$cpid/ramdisk/$3/iBSS.dec "$dir"/$1/$cpid/ramdisk/$3/iBSS.patched
            if [[ ! "$deviceid" == "iPhone6"* && ! "$deviceid" == "iPhone7"* && ! "$deviceid" == "iPad4"* && ! "$deviceid" == "iPad5"* && ! "$deviceid" == "iPod7"* ]]; then
                "$bin"/iBoot64Patcher "$dir"/$1/$cpid/ramdisk/$3/iBEC.dec "$dir"/$1/$cpid/ramdisk/$3/iBEC.patched -b "rd=md0 debug=0x2014e $boot_args wdt=-1 `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "-restore"; fi`"
            else
                "$bin"/iBoot64Patcher "$dir"/$1/$cpid/ramdisk/$3/iBEC.dec "$dir"/$1/$cpid/ramdisk/$3/iBEC.patched -b "amfi=0xff cs_enforcement_disable=1 $boot_args rd=md0 nand-enable-reformat=1 amfi_get_out_of_my_way=1 -restore -progress" -n
            fi
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/iBSS.patched -o "$dir"/$1/$cpid/ramdisk/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/iBEC.patched -o "$dir"/$1/$cpid/ramdisk/$3/iBEC.img4 -M IM4M -A -T ibec
            if [[ "$3" == "10.3"* ]]; then
                "$bin"/KPlooshFinder "$dir"/$1/$cpid/ramdisk/$3/kcache.raw "$dir"/$1/$cpid/ramdisk/$3/kcache2.patched
            else
                "$bin"/Kernel64Patcher2 "$dir"/$1/$cpid/ramdisk/$3/kcache.raw "$dir"/$1/$cpid/ramdisk/$3/kcache2.patched -a
            fi
            "$bin"/kerneldiff "$dir"/$1/$cpid/ramdisk/$3/kcache.raw "$dir"/$1/$cpid/ramdisk/$3/kcache2.patched "$dir"/$1/$cpid/ramdisk/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/kernelcache.dec -o "$dir"/$1/$cpid/ramdisk/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/ramdisk/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/kernelcache.dec -o "$dir"/$1/$cpid/ramdisk/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/ramdisk/$3/kc.bpatch
            if [[ ! "$3" == "7."* && ! "$3" == "8."* && ! "$3" == "9."* && ! "$3" == "10."* && ! "$3" == "11."* ]]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/trustcache.im4p -o "$dir"/$1/$cpid/ramdisk/$3/trustcache.img4 -M IM4M -T rtsc
            fi
            "$bin"/img4 -i "$dir"/$1/$cpid/ramdisk/$3/devicetree.dec -o "$dir"/$1/$cpid/ramdisk/$3/devicetree.img4 -M IM4M -T rdtr
        fi
    fi
    cd ..
    rm -rf work
}
_download_boot_files() {
    ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'$3'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
    rm -rf BuildManifest.plist
    mkdir -p "$dir"/$1/$cpid/$3
    rm -rf "$dir"/work
    mkdir "$dir"/work
    cd "$dir"/work
    "$bin"/img4tool -e -s "$dir"/other/shsh/"${check}".shsh -m IM4M
    if [ ! -e "$dir"/$1/$cpid/$3/kernelcache ]; then
        if [[ "$3" == "10."* ]]; then
            if [[ "$deviceid" == "iPhone8,1" || "$deviceid" == "iPhone8,2" ]]; then
                ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'11.1'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
            else
                ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'10.3.3'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
            fi
        fi
        "$bin"/pzb -g BuildManifest.plist "$ipswurl"
        if [ ! -e "$dir"/$1/$cpid/$3/iBSS.dec ]; then
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
            fn="$(awk "/""$replace""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')"
            if [[ "$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -e $3 $1)" == "true" ]]; then
                if [[ "$3" == "10."* ]]; then
                    if [[ "$deviceid" == "iPhone8,1" || "$deviceid" == "iPhone8,2" ]]; then
                        ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 11.1 $1)"
                    else
                        ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 10.3.3 $1)"
                    fi
                else
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                fi
            else
                fn2="$fn.dec"
                "$bin"/gaster decrypt $fn $fn2
                fn="$fn2"
            fi
            "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/iBSS.dec -k $ivkey
        fi
        if [ ! -e "$dir"/$1/$cpid/$3/iBEC.dec ]; then
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
            fn="$(awk "/""$replace""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')"
            if [[ "$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -e $3 $1)" == "true" ]]; then
                if [[ "$3" == "10."* ]]; then
                    if [[ "$deviceid" == "iPhone8,1" || "$deviceid" == "iPhone8,2" ]]; then
                        ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 11.1 $1)"
                    else
                        ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 10.3.3 $1)"
                    fi
                else
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                fi
            else
                fn2="$fn.dec"
                "$bin"/gaster decrypt $fn $fn2
                fn="$fn2"
            fi
            "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/iBEC.dec -k $ivkey
        fi
        if [[ "$3" == "10."* ]]; then
            rm -rf BuildManifest.plist
            ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'$3'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
            "$bin"/pzb -g BuildManifest.plist "$ipswurl"
        fi
        if [ ! -e "$dir"/$1/$cpid/$3/kernelcache.dec ]; then
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) "$ipswurl"
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                fn="$(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)"
                ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/kcache.raw -k $ivkey
                "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/kernelcache.dec -k $ivkey -D
            else
                "$bin"/img4 -i $(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) -o "$dir"/$1/$cpid/$3/kcache.raw
                "$bin"/img4 -i $(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) -o "$dir"/$1/$cpid/$3/kernelcache.dec -D
            fi
        fi
        if [ ! -e "$dir"/$1/$cpid/$3/DeviceTree.dec ]; then
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                fn="$(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash.*production[/]//' | sed 's/Firmware[/]all_flash[/]//')"
                ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/DeviceTree.dec -k $ivkey
            else
                mv $(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash.*production[/]//' | sed 's/Firmware[/]all_flash[/]//') "$dir"/$1/$cpid/$3/DeviceTree.dec
            fi
        fi
        if [[ ! "$3" == "7."* && ! "$3" == "8."* && ! "$3" == "9."* ]]; then
            if [ ! -e "$dir"/$1/$cpid/$3/aopfw.dec ]; then
                "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/aopfw/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)  "$ipswurl"
                if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                    fn="$(awk "/""$replace""/{x=1}x&&/aopfw/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]AOP[/]//' | sed 's/Firmware[/]//')"
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                    "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/aopfw.dec -k $ivkey
                else
                    mv $(awk "/""$replace""/{x=1}x&&/aopfw/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]AOP[/]//' | sed 's/Firmware[/]//') "$dir"/$1/$cpid/$3/aopfw.dec
                fi
            fi
        fi
        if [[ ! "$3" == "7."* && ! "$3" == "8."* && ! "$3" == "9."* ]]; then
            if [ ! -e "$dir"/$1/$cpid/$3/homerfw.dec ]; then
                "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/homer/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)  "$ipswurl"
                if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                    fn="$(awk "/""$replace""/{x=1}x&&/homer/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]//')"
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                    "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/homerfw.dec -k $ivkey
                else
                    mv $(awk "/""$replace""/{x=1}x&&/homer/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]//') "$dir"/$1/$cpid/$3/homerfw.dec
                fi
            fi
        fi
        if [[ ! "$3" == "7."* && ! "$3" == "8."* && ! "$3" == "9."* ]]; then
            if [ ! -e "$dir"/$1/$cpid/$3/avefw.dec ]; then
                "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/ave/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)  "$ipswurl"
                if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                    fn="$(awk "/""$replace""/{x=1}x&&/ave/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]ave[/]//' | sed 's/Firmware[/]//')"
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                    "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/avefw.dec -k $ivkey
                else
                    mv $(awk "/""$replace""/{x=1}x&&/ave/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]ave[/]//' | sed 's/Firmware[/]//') "$dir"/$1/$cpid/$3/avefw.dec
                fi
            fi
        fi
        if [[ ! "$3" == "7."* && ! "$3" == "8."* && ! "$3" == "9."* ]]; then
            if [ ! -e "$dir"/$1/$cpid/$3/multitouch.dec ]; then
                "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/[_]Multitouch/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)  "$ipswurl"
                if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                    fn="$(awk "/""$replace""/{x=1}x&&/[_]Multitouch/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]Multitouch[/]//' | sed 's/Firmware[/]//')"
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                    "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/multitouch.dec -k $ivkey
                else
                    mv $(awk "/""$replace""/{x=1}x&&/[_]Multitouch/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]Multitouch[/]//' | sed 's/Firmware[/]//') "$dir"/$1/$cpid/$3/multitouch.dec
                fi
            fi
        fi
        if [[ ! "$3" == "7."* && ! "$3" == "8."* && ! "$3" == "9."* ]]; then
            if [ ! -e "$dir"/$1/$cpid/$3/audiocodecfirmware.dec ]; then
                "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/[A]udioDSP/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)  "$ipswurl"
                if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                    fn="$(awk "/""$replace""/{x=1}x&&/[A]udioDSP/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]Callan[/]//' | sed 's/Firmware[/]//')"
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                    "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/audiocodecfirmware.dec -k $ivkey
                else
                    mv $(awk "/""$replace""/{x=1}x&&/[A]udioDSP/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]Callan[/]//' | sed 's/Firmware[/]//') "$dir"/$1/$cpid/$3/audiocodecfirmware.dec
                fi
            fi
        fi
        if [ ! -e "$dir"/$1/$cpid/$3/RestoreRamDisk.dmg ]; then
            "$bin"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
            if [[ "$3" == "7."* || "$3" == "8."* || "$3" == "9."* ]]; then
                fn="$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)"
                ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                "$bin"/img4 -i $fn -o "$dir"/$1/$cpid/$3/RestoreRamDisk.dmg -k $ivkey
            else
                "$bin"/img4 -i "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o "$dir"/$1/$cpid/$3/RestoreRamDisk.dmg
            fi
        fi
        if [[ ! "$3" == "7."* && ! "$3" == "8."* && ! "$3" == "9."* && ! "$3" == "10."* && ! "$3" == "11."* ]]; then
            if [ ! -e "$dir"/$1/$cpid/$3/trustcache.img4 ]; then
                "$bin"/pzb -g Firmware/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$ipswurl"
                 mv "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$dir"/$1/$cpid/$3/trustcache.im4p
            fi
        fi
        rm -rf BuildManifest.plist
        if [[ "$3" == "7."* ]]; then
            "$bin"/ipatcher "$dir"/$1/$cpid/$3/iBSS.dec "$dir"/$1/$cpid/$3/iBSS.patched
            "$bin"/ipatcher "$dir"/$1/$cpid/$3/iBEC.dec "$dir"/$1/$cpid/$3/iBEC.patched -b "$boot_args rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1 PE_i_can_has_debugger=1 amfi_get_out_of_my_way=0x1 amfi_unrestrict_task_for_pid=0x0"
        elif [[ "$3" == "8."* ]]; then
            "$bin"/ipatcher "$dir"/$1/$cpid/$3/iBSS.dec "$dir"/$1/$cpid/$3/iBSS.patched
            "$bin"/ipatcher "$dir"/$1/$cpid/$3/iBEC.dec "$dir"/$1/$cpid/$3/iBEC.patched -b "$boot_args rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e PE_i_can_has_debugger=1"
        elif [[ "$3" == "9."* ]]; then
            "$bin"/iBoot64Patcher "$dir"/$1/$cpid/$3/iBSS.dec "$dir"/$1/$cpid/$3/iBSS.patched
            "$bin"/iBoot64Patcher "$dir"/$1/$cpid/$3/iBEC.dec "$dir"/$1/$cpid/$3/iBEC.patched -b "$boot_args rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e PE_i_can_has_debugger=1 amfi_get_out_of_my_way=1 amfi_allow_any_signature=1"
        else
            "$bin"/iBoot64Patcher "$dir"/$1/$cpid/$3/iBSS.dec "$dir"/$1/$cpid/$3/iBSS.patched
            if [[ "$3" == "10.3"* || "$3" == "11."* || "$3" == "12."* ]]; then
                "$bin"/iBoot64Patcher "$dir"/$1/$cpid/$3/iBEC.dec "$dir"/$1/$cpid/$3/iBEC.patched2 -b "$boot_args rd=disk0s1s8 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x100 PE_i_can_has_debugger=1 amfi_get_out_of_my_way=1 amfi_allow_any_signature=1" -n
                "$bin"/kairos "$dir"/$1/$cpid/$3/iBEC.patched2 "$dir"/$1/$cpid/$3/iBEC.patched -d 8
            else
                "$bin"/iBoot64Patcher "$dir"/$1/$cpid/$3/iBEC.dec "$dir"/$1/$cpid/$3/iBEC.patched -b "$boot_args rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e PE_i_can_has_debugger=1 amfi_get_out_of_my_way=1 amfi_allow_any_signature=1" -n
            fi
        fi
        if [[ "$3" == "8.0" ]]; then
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBSS.patched -o "$dir"/$1/$cpid/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBEC.patched -o "$dir"/$1/$cpid/$3/iBEC.img4 -M IM4M -A -T ibec
            if [[ "$deviceid" == "iPhone6,2" || "$deviceid" == "iPhone6,1" || "$deviceid" == "iPad4,4" || "$deviceid" == "iPad4,5" || "$deviceid" == "iPad4,2" || "$deviceid" == "iPad4,8" ]]; then
                "$bin"/seprmvr64lite "$dir"/$1/$cpid/$3/kcache_12A4331d.raw "$dir"/$1/$cpid/$3/kcache.patched
                "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched -t -p -f -a -m -g -s
                "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache_12A4331d.raw "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kc.bpatch
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache_12A4331d.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache_12A4331d.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            else
                "$bin"/seprmvr64lite "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache.patched
                "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched -t -p -f -a -m -g -s
                "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kc.bpatch
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            fi
            "$bin"/dtree_patcher "$dir"/$1/$cpid/$3/devicetree.dec "$dir"/$1/$cpid/$3/DeviceTree.patched -n
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/DeviceTree.patched -o "$dir"/$1/$cpid/$3/devicetree.img4 -A -M IM4M -T rdtr
        elif [[ "$3" == "8."* ]]; then
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBSS.patched -o "$dir"/$1/$cpid/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBEC.patched -o "$dir"/$1/$cpid/$3/iBEC.img4 -M IM4M -A -T ibec
            "$bin"/seprmvr64lite "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache.patched
            "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched -t -p -e -f -a -m -g -s
            "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/dtree_patcher "$dir"/$1/$cpid/$3/devicetree.dec "$dir"/$1/$cpid/$3/DeviceTree.patched -n
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/DeviceTree.patched -o "$dir"/$1/$cpid/$3/devicetree.img4 -A -M IM4M -T rdtr
        elif [[ "$3" == "9."* ]]; then
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBSS.patched -o "$dir"/$1/$cpid/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBEC.patched -o "$dir"/$1/$cpid/$3/iBEC.img4 -M IM4M -A -T ibec
            # seprmvr64lite2 is seprmvr64lite but with only these patches
            # \x1b[35m ***** SEP Panicked! dumping log. *****\x1b[0m
            # AppleKeyStore: operation failed (pid: %d sel: %d ret: %x)
            # AssertMacros: %s (value = 0x%lx), %s file: %s, line: %d
            # "SEP/OS failed to boot"
            # "REQUIRE fail: %s @ %s:%u:%s: "
            "$bin"/seprmvr64lite2 "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache.patched
            # -e is vm_map_enter, -l is vm_map_protect, -f is vm_fault_enter, -t is tfp0, -m is mount_common, -a is mapIO, -s is PE_i_can_has_debugger, -p is sandbox_trace, and -j is sandbox patch
            "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched -e -l -f -t -m -a -s -p -j
            "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/dtree_patcher "$dir"/$1/$cpid/$3/devicetree.dec "$dir"/$1/$cpid/$3/DeviceTree.patched -n
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/DeviceTree.patched -o "$dir"/$1/$cpid/$3/devicetree.img4 -A -M IM4M -T rdtr
        elif [[ "$3" == "7."* ]]; then
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBSS.patched -o "$dir"/$1/$cpid/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBEC.patched -o "$dir"/$1/$cpid/$3/iBEC.img4 -M IM4M -A -T ibec
            "$bin"/seprmvr64lite "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache.patched
            "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched -m -e -f -k
            "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            cp "$dir"/$1/$cpid/$3/devicetree.dec "$dir"/$1/$cpid/$3/DeviceTree.patched
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/DeviceTree.patched -o "$dir"/$1/$cpid/$3/devicetree.img4 -A -M IM4M -T rdtr
        elif [[ "$3" == "10.0"* || "$3" == "10.1"* || "$3" == "10.2"* ]]; then
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBSS.patched -o "$dir"/$1/$cpid/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBEC.patched -o "$dir"/$1/$cpid/$3/iBEC.img4 -M IM4M -A -T ibec
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/aopfw.dec -o "$dir"/$1/$cpid/$3/aopfw.img4 -M IM4M -T aopf
            if [ -e "$dir"/$1/$cpid/$3/homerfw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/homerfw.dec -o "$dir"/$1/$cpid/$3/homerfw.img4 -M IM4M -T homr
            fi
            if [ -e "$dir"/$1/$cpid/$3/avefw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/avefw.dec -o "$dir"/$1/$cpid/$3/avefw.img4 -M IM4M -T avef
            fi
            if [ -e "$dir"/$1/$cpid/$3/multitouch.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/multitouch.dec -o "$dir"/$1/$cpid/$3/multitouch.img4 -M IM4M -T mtfw
            fi
            if [ -e "$dir"/$1/$cpid/$3/audiocodecfirmware.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/audiocodecfirmware.dec -o "$dir"/$1/$cpid/$3/audiocodecfirmware.img4 -M IM4M -T acfw
            fi
            # seprmvr64lite3 is seprmvr64lite but with only AppleKeyStore: operation failed (pid: %d sel: %d ret: %x) patch
            "$bin"/seprmvr64lite3 "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache.patched
            # seprmvr645 is plooshfinder seprmvr64 but with sks timeout strike patch removed
            "$bin"/seprmvr645 "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched
            # KPlooshFinder is amfi patch
            "$bin"/KPlooshFinder "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kcache3.patched
            # seprmvr643 just patches "SEP Panic" and may not even be required
            "$bin"/seprmvr643 "$dir"/$1/$cpid/$3/kcache3.patched "$dir"/$1/$cpid/$3/kcache4.patched
            # -a is mapIO, -f is vm_fault_enter, -h is sandbox patch, and -q is image4 validation patches
            "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache4.patched "$dir"/$1/$cpid/$3/kcache5.patched -a -f -h -q
            "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache5.patched "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            if [ -e "$dir"/$1/$cpid/$3/trustcache.im4p ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/trustcache.im4p -o "$dir"/$1/$cpid/$3/trustcache.img4 -M IM4M -T rtsc
            fi
            "$bin"/img4tool -e -o "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/devicetree.dec
            "$bin"/dtree_patcher "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/DeviceTree.patched -n
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/DeviceTree.patched -o "$dir"/$1/$cpid/$3/devicetree.img4 -A -M IM4M -T rdtr
        elif [[ "$3" == "10.3"* ]]; then
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBSS.patched -o "$dir"/$1/$cpid/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBEC.patched -o "$dir"/$1/$cpid/$3/iBEC.img4 -M IM4M -A -T ibec
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/aopfw.dec -o "$dir"/$1/$cpid/$3/aopfw.img4 -M IM4M -T aopf
            if [ -e "$dir"/$1/$cpid/$3/homerfw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/homerfw.dec -o "$dir"/$1/$cpid/$3/homerfw.img4 -M IM4M -T homr
            fi
            if [ -e "$dir"/$1/$cpid/$3/avefw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/avefw.dec -o "$dir"/$1/$cpid/$3/avefw.img4 -M IM4M -T avef
            fi
            if [ -e "$dir"/$1/$cpid/$3/multitouch.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/multitouch.dec -o "$dir"/$1/$cpid/$3/multitouch.img4 -M IM4M -T mtfw
            fi
            if [ -e "$dir"/$1/$cpid/$3/audiocodecfirmware.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/audiocodecfirmware.dec -o "$dir"/$1/$cpid/$3/audiocodecfirmware.img4 -M IM4M -T acfw
            fi
            # seprmvr64 is plooshfinder seprmvr64
            "$bin"/seprmvr64 "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache.patched
            # KPlooshFinder is amfi patch
            "$bin"/KPlooshFinder "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched
            # seprmvr643 just patches "SEP Panic" and may not even be required
            "$bin"/seprmvr643 "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kcache3.patched
            # -a is mapIO, -f is vm_fault_enter, and -q is image4 validation patches
            "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache3.patched "$dir"/$1/$cpid/$3/kcache4.patched -a -f -q
            "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache4.patched "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            if [ -e "$dir"/$1/$cpid/$3/trustcache.im4p ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/trustcache.im4p -o "$dir"/$1/$cpid/$3/trustcache.img4 -M IM4M -T rtsc
            fi
            "$bin"/img4tool -e -o "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/devicetree.dec
            "$bin"/dtree_patcher "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/DeviceTree.patched -n
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/DeviceTree.patched -o "$dir"/$1/$cpid/$3/devicetree.img4 -A -M IM4M -T rdtr
        elif [[ "$3" == "11."* ]]; then
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBSS.patched -o "$dir"/$1/$cpid/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBEC.patched -o "$dir"/$1/$cpid/$3/iBEC.img4 -M IM4M -A -T ibec
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/aopfw.dec -o "$dir"/$1/$cpid/$3/aopfw.img4 -M IM4M -T aopf
            if [ -e "$dir"/$1/$cpid/$3/homerfw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/homerfw.dec -o "$dir"/$1/$cpid/$3/homerfw.img4 -M IM4M -T homr
            fi
            if [ -e "$dir"/$1/$cpid/$3/avefw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/avefw.dec -o "$dir"/$1/$cpid/$3/avefw.img4 -M IM4M -T avef
            fi
            if [ -e "$dir"/$1/$cpid/$3/multitouch.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/multitouch.dec -o "$dir"/$1/$cpid/$3/multitouch.img4 -M IM4M -T mtfw
            fi
            if [ -e "$dir"/$1/$cpid/$3/audiocodecfirmware.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/audiocodecfirmware.dec -o "$dir"/$1/$cpid/$3/audiocodecfirmware.img4 -M IM4M -T acfw
            fi
            if [[ "$deviceid" == "iPhone8,1" && "$3" == "11.0" ]]; then
                # seprmvr64 is plooshfinder seprmvr64
                "$bin"/seprmvr647 "$dir"/$1/$cpid/$3/kcache_15A5278f.raw "$dir"/$1/$cpid/$3/kcache.patched
                # KPlooshFinder is amfi patch
                "$bin"/KPlooshFinder "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched
                # -a is mapIO, -f is vm_fault_enter, -m is mount_common, and -b is image4 validation patches
                "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kcache3.patched -a -f -m -b
                "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache_15A5278f.raw "$dir"/$1/$cpid/$3/kcache3.patched "$dir"/$1/$cpid/$3/kc.bpatch
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache_15A5278f.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache_15A5278f.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            else
                # seprmvr64 is plooshfinder seprmvr64
                "$bin"/seprmvr647 "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache.patched
                # KPlooshFinder is amfi patch
                "$bin"/KPlooshFinder "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched
                # -a is mapIO, -f is vm_fault_enter, -m is mount_common, and -b is image4 validation patches
                "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kcache3.patched -a -f -m -b
                "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache3.patched "$dir"/$1/$cpid/$3/kc.bpatch
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            fi
            if [ -e "$dir"/$1/$cpid/$3/trustcache.im4p ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/trustcache.im4p -o "$dir"/$1/$cpid/$3/trustcache.img4 -M IM4M -T rtsc
            fi
            "$bin"/img4tool -e -o "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/devicetree.dec
            "$bin"/dtree_patcher "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/DeviceTree.patched -n
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/DeviceTree.patched -o "$dir"/$1/$cpid/$3/devicetree.img4 -A -M IM4M -T rdtr
        elif [[ "$3" == "12.4"* || "$3" == "12.3"* || "$3" == "12.2"* ]]; then
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBSS.patched -o "$dir"/$1/$cpid/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBEC.patched -o "$dir"/$1/$cpid/$3/iBEC.img4 -M IM4M -A -T ibec
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/aopfw.dec -o "$dir"/$1/$cpid/$3/aopfw.img4 -M IM4M -T aopf
            if [ -e "$dir"/$1/$cpid/$3/homerfw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/homerfw.dec -o "$dir"/$1/$cpid/$3/homerfw.img4 -M IM4M -T homr
            fi
            if [ -e "$dir"/$1/$cpid/$3/avefw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/avefw.dec -o "$dir"/$1/$cpid/$3/avefw.img4 -M IM4M -T avef
            fi
            if [ -e "$dir"/$1/$cpid/$3/multitouch.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/multitouch.dec -o "$dir"/$1/$cpid/$3/multitouch.img4 -M IM4M -T mtfw
            fi
            if [ -e "$dir"/$1/$cpid/$3/audiocodecfirmware.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/audiocodecfirmware.dec -o "$dir"/$1/$cpid/$3/audiocodecfirmware.img4 -M IM4M -T acfw
            fi
            # seprmvr646 is plooshfinder seprmvr64 but with EP0 and AssertMacros patches removed
            "$bin"/seprmvr646 "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache.patched
            # KPlooshFinder is amfi patch
            "$bin"/KPlooshFinder "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched
            # seprmvr64lite4 is a less invasive AssertMacros patch that we have to use so it doesn't kernel panic during boot
            "$bin"/seprmvr64lite4 "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kcache3.patched
            # -a is mapIO, -m is mount_common, -f is vm_fault_enter, and -r is image4 validation patches
            "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache3.patched "$dir"/$1/$cpid/$3/kcache4.patched -a -m -r -f
            "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache4.patched "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            if [ -e "$dir"/$1/$cpid/$3/trustcache.im4p ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/trustcache.im4p -o "$dir"/$1/$cpid/$3/trustcache.img4 -M IM4M -T rtsc
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/trustcache.im4p -o "$dir"/$1/$cpid/$3/trustcache -M IM4M -T trst
            fi
            "$bin"/img4tool -e -o "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/devicetree.dec
            "$bin"/dtree_patcher "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/DeviceTree.patched -n
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/DeviceTree.patched -o "$dir"/$1/$cpid/$3/devicetree.img4 -A -M IM4M -T rdtr
        elif [[ "$3" == "12."* ]]; then
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBSS.patched -o "$dir"/$1/$cpid/$3/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/iBEC.patched -o "$dir"/$1/$cpid/$3/iBEC.img4 -M IM4M -A -T ibec
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/aopfw.dec -o "$dir"/$1/$cpid/$3/aopfw.img4 -M IM4M -T aopf
            if [ -e "$dir"/$1/$cpid/$3/homerfw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/homerfw.dec -o "$dir"/$1/$cpid/$3/homerfw.img4 -M IM4M -T homr
            fi
            if [ -e "$dir"/$1/$cpid/$3/avefw.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/avefw.dec -o "$dir"/$1/$cpid/$3/avefw.img4 -M IM4M -T avef
            fi
            if [ -e "$dir"/$1/$cpid/$3/multitouch.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/multitouch.dec -o "$dir"/$1/$cpid/$3/multitouch.img4 -M IM4M -T mtfw
            fi
            if [ -e "$dir"/$1/$cpid/$3/audiocodecfirmware.dec ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/audiocodecfirmware.dec -o "$dir"/$1/$cpid/$3/audiocodecfirmware.img4 -M IM4M -T acfw
            fi
            # seprmvr647 is plooshfinder seprmvr64 but with EP0 patch removed
            "$bin"/seprmvr647 "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache.patched
            # KPlooshFinder is amfi patch
            "$bin"/KPlooshFinder "$dir"/$1/$cpid/$3/kcache.patched "$dir"/$1/$cpid/$3/kcache2.patched
            # -a is mapIO, -m is mount_common, -f is vm_fault_enter, and -r is image4 validation patches
            "$bin"/Kernel64Patcher "$dir"/$1/$cpid/$3/kcache2.patched "$dir"/$1/$cpid/$3/kcache3.patched -a -m -r -f
            "$bin"/kerneldiff "$dir"/$1/$cpid/$3/kcache.raw "$dir"/$1/$cpid/$3/kcache3.patched "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache.img4 -M IM4M -T rkrn -P "$dir"/$1/$cpid/$3/kc.bpatch
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/kernelcache.dec -o "$dir"/$1/$cpid/$3/kernelcache -M IM4M -T krnl -P "$dir"/$1/$cpid/$3/kc.bpatch
            if [ -e "$dir"/$1/$cpid/$3/trustcache.im4p ]; then
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/trustcache.im4p -o "$dir"/$1/$cpid/$3/trustcache.img4 -M IM4M -T rtsc
                "$bin"/img4 -i "$dir"/$1/$cpid/$3/trustcache.im4p -o "$dir"/$1/$cpid/$3/trustcache -M IM4M -T trst
            fi
            "$bin"/img4tool -e -o "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/devicetree.dec
            "$bin"/dtree_patcher "$dir"/$1/$cpid/$3/devicetree.out "$dir"/$1/$cpid/$3/DeviceTree.patched -n
            "$bin"/img4 -i "$dir"/$1/$cpid/$3/DeviceTree.patched -o "$dir"/$1/$cpid/$3/devicetree.img4 -A -M IM4M -T rdtr
        fi
    fi
    cd ..
    rm -rf work
}
_download_root_fs() {
    ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'$3'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
    rm -rf BuildManifest.plist
    mkdir -p "$dir"/$1/$cpid/$3
    rm -rf "$dir"/work
    mkdir "$dir"/work
    cd "$dir"/work
    "$bin"/img4tool -e -s "$dir"/other/shsh/"${check}".shsh -m IM4M
    if [[ "$3" == "10.3"* || "$3" == "11."* || "$3" == "12."* ]]; then
        if [ ! -e "$dir"/$1/$cpid/$3/OS.dmg ]; then
            if [[ "$deviceid" == "iPhone8,1" && "$3" == "11.0" ]]; then
                # https://ia800301.us.archive.org/22/items/iPhone_4.7_11.0_15A5278f_Restore/iPhone_4.7_11.0_15A5278f_Restore.ipsw
                cd "$dir"/$1/$cpid/$3
                "$bin"/aria2c https://ia800301.us.archive.org/22/items/iPhone_4.7_11.0_15A5278f_Restore/iPhone_4.7_11.0_15A5278f_Restore.ipsw
                "$bin"/7z x $(find . -name '*.ipsw*')
                fn="058-76196-042.dmg"
                asr -source $fn -target "$dir"/$1/$cpid/$3/OS.dmg --embed -erase -noprompt --chunkchecksum --puppetstrings
                "$bin"/img4 -i kernelcache.release.n71 -o "$dir"/$1/$cpid/$3/kcache_15A5278f.raw
                "$bin"/img4 -i kernelcache.release.n71 -o "$dir"/$1/$cpid/$3/kernelcache_15A5278f.dec -D
                cd "$dir"/work/
            else
                "$bin"/pzb -g BuildManifest.plist "$ipswurl"
                "$bin"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
                fn="$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)"
                asr -source $fn -target "$dir"/$1/$cpid/$3/OS.dmg --embed -erase -noprompt --chunkchecksum --puppetstrings
            fi
            if [[ "$deviceid" == "iPhone6"* || "$deviceid" == "iPad4"* ]]; then
               "$bin"/irecovery -f /dev/null
            fi
        fi
    else
        if [ ! -e "$dir"/$1/$cpid/$3/OS.tar ]; then
            if [ ! -e "$dir"/$1/$cpid/$3/OS.dmg ]; then
                if [[ "$deviceid" == "iPhone7,2" || "$deviceid" == "iPhone7,1" || ! "$3" == "8.0" ]]; then
                    "$bin"/pzb -g BuildManifest.plist "$ipswurl"
                    "$bin"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
                    fn="$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)"
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                    "$bin"/dmg extract $fn "$dir"/$1/$cpid/$3/OS.dmg -k $ivkey
                elif [[ "$deviceid" == "iPhone6,1" || "$deviceid" == "iPhone6,2" ]]; then
                    # https://archive.org/download/Apple_iPhone_Firmware/Apple%20iPhone%206.1%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/
                    cd "$dir"/$1/$cpid/$3
                    "$bin"/aria2c https://ia903400.us.archive.org/4/items/Apple_iPhone_Firmware/Apple%20iPhone%206.1%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    "$bin"/7z x media_ipsw.rar
                    "$bin"/7z x $(find . -name '*.ipsw*')
                    "$bin"/dmg extract 058-01244-053.dmg OS.dmg -k 5c8b481822b91861c1d19590e790b306daaab2230f89dd275c18356d28fdcd47436a0737
                    "$bin"/img4 -i kernelcache.release.n51 -o "$dir"/$1/$cpid/$3/kcache_12A4331d.raw -k fdee9545abf38072bb54d6cc46aeb44cc0ab44308fdccce0a0adc4f2c02c531339c2acd2d7c1e099abb298a63730967a
                    "$bin"/img4 -i kernelcache.release.n51 -o "$dir"/$1/$cpid/$3/kernelcache_12A4331d.dec -k fdee9545abf38072bb54d6cc46aeb44cc0ab44308fdccce0a0adc4f2c02c531339c2acd2d7c1e099abb298a63730967a -D
                    cd "$dir"/work/
                elif [[ "$deviceid" == "iPad4,4" ]]; then
                    # https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.4%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    cd "$dir"/$1/$cpid/$3
                    "$bin"/aria2c https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.4%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    "$bin"/7z x media_ipsw.rar
                    "$bin"/7z x $(find . -name '*.ipsw*')
                    "$bin"/dmg extract 058-01149-054.dmg OS.dmg -k b62a823a1b5355e1e8211db6441e4384f92e8b47407837afadf24facab5c7b0320f61a4f
                    "$bin"/img4 -i kernelcache.release.j85 -o "$dir"/$1/$cpid/$3/kcache_12A4331d.raw -k e64f85ed518a3747d5b04c9d703dd96b92df85410ace43dbed85b7fa66c186e002d59fd2812910e7326ef173cb1c5a8f
                    "$bin"/img4 -i kernelcache.release.j85 -o "$dir"/$1/$cpid/$3/kernelcache_12A4331d.dec -k e64f85ed518a3747d5b04c9d703dd96b92df85410ace43dbed85b7fa66c186e002d59fd2812910e7326ef173cb1c5a8f -D
                    cd "$dir"/work/
                elif [[ "$deviceid" == "iPad4,5" ]]; then
                    # https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.5%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    cd "$dir"/$1/$cpid/$3
                    "$bin"/aria2c https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.5%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    "$bin"/7z x media_ipsw.rar
                    "$bin"/7z x $(find . -name '*.ipsw*')
                    "$bin"/dmg extract 058-01282-053.dmg OS.dmg -k 67a958bddcc762e21702583b20b87caad97ed96433e9e7e8a57ef4ea53d71549f030c125
                    "$bin"/img4 -i kernelcache.release.j86 -o "$dir"/$1/$cpid/$3/kcache_12A4331d.raw -k 4c70597be8d32ab7c7177e1b1e3f1ba00065ed0b2222d0c9c8484a7dada36f2165037fa3324ee5e8aa2bd198a56fd2d9
                    "$bin"/img4 -i kernelcache.release.j86 -o "$dir"/$1/$cpid/$3/kernelcache_12A4331d.dec -k 4c70597be8d32ab7c7177e1b1e3f1ba00065ed0b2222d0c9c8484a7dada36f2165037fa3324ee5e8aa2bd198a56fd2d9 -D
                    cd "$dir"/work/
                elif [[ "$deviceid" == "iPad4,2" ]]; then
                    # https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.2%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    cd "$dir"/$1/$cpid/$3
                    "$bin"/aria2c https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.2%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    "$bin"/7z x media_ipsw.rar
                    "$bin"/7z x $(find . -name '*.ipsw*')
                    "$bin"/dmg extract 058-01330-053.dmg OS.dmg -k 65e1ae6a877652010bcafd88c1b882494b66bd9c2dc3ebbe35d0ebc42466be1a3956c6cc
                    "$bin"/img4 -i kernelcache.release.j72 -o "$dir"/$1/$cpid/$3/kcache_12A4331d.raw -k 93c94a8186de108199771d504c753ecf397433be91c748045b026631d976ac6fe80a2c196db01e6eef506ce231a3fb44
                    "$bin"/img4 -i kernelcache.release.j72 -o "$dir"/$1/$cpid/$3/kernelcache_12A4331d.dec -k 93c94a8186de108199771d504c753ecf397433be91c748045b026631d976ac6fe80a2c196db01e6eef506ce231a3fb44 -D
                    cd "$dir"/work/
                elif [[ "$deviceid" == "iPad4,1" ]]; then
                    # https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.1%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    cd "$dir"/$1/$cpid/$3
                    "$bin"/aria2c https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.1%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    "$bin"/7z x media_ipsw.rar
                    "$bin"/7z x $(find . -name '*.ipsw*')
                    "$bin"/dmg extract 058-01219-053.dmg OS.dmg -k c6017d6da64083eddbbf01c80f4dc6f84c1d935cec206d60116e7177255f2b677ac2d077
                    "$bin"/img4 -i kernelcache.release.j71 -o "$dir"/$1/$cpid/$3/kcache_12A4331d.raw -k 5ea29d371ad06c6e7fb0cd904779cd34f21385cc504f178fb5a9b2d4066703c816208e8f6d9479dd1b49d4d6a2460b02
                    "$bin"/img4 -i kernelcache.release.j71 -o "$dir"/$1/$cpid/$3/kernelcache_12A4331d.dec -k 5ea29d371ad06c6e7fb0cd904779cd34f21385cc504f178fb5a9b2d4066703c816208e8f6d9479dd1b49d4d6a2460b02 -D
                    cd "$dir"/work/
                elif [[ "$deviceid" == "iPad4,6" ]]; then
                    # https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.6%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    cd "$dir"/$1/$cpid/$3
                    "$bin"/aria2c https://ia803400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.6%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    "$bin"/7z x media_ipsw.rar
                    "$bin"/7z x $(find . -name '*.ipsw*')
                    "$bin"/dmg extract 058-01099-053.dmg OS.dmg -k 3746eef01500a81f45d7ceed3c35ed02ad7b9d7da26e7fa4a27a84a1a53a224e65ab8ba8
                    "$bin"/img4 -i kernelcache.release.j87 -o "$dir"/$1/$cpid/$3/kcache_12A4331d.raw -k c17906bdffdf40b6f9c0656c6b7d585449e6eb495439f9cae8faee3a466e75de248c2ce176cddc3a1ca4de73be0baeef
                    "$bin"/img4 -i kernelcache.release.j87 -o "$dir"/$1/$cpid/$3/kernelcache_12A4331d.dec -k c17906bdffdf40b6f9c0656c6b7d585449e6eb495439f9cae8faee3a466e75de248c2ce176cddc3a1ca4de73be0baeef -D
                    cd "$dir"/work/
                elif [[ "$deviceid" == "iPad4,3" ]]; then
                    # https://ia903400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.3%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    cd "$dir"/$1/$cpid/$3
                    "$bin"/aria2c https://ia903400.us.archive.org/4/items/Apple_iPad_Firmware_Part_1/Apple%20iPad%204.3%20Firmware%208.0%20%288.0.12A4331d%29%20%28beta4%29/media_ipsw.rar
                    "$bin"/7z x media_ipsw.rar
                    "$bin"/7z x $(find . -name '*.ipsw*')
                    "$bin"/dmg extract 058-01287-053.dmg OS.dmg -k f593490d57e2c6a01bbfee212c83f711a8e80e6366107803ff3a933850b48ed68f495014
                    "$bin"/img4 -i kernelcache.release.j73 -o "$dir"/$1/$cpid/$3/kcache_12A4331d.raw -k fc44a450a05e812125e93ff45c820a90cd11f08347133cc03a9b4bed23a1ec16c509c58d3b0f3083640d62edc56eee10
                    "$bin"/img4 -i kernelcache.release.j73 -o "$dir"/$1/$cpid/$3/kernelcache_12A4331d.dec -k fc44a450a05e812125e93ff45c820a90cd11f08347133cc03a9b4bed23a1ec16c509c58d3b0f3083640d62edc56eee10 -D
                    cd "$dir"/work/
                else
                    "$bin"/pzb -g BuildManifest.plist "$ipswurl"
                    "$bin"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
                    fn="$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)"
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $3 $1)"
                    "$bin"/dmg extract $fn "$dir"/$1/$cpid/$3/OS.dmg -k $ivkey
                fi
            fi
            "$bin"/dmg build "$dir"/$1/$cpid/$3/OS.dmg "$dir"/$1/$cpid/$3/rw.dmg
            hdiutil attach -mountpoint /tmp/ios "$dir"/$1/$cpid/$3/rw.dmg
            sudo diskutil enableOwnership /tmp/ios
            sudo "$bin"/gnutar -cvf "$dir"/$1/$cpid/$3/OS.tar -C /tmp/ios .
            hdiutil detach /tmp/ios
            rm -rf /tmp/ios
            if [[ "$deviceid" == "iPhone6"* || "$deviceid" == "iPad4"* ]]; then
               "$bin"/irecovery -f /dev/null
            fi
        fi
    fi
    cd ..
    rm -rf work
}
_kill_if_running() {
    if (pgrep -u root -xf "$1" &> /dev/null > /dev/null); then
        sudo killall $1
    else
        if (pgrep -x "$1" &> /dev/null > /dev/null); then
            killall $1
        fi
    fi
}
if [ ! -e java/bin/java ]; then
    mkdir java
    cd java
    curl -k -SLO https://builds.openlogic.com/downloadJDK/openlogic-openjdk-jre/8u262-b10/openlogic-openjdk-jre-8u262-b10-mac-x64.zip
    "$bin"/7z x openlogic-openjdk-jre-8u262-b10-mac-x64.zip
    sudo cp -rf openlogic-openjdk-jre-8u262-b10-mac-x64/jdk1.8.0_262.jre/Contents/Home/* .
    sudo rm -rf openlogic-openjdk-jre-8u262-b10-mac-x64/
    cd ..
fi
for cmd in curl unzip git ssh scp killall sudo grep pgrep ${linux_cmds}; do
    if ! command -v "${cmd}" > /dev/null; then
        echo "[-] Command '${cmd}' not installed, please install it!";
        cmd_not_found=1
    fi
done
if [ "$cmd_not_found" = "1" ]; then
    exit 1
fi
if [[ "$*" == *"--fix-auto-boot"* ]]; then
    "$bin"/irecovery -c "setenv auto-boot true"
    "$bin"/irecovery -c "saveenv"
    "$bin"/irecovery -c "reset"
    exit 0
fi
sudo killall -STOP -c usbd
if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
    "$bin"/dfuhelper.sh
fi
_wait_for_dfu
rm -rf work
check=$("$bin"/irecovery -q | grep CPID | sed 's/CPID: //')
cpid=$("$bin"/irecovery -q | grep CPID | sed 's/CPID: //')
replace=$("$bin"/irecovery -q | grep MODEL | sed 's/MODEL: //')
deviceid=$("$bin"/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
echo $deviceid
parse_cmdline "$@"
boot_args=""
if [ "$serial" = "1" ]; then
    boot_args="serial=3"
else
    boot_args="-v"
fi
_wait_for_dfu
if [[ "$clean" == 1 ]]; then
    rm -rf "$dir"/$deviceid/$cpid/$version/iBSS*
    rm -rf "$dir"/$deviceid/$cpid/$version/iBEC*
    rm -rf "$dir"/$deviceid/$cpid/$version/kcache2.patched
    rm -rf "$dir"/$deviceid/$cpid/$version/kcache3.patched
    rm -rf "$dir"/$deviceid/$cpid/$version/kcache4.patched
    rm -rf "$dir"/$deviceid/$cpid/$version/kcache5.patched
    rm -rf "$dir"/$deviceid/$cpid/$version/kcache.patched
    rm -rf "$dir"/$deviceid/$cpid/$version/kcache.raw
    rm -rf "$dir"/$deviceid/$cpid/$version/kernelcache.dec
    rm -rf "$dir"/$deviceid/$cpid/$version/kc.bpatch
    rm -rf "$dir"/$deviceid/$cpid/$version/kernelcache.img4
    rm -rf "$dir"/$deviceid/$cpid/$version/kernelcache
    rm -rf "$dir"/$deviceid/$cpid/$version/kernelcache.im4p.img4
    rm -rf "$dir"/$deviceid/$cpid/$version/kernelcache.im4p
    rm -rf "$dir"/$deviceid/$cpid/$version/kpp.bin
    rm -rf "$dir"/$deviceid/$cpid/$version/DeviceTree*
    rm -rf "$dir"/$deviceid/$cpid/$version/devicetree*
    rm -rf "$dir"/$deviceid/$cpid/ramdisk/
    rm -rf "$dir"/work/
    echo "[*] Removed the created boot files"
    exit 0
fi
if [[ "$boot" == 1 ]]; then
    if [[ "$version" == "8.0" || "$version" == "11.0" ]]; then
        # required to get ios 8 beta 4 or ios 11 beta 1 kernel
        _download_root_fs $deviceid $replace $version
    fi
    _download_boot_files $deviceid $replace $version
    _kill_if_running iproxy
    sudo killall -STOP -c usbd
    read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
    if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
        read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
        echo "[*] Waiting 10 seconds before continuing.."
        sleep 10
    elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
        echo "[*] Ok no problem, continuing.."
    else
        echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
        read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
        echo "[*] Waiting 10 seconds before continuing.."
        sleep 10
    fi
    if [ -e "$dir"/$deviceid/$cpid/$version/iBSS.img4 ]; then
        cd "$dir"/$deviceid/$cpid/$version
        if [[ "$deviceid" == "iPhone6"* || "$deviceid" == "iPad4"* ]]; then
            "$bin"/ipwnder -p
        else
            "$bin"/gaster pwn
            "$bin"/gaster reset
        fi
        "$bin"/irecovery -f iBSS.img4
        "$bin"/irecovery -f iBSS.img4
        "$bin"/irecovery -f iBEC.img4
        if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
            sleep 1
            "$bin"/irecovery -c go
            sleep 2
        fi
        "$bin"/irecovery -f devicetree.img4
        "$bin"/irecovery -c devicetree
        if [ -e ./trustcache.img4 ]; then
            "$bin"/irecovery -f trustcache.img4
            "$bin"/irecovery -c firmware
        fi
        "$bin"/irecovery -f kernelcache.img4
        "$bin"/irecovery -c bootx &
        cd "$dir"/
        exit 0
    fi
    exit 0
fi
if [[ "$ramdisk" == 1 || "$restore" == 1 || "$dump_blobs" == 1 || "$fix_activation" == 1 || "$dump_nand" == 1 || "$restore_nand" == 1 || "$restore_mnt1" == 1 || "$restore_mnt2" == 1 || "$disable_NoMoreSIGABRT" == 1 || "$NoMoreSIGABRT" == 1 ]]; then
    _kill_if_running iproxy
    if [[ "$ramdisk" == 1 || "$dump_blobs" == 1 || "$dump_nand" == 1 || "$restore_nand" == 1 || "$restore_mnt1" == 1 || "$restore_mnt2" == 1 || "$disable_NoMoreSIGABRT" == 1 || "$NoMoreSIGABRT" == 1 ]]; then
        rdversion="$version"
        if [[ "$version" == "9."* ]]; then
            rdversion="11.4"
        elif [[ "$version" == "10."* || "$version" == "11.0" ]]; then
            rdversion="10.3.3"
        elif [[ "$deviceid" == "iPhone8,1" && "$version" == "11.0" ]]; then
            rdversion="10.3.3"
        elif [[ "$version" == "7."* || "$version" == "8."* ]]; then
            rdversion="8.4.1"
        fi
        _download_ramdisk_boot_files $deviceid $replace $rdversion
        sleep 1
        if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
            if [[ "$deviceid" == "iPhone10"* || "$cpid" == "0x8015"* ]]; then
                "$bin"/dfuhelper.sh
            elif [[ "$cpid" = 0x801* && "$deviceid" != *"iPad"* ]]; then
                "$bin"/dfuhelper2.sh
            else
                "$bin"/dfuhelper3.sh
            fi
        fi
        _wait_for_dfu
        sudo killall -STOP -c usbd
        read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
        if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
            read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
            echo "[*] Waiting 10 seconds before continuing.."
            sleep 10
        elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
            echo "[*] Ok no problem, continuing.."
        else
            echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
            read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
            echo "[*] Waiting 10 seconds before continuing.."
            sleep 10
        fi
        cd "$dir"/$deviceid/$cpid/ramdisk/$rdversion
    else
        if [[ "$version" == "7."* || "$version" == "8."* ]]; then
            _download_ramdisk_boot_files $deviceid $replace 8.4.1
        elif [[ "$version" == "10.3"* ]]; then
            _download_ramdisk_boot_files $deviceid $replace 10.3.3
            if [[ "$(./java/bin/java -jar ./Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -e 14.3 $deviceid)" == "true" ]]; then
                _download_ramdisk_boot_files $deviceid $replace 14.3
            else
                _download_ramdisk_boot_files $deviceid $replace 12.5.4
            fi
        elif [[ "$deviceid" == "iPhone8,1" && "$version" == "11.0" ]]; then
            _download_ramdisk_boot_files $deviceid $replace 10.3.3
            if [[ "$(./java/bin/java -jar ./Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -e 14.3 $deviceid)" == "true" ]]; then
                _download_ramdisk_boot_files $deviceid $replace 14.3
            else
                _download_ramdisk_boot_files $deviceid $replace 12.5.4
            fi
        elif [[ "$version" == "11."* || "$version" == "12."* ]]; then
            if [[ "$(./java/bin/java -jar ./Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -e 14.3 $deviceid)" == "true" ]]; then
                _download_ramdisk_boot_files $deviceid $replace 14.3
            else
                _download_ramdisk_boot_files $deviceid $replace 12.5.4
            fi
        else
            _download_ramdisk_boot_files $deviceid $replace 11.4
        fi
        if [[ ! -e "$dir"/$deviceid/0.0/apticket.der || ! -e "$dir"/$deviceid/0.0/sep-firmware.img4 || ! -e "$dir"/$deviceid/0.0/keybags ]]; then
            read -p "[*] Please enter the iOS version that is currently installed on your device  " r
            if [[ "$r" == "11.4.1"* ]]; then
                r="11.4"
            fi
            _download_ramdisk_boot_files $deviceid $replace $r
			if [[ "$r" == "9."* ]]; then
				fuck=1
				r="10.2.1"
                _download_ramdisk_boot_files $deviceid $replace $r
			fi
        fi
        if [[ "$version" == "10.3"* || "$version" == "11."* || "$version" == "12."* ]]; then
            if [ -z "$r" ]; then
                read -p "what ios version was installed on this device prior to downgrade? " r
                if [[ "$r" == "11.4.1"* ]]; then
                    r="11.4"
                fi
                _download_ramdisk_boot_files $deviceid $replace $r
            fi
        fi
        if [[ "$version" == "8.0" && "$restore" == 1 ]]; then
            # required to get ios 8 beta 4 kernel
            _download_root_fs $deviceid $replace $version
        fi
        if [[ "$version" == "11.0" && "$restore" == 1 ]]; then
            # required to get ios 11 beta 1 kernel
            _download_root_fs $deviceid $replace $version
        fi
        _download_boot_files $deviceid $replace $version
        if [[ "$restore" == 1 ]]; then
            _download_root_fs $deviceid $replace $version
        fi
        echo "[*] Waiting for device in DFU mode"
        sleep 1
        if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
            if [[ "$deviceid" == "iPhone10"* || "$cpid" == "0x8015"* ]]; then
                "$bin"/dfuhelper.sh
            elif [[ "$cpid" = 0x801* && "$deviceid" != *"iPad"* ]]; then
                "$bin"/dfuhelper2.sh
            else
                "$bin"/dfuhelper3.sh
            fi
        fi
        _wait_for_dfu
        sudo killall -STOP -c usbd
        read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
        if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
            read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
            echo "[*] Waiting 10 seconds before continuing.."
            sleep 10
        elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
            echo "[*] Ok no problem, continuing.."
        else
            echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
            read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
            echo "[*] Waiting 10 seconds before continuing.."
            sleep 10
        fi
        if [[ ! -e "$dir"/$deviceid/0.0/apticket.der || ! -e "$dir"/$deviceid/0.0/sep-firmware.img4 || ! -e "$dir"/$deviceid/0.0/keybags ]]; then
            cd "$dir"/$deviceid/$cpid/ramdisk/$r
        elif [[ "$version" == "7."* || "$version" == "8."* ]]; then
            cd "$dir"/$deviceid/$cpid/ramdisk/8.4.1
        elif [[ "$version" == "10.3"* ]]; then
            cd "$dir"/$deviceid/$cpid/ramdisk/10.3.3
        elif [[ "$deviceid" == "iPhone8,1" && "$version" == "11.0" ]]; then
            cd "$dir"/$deviceid/$cpid/ramdisk/10.3.3
        elif [[ "$version" == "11."* || "$version" == "12."* ]]; then
            if [[ "$(./java/bin/java -jar ./Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -e 14.3 $deviceid)" == "true" ]]; then
                cd "$dir"/$deviceid/$cpid/ramdisk/14.3
            else
                cd "$dir"/$deviceid/$cpid/ramdisk/12.5.4
            fi
        else
            cd "$dir"/$deviceid/$cpid/ramdisk/11.4
        fi
    fi
    if [[ "$deviceid" == "iPhone6"* || "$deviceid" == "iPad4"* ]]; then
        "$bin"/ipwnder -p
    else
        "$bin"/gaster pwn
        "$bin"/gaster reset
    fi
    "$bin"/irecovery -f iBSS.img4
    "$bin"/irecovery -f iBSS.img4
    "$bin"/irecovery -f iBEC.img4
    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        sleep 1
        "$bin"/irecovery -c go
        sleep 2
    fi
    "$bin"/irecovery -f ramdisk.img4
    "$bin"/irecovery -c ramdisk
    "$bin"/irecovery -f devicetree.img4
    "$bin"/irecovery -c devicetree
    if [ -e ./trustcache.img4 ]; then
        "$bin"/irecovery -f trustcache.img4
        "$bin"/irecovery -c firmware
    fi
    "$bin"/irecovery -f kernelcache.img4
    "$bin"/irecovery -c bootx &
    cd "$dir"/
    read -p "[*] Press Enter once your device has fully booted into the SSH ramdisk " r1
    echo "[*] Waiting 6 seconds before continuing.."
    sleep 6
    sudo killall -STOP -c usbd
    read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
    if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
        read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
        echo "[*] Waiting 10 seconds before continuing.."
        sleep 10
    elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
        echo "[*] Ok no problem, continuing.."
    else
        echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
        read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
        echo "[*] Waiting 10 seconds before continuing.."
        sleep 10
    fi
    "$bin"/iproxy 2222 22 &
    sleep 2
    if [[ "$restore" == 1 ]]; then
        if [[ "$deviceid" == "iPhone10"* || "$cpid" == "0x8015"* ]]; then
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram auto-boot=false" 2> /dev/null
        fi
        mkdir -p "$dir"/$deviceid/0.0/
        hit=0
        if [[ ! -e "$dir"/$deviceid/0.0/apticket.der || ! -e "$dir"/$deviceid/0.0/sep-firmware.img4 || ! -e "$dir"/$deviceid/0.0/keybags ]]; then
            if [[ "$r" == "7."* || "$r" == "8."* || "$r" == "9."* || "$r" == "10.0"* || "$r" == "10.1"* || "$r" == "10.2"* ]]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_hfs /dev/disk0s1s1 /mnt1" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -t hfs /dev/disk0s1s2 /mnt2" 2> /dev/null
            else
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "bash -c mount_filesystems" 2> /dev/null
            fi
			if [[ "$fuck" == 1 ]]; then
				if [ ! -e "$dir"/$deviceid/0.0/apticket.der ]; then
					"$bin"/sshpass -p "alpine" scp -P 2222 root@localhost:/mnt1/System/Library/Caches/apticket.der "$dir"/$deviceid/0.0/apticket.der 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/sep-firmware.img4 ]; then
					"$bin"/sshpass -p "alpine" scp -P 2222 root@localhost:/mnt1/usr/standalone/firmware/sep-firmware.img4 "$dir"/$deviceid/0.0/sep-firmware.img4 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/FUD ]; then
					"$bin"/sshpass -p "alpine" scp -r -P 2222 root@localhost:/mnt1/usr/standalone/firmware/FUD "$dir"/$deviceid/0.0/FUD 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/Baseband ]; then
					"$bin"/sshpass -p "alpine" scp -r -P 2222 root@localhost:/mnt1/usr/local/standalone/firmware/Baseband "$dir"/$deviceid/0.0/Baseband 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/firmware ]; then
					"$bin"/sshpass -p "alpine" scp -r -P 2222 root@localhost:/mnt1/usr/standalone/firmware "$dir"/$deviceid/0.0/firmware 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/local ]; then
					"$bin"/sshpass -p "alpine" scp -r -P 2222 root@localhost:/mnt1/usr/local "$dir"/$deviceid/0.0/local 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/keybags ]; then
					"$bin"/sshpass -p "alpine" scp -r -P 2222 root@localhost:/mnt2/keybags "$dir"/$deviceid/0.0/keybags 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/com.apple.factorydata ]; then
					"$bin"/sshpass -p "alpine" scp -r -P 2222 root@localhost:/mnt1/System/Library/Caches/com.apple.factorydata "$dir"/$deviceid/0.0/com.apple.factorydata 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/bbfs ]; then
					"$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -t hfs /dev/disk0s1s3 /mnt3" 2> /dev/null
					"$bin"/sshpass -p "alpine" scp -r -P 2222 root@localhost:/mnt3/bbfs "$dir"/$deviceid/0.0/bbfs 2> /dev/null
				fi
			else
				if [ ! -e "$dir"/$deviceid/0.0/apticket.der ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/Caches/apticket.der "$dir"/$deviceid/0.0/apticket.der 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/sep-firmware.img4 ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/usr/standalone/firmware/sep-firmware.img4 "$dir"/$deviceid/0.0/sep-firmware.img4 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/FUD ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt1/usr/standalone/firmware/FUD "$dir"/$deviceid/0.0/FUD 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/Baseband ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt1/usr/local/standalone/firmware/Baseband "$dir"/$deviceid/0.0/Baseband 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/firmware ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt1/usr/standalone/firmware "$dir"/$deviceid/0.0/firmware 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/local ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt1/usr/local "$dir"/$deviceid/0.0/local 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/keybags ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt2/keybags "$dir"/$deviceid/0.0/keybags 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/wireless ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt2/wireless "$dir"/$deviceid/0.0/wireless 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/com.apple.factorydata ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt1/System/Library/Caches/com.apple.factorydata "$dir"/$deviceid/0.0/com.apple.factorydata 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/IC-Info.sisv ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv "$dir"/$deviceid/0.0/IC-Info.sisv 2> /dev/null
				fi
				if [ ! -e "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist 2> /dev/null
				fi
                if [ ! -e "$dir"/$deviceid/0.0/data_ark.plist ]; then
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt2/root/Library/Lockdown/data_ark.plist "$dir"/$deviceid/0.0/data_ark.plist 2> /dev/null
                fi
                #if [ ! -e "$dir"/$deviceid/0.0/Carrier_Bundles.tar ]; then
                #    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -cvf /mnt1/Carrier_Bundles.tar /mnt1/System/Library/Carrier\ Bundles/iPhone/" 2> /dev/null
                #    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/Carrier_Bundles.tar "$dir"/$deviceid/0.0/Carrier_Bundles.tar 2> /dev/null
                #fi
				# /mnt2/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library/internal/data_ark.plist
				dataarkplist=$(remote_cmd "/usr/bin/find /mnt2/containers/Data/System -name 'data_ark.plist'" 2> /dev/null)
				if [[ "$dataarkplist" == "/mnt2/containers/Data/System"* ]]; then
					folder=$(echo $dataarkplist | sed 's/\/data_ark.plist//g')
                    folder=$(echo $folder | sed 's/\/internal//g')
					# /mnt2/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library
					if [[ "$folder" == "/mnt2/containers/Data/System"* ]]; then
						if [ ! -e "$dir"/$deviceid/0.0/activation_records ]; then
							"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:$folder/activation_records "$dir"/$deviceid/0.0/activation_records 2> /dev/null
						fi
					fi
				fi
				if [ ! -e "$dir"/$deviceid/0.0/activation_records ]; then
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt2/mobile/Library/mad/activation_records "$dir"/$deviceid/0.0/activation_records 2> /dev/null
				fi
				if [[ ! -e "$dir"/$deviceid/0.0/apticket.der ]]; then
					has_active=$(remote_cmd "ls /mnt6/active" 2> /dev/null)
					if [ ! "$has_active" = "/mnt6/active" ]; then
						echo "[*] An error occured while trying to back up the required files required to downgrade"
						$("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
                        _kill_if_running iproxy
						exit 0
					fi
					active=$(remote_cmd "cat /mnt6/active" 2> /dev/null)
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt6/$active/System/Library/Caches/apticket.der "$dir"/$deviceid/0.0/apticket.der 2> /dev/null
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt6/$active/usr/standalone/firmware/sep-firmware.img4 "$dir"/$deviceid/0.0/sep-firmware.img4 2> /dev/null
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt6/$active/usr/standalone/firmware/FUD "$dir"/$deviceid/0.0/FUD 2> /dev/null
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt6/$active/usr/local/standalone/firmware/Baseband "$dir"/$deviceid/0.0/Baseband 2> /dev/null
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt6/$active/usr/standalone/firmware "$dir"/$deviceid/0.0/firmware 2> /dev/null
					"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 root@localhost:/mnt6/$active/usr/local "$dir"/$deviceid/0.0/local 2> /dev/null
				fi
			fi
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            if [[ ! -e "$dir"/$deviceid/0.0/apticket.der || ! -e "$dir"/$deviceid/0.0/sep-firmware.img4 || ! -e "$dir"/$deviceid/0.0/keybags ]]; then
                echo "[*] An error occured while trying to back up the required files required to downgrade"
                $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
                _kill_if_running iproxy
                exit 0
            else
                hit=1
                echo "[*] Backed up the required files required to downgrade"
            fi
        fi
        if [ ! -e "$dir"/$deviceid/0.0/apticket.der ]; then
            echo "missing ./apticket.der, which is required in order to proceed. exiting.."
            exit 0
        fi
        if [ ! -e "$dir"/$deviceid/0.0/sep-firmware.img4 ]; then
            echo "missing ./sep-firmware.img4, which is required in order to proceed. exiting.."
            exit 0
        fi
        if [ ! -e "$dir"/$deviceid/0.0/keybags ]; then
            echo "missing ./keybags, which is required in order to proceed. exiting.."
            exit 0
        fi
        if [ ! -e "$dir"/$deviceid/0.0/activation_records/activation_record.plist ]; then
            read -p "missing ./activation_records/activation_record.plist, which is recommended in order to proceed. press enter to continue.. " r1
        fi
        if [[ "$version" == "10.3"* || "$version" == "11."* || "$version" == "12."* ]]; then
            if [[ "$hit" == 1 ]]; then
                $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
                _kill_if_running iproxy
                echo "device should now reboot into recovery, pls wait"
                if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
                    if [[ "$deviceid" == "iPhone10"* || "$cpid" == "0x8015"* ]]; then
                        if [[ "$r" == "13.*" || "$r" == "14.*" || "$r" == "15.*" ]]; then
                            echo "[*] Waiting 30 seconds before continuing.."
                            sleep 30
                        fi
                        "$bin"/dfuhelper.sh
                    elif [[ "$cpid" = 0x801* && "$deviceid" != *"iPad"* ]]; then
                        "$bin"/dfuhelper2.sh
                    else
                        "$bin"/dfuhelper3.sh
                    fi
                fi
                _wait_for_dfu
                sudo killall -STOP -c usbd
                read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
                if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
                    read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                    echo "[*] Waiting 10 seconds before continuing.."
                    sleep 10
                elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
                    echo "[*] Ok no problem, continuing.."
                else
                    echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
                    read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                    echo "[*] Waiting 10 seconds before continuing.."
                    sleep 10
                fi
                if [[ "$version" == "7."* || "$version" == "8."* ]]; then
                    cd "$dir"/$deviceid/$cpid/ramdisk/8.4.1
                elif [[ "$version" == "10.3"* ]]; then
                    cd "$dir"/$deviceid/$cpid/ramdisk/10.3.3
                elif [[ "$deviceid" == "iPhone8,1" && "$version" == "11.0" ]]; then
                    cd "$dir"/$deviceid/$cpid/ramdisk/10.3.3
                elif [[ "$version" == "11."* || "$version" == "12."* ]]; then
                    if [[ "$(./java/bin/java -jar ./Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -e 14.3 $deviceid)" == "true" ]]; then
                        cd "$dir"/$deviceid/$cpid/ramdisk/14.3
                    else
                        cd "$dir"/$deviceid/$cpid/ramdisk/12.5.4
                    fi
                else
                    cd "$dir"/$deviceid/$cpid/ramdisk/11.4
                fi
                if [[ "$deviceid" == "iPhone6"* || "$deviceid" == "iPad4"* ]]; then
                    "$bin"/ipwnder -p
                else
                    "$bin"/gaster pwn
                    "$bin"/gaster reset
                fi
                "$bin"/irecovery -f iBSS.img4
                "$bin"/irecovery -f iBSS.img4
                "$bin"/irecovery -f iBEC.img4
                if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
                    sleep 1
                    "$bin"/irecovery -c go
                    sleep 2
                fi
                "$bin"/irecovery -f ramdisk.img4
                "$bin"/irecovery -c ramdisk
                "$bin"/irecovery -f devicetree.img4
                "$bin"/irecovery -c devicetree
                if [ -e ./trustcache.img4 ]; then
                    "$bin"/irecovery -f trustcache.img4
                    "$bin"/irecovery -c firmware
                fi
                "$bin"/irecovery -f kernelcache.img4
                "$bin"/irecovery -c bootx &
                cd "$dir"/
                read -p "[*] Press Enter once your device has fully booted into the SSH ramdisk " r1
                echo "[*] Waiting 6 seconds before continuing.."
                sleep 6
                sudo killall -STOP -c usbd
                read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
                if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
                    read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                    echo "[*] Waiting 10 seconds before continuing.."
                    sleep 10
                elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
                    echo "[*] Ok no problem, continuing.."
                else
                    echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
                    read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                    echo "[*] Waiting 10 seconds before continuing.."
                    sleep 10
                fi
                "$bin"/iproxy 2222 22 &
            fi
            echo "[*] Testing for baseband presence"
            systemdisk=8
            datadisk=9
            #if [ "$(remote_cmd "/usr/bin/mgask HasBaseband | grep -E 'true|false'")" = "true" ] && [[ "${cpid}" == *"0x700"* ]]; then
            #    systemdisk=7
            #    datadisk=8
            #elif [ "$(remote_cmd "/usr/bin/mgask HasBaseband | grep -E 'true|false'")" = "false" ]; then
            #    if [[ "${cpid}" == *"0x700"* ]]; then
            #        systemdisk=6
            #        datadisk=7
            #    else
            #        systemdisk=7
            #        datadisk=8
            #    fi
            #fi
            systemfs=disk0s1s$systemdisk
            datafs=disk0s1s$datadisk
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt4" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt5" 2> /dev/null
            echo "[*] Deleting /dev/disk0s1s$systemdisk"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/apfs_deletefs /dev/$systemfs"
            sleep 1
            echo "[*] Creating /dev/disk0s1s$systemdisk"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
            sleep 2
            remote_cmd "/sbin/apfs_deletefs /dev/$systemfs" && {
                sleep 1
                echo "[*] Creating /dev/disk0s1s$systemdisk"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                sleep 2
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "ls /dev/"
            } || {
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                sleep 2
                remote_cmd "/sbin/apfs_deletefs /dev/$systemfs" && {
                    sleep 1
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                    sleep 2
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "ls /dev/"
                } || {
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                    sleep 2
                    remote_cmd "/sbin/apfs_deletefs /dev/$systemfs" && {
                        sleep 1
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                        sleep 2
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "ls /dev/"
                    } || {
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                        sleep 2
                        remote_cmd "/sbin/apfs_deletefs /dev/$systemfs" && {
                            sleep 1
                            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                            sleep 2
                            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "ls /dev/"
                        } || {
                            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                            sleep 2
                            remote_cmd "/sbin/apfs_deletefs /dev/$systemfs" && {
                                sleep 1
                                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                                sleep 2
                                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "ls /dev/"
                            } || {
                                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                                sleep 2
                                remote_cmd "/sbin/apfs_deletefs /dev/$systemfs" && {
                                    sleep 1
                                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                                    sleep 2
                                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "ls /dev/"
                                } || {
                                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                                    sleep 2
                                    remote_cmd "/sbin/apfs_deletefs /dev/$systemfs" && {
                                        sleep 1
                                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v SystemX /dev/disk0s1"
                                        sleep 2
                                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "ls /dev/"
                                    } || {
                                        echo "[*] An error occured while trying to create /dev/$systemfs"
                                        exit 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
            echo "[*] /dev/disk0s1s$systemdisk created, continuing..."
            echo "[*] Deleting /dev/disk0s1s$datadisk"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/apfs_deletefs /dev/$datafs"
            sleep 1
            echo "[*] Creating /dev/disk0s1s$datadisk"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_apfs -A -v DataX /dev/disk0s1"
            sleep 2
            echo "[*] /dev/disk0s1s$datadisk created, continuing..."
            echo "[*] Uploading $dir/$deviceid/$cpid/$version/OS.dmg, this may take up to 10 minutes.."
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_apfs /dev/$systemfs /mnt4"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_apfs /dev/$datafs /mnt5"
            "$bin"/sshpass -p 'alpine' scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/OS.dmg root@localhost:/mnt4
            ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'$version'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
            rm -rf BuildManifest.plist
            mkdir -p "$dir"/$deviceid/$cpid/$version
            rm -rf "$dir"/work
            mkdir "$dir"/work
            cd "$dir"/work
            "$bin"/img4tool -e -s "$dir"/other/shsh/"${check}".shsh -m IM4M
            if [[ "$version" == "10."* ]]; then
                if [[ "$deviceid" == "iPhone8,1" || "$deviceid" == "iPhone8,2" ]]; then
                    ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'11.1'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
                else
                    ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$bin"/jq '.firmwares | .[] | select(.version=="'10.3.3'")' | "$bin"/jq -s '.[0] | .url' --raw-output)
                fi
            fi
            rm -rf "$dir"/$deviceid/$cpid/$version/iBSS*
            rm -rf "$dir"/$deviceid/$cpid/$version/iBEC*
            "$bin"/pzb -g BuildManifest.plist "$ipswurl"
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
            fn="$(awk "/""$replace""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')"
            if [[ "$version" == "10."* ]]; then
                if [[ "$deviceid" == "iPhone8,1" || "$deviceid" == "iPhone8,2" ]]; then
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 11.1 $deviceid)"
                else
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 10.3.3 $deviceid)"
                fi
            else
                ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $version $deviceid)"
            fi
            "$bin"/img4 -i $fn -o "$dir"/$deviceid/$cpid/$version/iBSS.dec -k $ivkey
            "$bin"/pzb -g $(awk "/""$replace""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
            fn="$(awk "/""$replace""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')"
            if [[ "$version" == "10."* ]]; then
                if [[ "$deviceid" == "iPhone8,1" || "$deviceid" == "iPhone8,2" ]]; then
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 11.1 $deviceid)"
                else
                    ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn 10.3.3 $deviceid)"
                fi
            else
                ivkey="$(../java/bin/java -jar ../Darwin/FirmwareKeysDl-1.0-SNAPSHOT.jar -ivkey $fn $version $deviceid)"
            fi
            "$bin"/img4 -i $fn -o "$dir"/$deviceid/$cpid/$version/iBEC.dec -k $ivkey
            rm -rf BuildManifest.plist
            "$bin"/iBoot64Patcher "$dir"/$deviceid/$cpid/$version/iBSS.dec "$dir"/$deviceid/$cpid/$version/iBSS.patched
            "$bin"/iBoot64Patcher "$dir"/$deviceid/$cpid/$version/iBEC.dec "$dir"/$deviceid/$cpid/$version/iBEC.patched2 -b "$boot_args rd=$systemfs amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e PE_i_can_has_debugger=1 amfi_get_out_of_my_way=1 amfi_allow_any_signature=1" -n
            "$bin"/kairos "$dir"/$deviceid/$cpid/$version/iBEC.patched2 "$dir"/$deviceid/$cpid/$version/iBEC.patched -d 8
            "$bin"/img4 -i "$dir"/$deviceid/$cpid/$version/iBSS.patched -o "$dir"/$deviceid/$cpid/$version/iBSS.img4 -M IM4M -A -T ibss
            "$bin"/img4 -i "$dir"/$deviceid/$cpid/$version/iBEC.patched -o "$dir"/$deviceid/$cpid/$version/iBEC.img4 -M IM4M -A -T ibec
            cd ..
            rm -rf work
        else
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "lwvm init" 2> /dev/null
            sleep 1
            echo "[*] Wiped the device"
        fi
        $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
        sleep 5
        _kill_if_running iproxy
        echo "[*] Device should boot to Recovery mode. Please wait..."
        if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
            if [[ "$deviceid" == "iPhone10"* || "$cpid" == "0x8015"* ]]; then
                "$bin"/dfuhelper.sh
            elif [[ "$cpid" = 0x801* && "$deviceid" != *"iPad"* ]]; then
                "$bin"/dfuhelper2.sh
            else
                "$bin"/dfuhelper3.sh
            fi
        fi
        _wait_for_dfu
        sudo killall -STOP -c usbd
        read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
        if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
            read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
            echo "[*] Waiting 10 seconds before continuing.."
            sleep 10
        elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
            echo "[*] Ok no problem, continuing.."
        else
            echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
            read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
            echo "[*] Waiting 10 seconds before continuing.."
            sleep 10
        fi
        if [[ "$version" == "7."* || "$version" == "8."* ]]; then
            cd "$dir"/$deviceid/$cpid/ramdisk/8.4.1
        elif [[ "$version" == "10.3"* || "$version" == "11."* ||  "$version" == "12."* ]]; then
            cd "$dir"/$deviceid/$cpid/ramdisk/$r
        else
            cd "$dir"/$deviceid/$cpid/ramdisk/11.4
        fi
        if [[ "$deviceid" == "iPhone6"* || "$deviceid" == "iPad4"* ]]; then
            "$bin"/ipwnder -p
        else
            "$bin"/gaster pwn
            "$bin"/gaster reset
        fi
        "$bin"/irecovery -f iBSS.img4
        "$bin"/irecovery -f iBSS.img4
        "$bin"/irecovery -f iBEC.img4
        if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
            sleep 1
            "$bin"/irecovery -c go
            sleep 2
        fi
        "$bin"/irecovery -f ramdisk.img4
        "$bin"/irecovery -c ramdisk
        "$bin"/irecovery -f devicetree.img4
        "$bin"/irecovery -c devicetree
        if [ -e ./trustcache.img4 ]; then
            "$bin"/irecovery -f trustcache.img4
            "$bin"/irecovery -c firmware
        fi
        "$bin"/irecovery -f kernelcache.img4
        "$bin"/irecovery -c bootx &
        cd "$dir"/
        read -p "[*] Press Enter once your device has fully booted into the SSH ramdisk. " r1
        echo "[*] Waiting 6 seconds before continuing.."
        sleep 6
        sudo killall -STOP -c usbd
        read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
        if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
            read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
            echo "[*] Waiting 10 seconds before continuing.."
            sleep 10
        elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
            echo "[*] Ok no problem, continuing.."
        else
            echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
            read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
            echo "[*] Waiting 10 seconds before continuing.."
            sleep 10
        fi
        "$bin"/iproxy 2222 22 &
        if [[ "$version" == "10.3"* || "$version" == "11."* || "$version" == "12."* ]]; then
            echo "[*] /System/Library/Filesystems/apfs.fs/apfs_invert -d /dev/disk0s1 -s $systemdisk -n OS.dmg"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/System/Library/Filesystems/apfs.fs/apfs_invert -d /dev/disk0s1 -s $systemdisk -n OS.dmg"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_apfs /dev/$systemfs /mnt4"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_apfs /dev/$datafs /mnt5"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv -v /mnt4/private/var/* /mnt5"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt4/usr/local/standalone/firmware/Baseband"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir /mnt5/keybags"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/wireless/baseband_data"
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/keybags root@localhost:/mnt5
            if [ -e "$dir"/$deviceid/0.0/Baseband ]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/Baseband root@localhost:/mnt4/usr/local/standalone/firmware
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg /mnt4/usr/local/standalone/firmware/Baseband"
            fi
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/apticket.der root@localhost:/mnt4/System/Library/Caches/
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/sep-firmware.img4 root@localhost:/mnt4/usr/standalone/firmware/
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt4/usr/standalone/firmware/sep-firmware.img4"
            if [ -e "$dir"/$deviceid/0.0/FUD ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt4/usr/standalone/firmware/FUD"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/FUD/* root@localhost:/mnt4/usr/standalone/firmware/FUD
            fi
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rv /mnt4/System/Library/Caches/com.apple.factorydata"
            if [ -e "$dir"/$deviceid/0.0/com.apple.factorydata ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt4/System/Library/Caches/com.apple.factorydata"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/com.apple.factorydata/* root@localhost:/mnt4/System/Library/Caches/com.apple.factorydata
            fi
            if [ -e "$dir"/$deviceid/0.0/IC-Info.sisv ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/mobile/Library/FairPlay/iTunes_Control/iTunes/"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/IC-Info.sisv root@localhost:/mnt5/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv 2> /dev/null
            fi
            if [ -e "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/wireless/Library/Preferences/"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist root@localhost:/mnt5/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist 2> /dev/null
            fi
            cp "$dir"/jb/fstab_apfs "$dir"/$deviceid/$cpid/$version/fstab.patched
            sed -i -e "s/mnt4/$systemdisk/g" "$dir"/$deviceid/$cpid/$version/fstab.patched
            sed -i -e "s/mnt5/$datadisk/g" "$dir"/$deviceid/$cpid/$version/fstab.patched
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/fstab.patched root@localhost:/mnt4/etc/fstab
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/data_ark.plist_ios10.tar root@localhost:/mnt5/
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt5/data_ark.plist_ios10.tar -C /mnt5"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt5/data_ark.plist_ios10.tar"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt5/root/Library/Lockdown/device_private_key.pem"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt5/root/Library/Lockdown/device_public_key.pem"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/root/Library/Lockdown/escrow_records"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/root/Library/Lockdown/pair_records"
            if [ ! -e "$dir"/$deviceid/0.0/activation_records/activation_record.plist ]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt4/usr/libexec/mobileactivationd "$dir"/$deviceid/$cpid/$version/mobactivationd.raw
                "$bin"/mobactivationd64patcher "$dir"/$deviceid/$cpid/$version/mobactivationd.raw "$dir"/$deviceid/$cpid/$version/mobactivationd.patched -b -c -d
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/mobactivationd.patched root@localhost:/mnt4/usr/libexec/mobileactivationd
            fi
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.saurik.Cydia.Startup.plist root@localhost:/mnt4/System/Library/LaunchDaemons
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown root:wheel /mnt4/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist"
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/kernelcache root@localhost:/mnt4/System/Library/Caches/com.apple.kernelcaches
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt4/.cydia_no_stash"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown root:wheel /mnt4/.cydia_no_stash"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt4/.cydia_no_stash"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt4/usr/lib/libmis.dylib"
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/aopfw.img4 root@localhost:/mnt4/usr/standalone/firmware/FUD/AOP.img4
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/homerfw.img4 root@localhost:/mnt4/usr/standalone/firmware/FUD/Homer.img4
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/avefw.img4 root@localhost:/mnt4/usr/standalone/firmware/FUD/AVE.img4
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/trustcache root@localhost:/mnt4/usr/standalone/firmware/FUD/StaticTrustCache.img4
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/multitouch.img4 root@localhost:/mnt4/usr/standalone/firmware/FUD/Multitouch.img4
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/audiocodecfirmware.img4 root@localhost:/mnt4/usr/standalone/firmware/FUD/AudioCodecFirmware.img4
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt4/usr/standalone/firmware/FUD/AOP.img4"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt4/usr/standalone/firmware/FUD/Homer.img4"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt4/usr/standalone/firmware/FUD/AVE.img4"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt4/usr/standalone/firmware/FUD/StaticTrustCache.img4"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt4/usr/standalone/firmware/FUD/Multitouch.img4"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt4/usr/standalone/firmware/FUD/AudioCodecFirmware.img4"
            if [ -e "$dir"/$deviceid/0.0/activation_records ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/root/Library/Lockdown/activation_records"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/activation_records root@localhost:/mnt5/root/Library/Lockdown 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg /mnt5/root/Library/Lockdown/activation_records"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/mobile/Library/mad/activation_records"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/activation_records root@localhost:/mnt5/mobile/Library/mad 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg /mnt5/mobile/Library/mad/activation_records"
            fi
            if [ -e "$dir"/$deviceid/0.0/activation_records/activation_record.plist ]; then
                if [ -e "$dir"/$deviceid/0.0/data_ark.plist ]; then
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/data_ark.plist root@localhost:/mnt5/root/Library/Lockdown/data_ark.plist 2> /dev/null
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt5/root/Library/Lockdown/data_ark.plist"
                fi
            fi
            if [[ "$version" == "10."* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/AppleInternal.tar root@localhost:/mnt4/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/PrototypeTools.framework_ios10.tar root@localhost:/mnt4/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt4/System/Library/CoreServices/SystemVersion.plist "$dir"/$deviceid/$cpid/$version/SystemVersion.plist
                sed -i -e 's/<\/dict>/<key>ReleaseType<\/key><string>Internal<\/string><key>ProductType<\/key><string>Internal<\/string><\/dict>/g' "$dir"/$deviceid/$cpid/$version/SystemVersion.plist
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/SystemVersion.plist root@localhost:/mnt4/System/Library/CoreServices/SystemVersion.plist
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt4/System/Library/CoreServices/SpringBoard.app/en.lproj/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt4/System/Library/CoreServices/SpringBoard.app/en_GB.lproj/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.apple.springboard_ios10.plist root@localhost:/mnt5/mobile/Library/Preferences/com.apple.springboard.plist
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt4/PrototypeTools.framework_ios10.tar -C /mnt4/System/Library/PrivateFrameworks/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt4/System/Library/PrivateFrameworks/PrototypeTools.framework'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/PrototypeTools.framework_ios10.tar'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt4/AppleInternal.tar -C /mnt4/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt4/AppleInternal/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/AppleInternal.tar'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt5/mobile/Library/Caches/com.apple.MobileGestalt.plist'
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/Meridian.app.tar root@localhost:/mnt4/
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt4/Meridian.app.tar -C /mnt4/Applications' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/Meridian.app.tar' 2> /dev/null
            elif [[ "$version" == "11."* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/AppleInternal.tar root@localhost:/mnt4/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/PrototypeTools.framework_ios11.tar root@localhost:/mnt4/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt4/System/Library/CoreServices/SystemVersion.plist "$dir"/$deviceid/$cpid/$version/SystemVersion.plist
                sed -i -e 's/<\/dict>/<key>ReleaseType<\/key><string>Internal<\/string><key>ProductType<\/key><string>Internal<\/string><\/dict>/g' "$dir"/$deviceid/$cpid/$version/SystemVersion.plist
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/SystemVersion.plist root@localhost:/mnt4/System/Library/CoreServices/SystemVersion.plist
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt4/System/Library/CoreServices/SpringBoard.app/en.lproj/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt4/System/Library/CoreServices/SpringBoard.app/en_GB.lproj/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.apple.springboard_ios10.plist root@localhost:/mnt5/mobile/Library/Preferences/com.apple.springboard.plist
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt4/PrototypeTools.framework_ios11.tar -C /mnt4/System/Library/PrivateFrameworks/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt4/System/Library/PrivateFrameworks/PrototypeTools.framework'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/PrototypeTools.framework_ios11.tar'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt4/AppleInternal.tar -C /mnt4/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt4/AppleInternal/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/AppleInternal.tar'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt5/mobile/Library/Caches/com.apple.MobileGestalt.plist'
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/electra1141.app.tar root@localhost:/mnt4/
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt4/electra1141.app.tar -C /mnt4/Applications/"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt4/Applications/electra1141.app'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt4/System/Library/DataClassMigrators/SystemAppMigrator.migrator/"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv -v /mnt5/staged_system_apps/* /mnt4/Applications"
            elif [[ "$version" == "12."* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/AppleInternal.tar root@localhost:/mnt4/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/PrototypeTools.framework_ios12.tar root@localhost:/mnt4/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt4/System/Library/CoreServices/SystemVersion.plist "$dir"/$deviceid/$cpid/$version/SystemVersion.plist
                sed -i -e 's/<\/dict>/<key>ReleaseType<\/key><string>Internal<\/string><key>ProductType<\/key><string>Internal<\/string><\/dict>/g' "$dir"/$deviceid/$cpid/$version/SystemVersion.plist
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/SystemVersion.plist root@localhost:/mnt4/System/Library/CoreServices/SystemVersion.plist
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt4/System/Library/CoreServices/SpringBoard.app/en.lproj/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt4/System/Library/CoreServices/SpringBoard.app/en_GB.lproj/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.apple.springboard_ios10.plist root@localhost:/mnt5/mobile/Library/Preferences/com.apple.springboard.plist
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt4/PrototypeTools.framework_ios12.tar -C /mnt4/System/Library/PrivateFrameworks/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt4/System/Library/PrivateFrameworks/PrototypeTools.framework'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/PrototypeTools.framework_ios12.tar'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt4/AppleInternal.tar -C /mnt4/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt4/AppleInternal/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/AppleInternal.tar'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt5/mobile/Library/Caches/com.apple.MobileGestalt.plist'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt4/System/Library/DataClassMigrators/SystemAppMigrator.migrator/"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv -v /mnt5/staged_system_apps/* /mnt4/Applications"
                if [ -e "$dir"/jb/Chimera.app.tar.gz ]; then
                    read -p "would you like to install Chimera.app.tar.gz to /mnt4/Applications? " r1
                    if [[ "$r1" = 'yes' || "$r1" = 'y' ]]; then
                        "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/Chimera.app.tar.gz root@localhost:/mnt4/
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xzvf /mnt4/Chimera.app.tar.gz -C /mnt4/Applications/"
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt4/Applications/Chimera.app'
                    fi
                fi
                echo "[*] If you boot now, you will get stuck at the \"screen time\" step in Setup.app"
                echo "[*] You must delete Setup.app if you want to be able to use iOS $version"
                echo "[*] See https://files.catbox.moe/96vhbl.mov for a video demonstration of the issue"
                echo "[*] I will now drop you into ssh so you can do this, the root fs is mounted at /mnt4"
                ssh -o StrictHostKeyChecking=no -p2222 root@localhost
            fi
            #"$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram oblit-inprogress=5"
        else
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "cat /gpt.txt | gptfdisk /dev/rdisk0s1" 2> /dev/null
            sleep 2
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/sync" 2> /dev/null
            sleep 1
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/sync" 2> /dev/null
            sleep 1
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/sync" 2> /dev/null
            sleep 1
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_hfs -s -v System -J -b 4096 -n a=4096,c=4096,e=4096 /dev/disk0s1s1"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/newfs_hfs -s -v Data -J -b 4096 -n a=4096,c=4096,e=4096 /dev/disk0s1s2"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_hfs /dev/disk0s1s1 /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs -o suid,dev /dev/disk0s1s2 /mnt2" 2> /dev/null
            echo "[*] Uploading $dir/$deviceid/$cpid/$version/OS.tar, this may take up to 10 minutes.."
            "$bin"/sshpass -p 'alpine' scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/OS.tar root@localhost:/mnt2 2> /dev/null
            remote_cmd "tar -xvf /mnt2/OS.tar -C /mnt1" && {
                echo "[*] Done"
            } || {
                remote_cmd "tar -xvf /mnt2/OS.tar -C /mnt1" && {
                    echo "[*] Done"
                } || {
                    "$bin"/sshpass -p 'alpine' scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/OS.tar root@localhost:/mnt2 2> /dev/null
                    remote_cmd "tar -xvf /mnt2/OS.tar -C /mnt1" && {
                        echo "[*] Done"
                    } || {
                        remote_cmd "tar -xvf /mnt2/OS.tar -C /mnt1" && {
                            echo "[*] Done"
                        } || {
                            echo "[*] An error occured while trying to upload $dir/$deviceid/$cpid/$version/OS.tar"
                            exit 0
                        }
                    }
                }
            }
            if [[ "$version" == "7."* ]]; then
                "$bin"/sshpass -p 'alpine' scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/cydia_ios7.tar root@localhost:/mnt2 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/cydia_ios7.tar -C /mnt1"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/cydia_ios7.tar" 2> /dev/null
            elif [[ "$version" == "8."* || "$version" == "9."* ]]; then
                "$bin"/sshpass -p 'alpine' scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/cydia.tar root@localhost:/mnt2 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/cydia.tar -C /mnt1"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/cydia.tar" 2> /dev/null
            fi
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv -v /mnt1/private/var/* /mnt2"
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt1/usr/local/standalone/firmware/Baseband" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir /mnt2/keybags" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/wireless/baseband_data" 2> /dev/null
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/keybags root@localhost:/mnt2 2> /dev/null
            if [ -e "$dir"/$deviceid/0.0/Baseband ]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/Baseband root@localhost:/mnt1/usr/local/standalone/firmware 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg /mnt1/usr/local/standalone/firmware/Baseband"
            fi
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/apticket.der root@localhost:/mnt1/System/Library/Caches/ 2> /dev/null
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/sep-firmware.img4 root@localhost:/mnt1/usr/standalone/firmware/ 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt1/usr/standalone/firmware/sep-firmware.img4"
            if [ -e "$dir"/$deviceid/0.0/FUD ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir /mnt1/usr/standalone/firmware/FUD"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/FUD/* root@localhost:/mnt1/usr/standalone/firmware/FUD
            fi
            if [ -e "$dir"/$deviceid/0.0/com.apple.factorydata ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir /mnt1/System/Library/Caches/com.apple.factorydata"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/com.apple.factorydata/* root@localhost:/mnt1/System/Library/Caches/com.apple.factorydata 2> /dev/null
            fi
            if [ -e "$dir"/$deviceid/0.0/IC-Info.sisv ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/IC-Info.sisv root@localhost:/mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv 2> /dev/null
            fi
            if [ -e "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/wireless/Library/Preferences/"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist root@localhost:/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist 2> /dev/null
            fi
            if [ -e "$dir"/$deviceid/0.0/activation_records ]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/root/Library/Lockdown/activation_records"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/activation_records root@localhost:/mnt2/root/Library/Lockdown 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg /mnt2/root/Library/Lockdown/activation_records"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/mobile/Library/mad/activation_records"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/activation_records root@localhost:/mnt2/mobile/Library/mad 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg /mnt2/mobile/Library/mad/activation_records"
            fi
            if [[ "$version" == "10."* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/data_ark.plist_ios10.tar root@localhost:/mnt2/
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist_ios10.tar -C /mnt2"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/data_ark.plist_ios10.tar"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt2/root/Library/Lockdown/device_private_key.pem"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt2/root/Library/Lockdown/device_public_key.pem"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/root/Library/Lockdown/escrow_records"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/root/Library/Lockdown/pair_records"
                if [ ! -e "$dir"/$deviceid/0.0/activation_records/activation_record.plist ]; then
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/usr/libexec/mobileactivationd "$dir"/$deviceid/$cpid/$version/mobactivationd.raw
                    "$bin"/mobactivationd64patcher "$dir"/$deviceid/$cpid/$version/mobactivationd.raw "$dir"/$deviceid/$cpid/$version/mobactivationd.patched -b -c -d
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/mobactivationd.patched root@localhost:/mnt1/usr/libexec/mobileactivationd
                fi
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.saurik.Cydia.Startup.plist root@localhost:/mnt1/System/Library/LaunchDaemons
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown root:wheel /mnt1/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/kernelcache root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/.cydia_no_stash"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown root:wheel /mnt1/.cydia_no_stash"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt1/.cydia_no_stash"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/usr/lib/libmis.dylib"
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/AppleInternal.tar root@localhost:/mnt1/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/PrototypeTools.framework_ios10.tar root@localhost:/mnt1/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/CoreServices/SystemVersion.plist "$dir"/$deviceid/$cpid/$version/SystemVersion.plist
                sed -i -e 's/<\/dict>/<key>ReleaseType<\/key><string>Internal<\/string><key>ProductType<\/key><string>Internal<\/string><\/dict>/g' "$dir"/$deviceid/$cpid/$version/SystemVersion.plist
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/SystemVersion.plist root@localhost:/mnt1/System/Library/CoreServices/SystemVersion.plist
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en.lproj/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en_GB.lproj/
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.apple.springboard_ios10.plist root@localhost:/mnt2/mobile/Library/Preferences/com.apple.springboard.plist
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/PrototypeTools.framework_ios10.tar -C /mnt1/System/Library/PrivateFrameworks/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/System/Library/PrivateFrameworks/PrototypeTools.framework'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/PrototypeTools.framework_ios10.tar'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/AppleInternal.tar -C /mnt1/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/AppleInternal/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/AppleInternal.tar'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt2/mobile/Library/Caches/com.apple.MobileGestalt.plist'
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/Meridian.app.tar root@localhost:/mnt1/
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt1/Meridian.app.tar -C /mnt1/Applications' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/Meridian.app.tar' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileSafari.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/Calendar.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MapsDataClassMigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileSlideShow.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/iapmigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileMailMigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileNotes.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/WebBookmarks.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/iTunesStore.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MessagesDataMigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/HealthMigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/DAAccount.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/CoreLocationMigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/aopfw.img4 root@localhost:/mnt1/usr/standalone/firmware/FUD/AOP.img4
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/homerfw.img4 root@localhost:/mnt1/usr/standalone/firmware/FUD/Homer.img4
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/avefw.img4 root@localhost:/mnt1/usr/standalone/firmware/FUD/AVE.img4
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/trustcache root@localhost:/mnt1/usr/standalone/firmware/FUD/StaticTrustCache.img4
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/multitouch.img4 root@localhost:/mnt1/usr/standalone/firmware/FUD/Multitouch.img4
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/audiocodecfirmware.img4 root@localhost:/mnt1/usr/standalone/firmware/FUD/AudioCodecFirmware.img4
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt1/usr/standalone/firmware/FUD/AOP.img4"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt1/usr/standalone/firmware/FUD/Homer.img4"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt1/usr/standalone/firmware/FUD/AVE.img4"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt1/usr/standalone/firmware/FUD/StaticTrustCache.img4"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt1/usr/standalone/firmware/FUD/Multitouch.img4"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt1/usr/standalone/firmware/FUD/AudioCodecFirmware.img4"
            else
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/data_ark.plist_ios7.tar root@localhost:/mnt2/ 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist_ios7.tar -C /mnt2" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/data_ark.plist_ios7.tar" 2> /dev/null  
            fi
            if [[ "$version" == "7."* || "$version" == "8."* || "$version" == "9."* ]]; then
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/fstab_rw root@localhost:/mnt1/etc/fstab 2> /dev/null
            else
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/fstab root@localhost:/mnt1/etc/ 2> /dev/null
            fi
            if [[ "$version" == "8."* || "$version" == "9.0"* || "$version" == "9.1"* || "$version" == "9.2"* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/data_ark.plist_ios8.tar root@localhost:/mnt2/ 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist_ios8.tar -C /mnt2" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/data_ark.plist_ios8.tar" 2> /dev/null
                if [ ! -e "$dir"/$deviceid/0.0/activation_records/activation_record.plist ]; then
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/PrivateFrameworks/MobileActivation.framework/Support/mobactivationd "$dir"/$deviceid/$cpid/$version/mobactivationd.raw 2> /dev/null
                    "$bin"/mobactivationd64patcher "$dir"/$deviceid/$cpid/$version/mobactivationd.raw "$dir"/$deviceid/$cpid/$version/mobactivationd.patched -b -c -d 2> /dev/null
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/mobactivationd.patched root@localhost:/mnt1/System/Library/PrivateFrameworks/MobileActivation.framework/Support/mobactivationd 2> /dev/null
                fi
                if [[ -e "$dir"/$deviceid/$cpid/$version/kcache_12A4331d.raw ]]; then
                    # fix laggy keyboard on ios 8 beta 4
                    # see https://files.catbox.moe/mbyrin.jpg to otherwise see the crash log of kbd
                    # you can remove this command if you want, just know the keyboard will be very laggy
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/Applications/Setup.app" 2> /dev/null
                fi
            elif [[ "$version" == "9.3"* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/data_ark.plist_ios8.tar root@localhost:/mnt2/ 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist_ios8.tar -C /mnt2" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/data_ark.plist_ios8.tar" 2> /dev/null
                if [ ! -e "$dir"/$deviceid/0.0/activation_records/activation_record.plist ]; then
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/usr/libexec/mobileactivationd "$dir"/$deviceid/$cpid/$version/mobactivationd.raw 2> /dev/null
                    "$bin"/mobactivationd64patcher "$dir"/$deviceid/$cpid/$version/mobactivationd.raw "$dir"/$deviceid/$cpid/$version/mobactivationd.patched -b -c -d 2> /dev/null
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/mobactivationd.patched root@localhost:/mnt1/usr/libexec/mobileactivationd 2> /dev/null
                fi
            fi
            if [[ ! "$version" == "10."* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.saurik.Cydia.Startup.plist root@localhost:/mnt1/System/Library/LaunchDaemons 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown root:wheel /mnt1/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist" 2> /dev/null
            fi
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/OS.tar" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/log/asl/SweepStore" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/Library/PreinstalledAssets/*" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/Library/Preferences/.GlobalPreferences.plist" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/.forward" 2> /dev/null
            if [[ "$version" == "7."*  ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/untether_ios7.tar root@localhost:/mnt1/ 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt1/untether_ios7.tar -C /mnt1/' 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/wtfis.app_ios7.tar root@localhost:/mnt1/
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt1/wtfis.app_ios7.tar -C /mnt1/Applications' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/.installed_wtfis" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt1/.installed_wtfis" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/evasi0n7-installed" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt1/evasi0n7-installed" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/mobile/Media/" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt2/mobile/Media/.evasi0n7_installed" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt2/mobile/Media/.evasi0n7_installed" 2> /dev/null
            elif [[ "$version" == "9."*  ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/untether_ios9.tar root@localhost:/mnt1/ 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt1/untether_ios9.tar -C /mnt1/' 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/wtfis.app_ios9.tar root@localhost:/mnt1/ 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt1/wtfis.app_ios9.tar -C /mnt1/Applications' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/.installed_wtfis" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chown root:wheel /mnt1/.installed_wtfis" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt1/.installed_wtfis" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'cp /mnt1/usr/libexec/CrashHousekeeping /mnt1/usr/libexec/CrashHousekeeping_o' 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/startup_ios9.sh root@localhost:/mnt1/usr/libexec/CrashHousekeeping 2> /dev/null
            fi
            if [ -e "$dir"/jb/Evermusic_Free.app.tar ]; then
                if [[ "$version" == "10."* || "$version" == "9."* || "$version" == "8."* ]]; then
                    read -p "would you like to also install Evermusic_Free.app? " r
                    if [[ "$r" = 'yes' || "$r" = 'y' ]]; then
                        "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/Evermusic_Free.app.tar root@localhost:/mnt1/
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt1/Evermusic_Free.app.tar -C /mnt1/Applications/"
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/Applications/Evermusic_Free.app'
                    fi
                fi
            fi
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/kernelcache root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches 2> /dev/null
            if [[ ! "$version" == "10."* ]]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/.cydia_no_stash" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown root:wheel /mnt1/.cydia_no_stash" 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt1/.cydia_no_stash" 2> /dev/null
            fi
            if [[ "$version" == "8."* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/AppleInternal.tar root@localhost:/mnt1/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/PrototypeTools.framework_ios8.tar root@localhost:/mnt1/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/CoreServices/SystemVersion.plist "$dir"/$deviceid/$cpid/$version/SystemVersion.plist 2> /dev/null
                sed -i -e 's/<\/dict>/<key>ReleaseType<\/key><string>Internal<\/string><key>ProductType<\/key><string>Internal<\/string><\/dict>/g' "$dir"/$deviceid/$cpid/$version/SystemVersion.plist 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/SystemVersion.plist root@localhost:/mnt1/System/Library/CoreServices/SystemVersion.plist 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en.lproj/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en_GB.lproj/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.apple.springboard_ios8.plist root@localhost:/mnt2/mobile/Library/Preferences/com.apple.springboard.plist 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/PrototypeTools.framework_ios8.tar -C /mnt1/System/Library/PrivateFrameworks/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/System/Library/PrivateFrameworks/PrototypeTools.framework' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/PrototypeTools.framework_ios8.tar' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/AppleInternal.tar -C /mnt1/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/AppleInternal/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/AppleInternal.tar' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt2/mobile/Library/Caches/com.apple.MobileGestalt.plist' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileNotes.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/InternationalSupportMigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileAsset.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/HealthMigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileSlideShow.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileSafari.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MapsDataClassMigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/PrivateFrameworks/DataMigration.framework/XPCServices/com.apple.datamigrator.xpc/com.apple.datamigrator "$dir"/$deviceid/$cpid/$version/com.apple.datamigrator 2> /dev/null
                "$bin"/datamigrator64patcher "$dir"/$deviceid/$cpid/$version/com.apple.datamigrator "$dir"/$deviceid/$cpid/$version/com.apple.datamigrator_patched -n
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/com.apple.datamigrator_patched root@localhost:/mnt1/System/Library/PrivateFrameworks/DataMigration.framework/XPCServices/com.apple.datamigrator.xpc/com.apple.datamigrator 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/usr/libexec/lockdownd "$dir"/$deviceid/$cpid/$version/lockdownd.raw 2> /dev/null
                "$bin"/lockdownd64patcher "$dir"/$deviceid/$cpid/$version/lockdownd.raw "$dir"/$deviceid/$cpid/$version/lockdownd.patched -u -l 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/lockdownd.patched root@localhost:/mnt1/usr/libexec/lockdownd 2> /dev/null
                #"$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'cp /mnt1/usr/libexec/keybagd /mnt1/usr/libexec/keybagd.bak' 2> /dev/null
                #"$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/fixkeybag root@localhost:/mnt1/usr/libexec/keybagd 2> /dev/null
            elif [[ "$version" == "7."* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/AppleInternal.tar root@localhost:/mnt1/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/PrototypeTools.framework.tar root@localhost:/mnt1/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/CoreServices/SystemVersion.plist "$dir"/$deviceid/$cpid/$version/SystemVersion.plist 2> /dev/null
                sed -i -e 's/<\/dict>/<key>ReleaseType<\/key><string>Internal<\/string><key>ProductType<\/key><string>Internal<\/string><\/dict>/g' "$dir"/$deviceid/$cpid/$version/SystemVersion.plist 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/SystemVersion.plist root@localhost:/mnt1/System/Library/CoreServices/SystemVersion.plist 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en.lproj/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en_GB.lproj/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.apple.springboard.plist root@localhost:/mnt2/mobile/Library/Preferences/com.apple.springboard.plist 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/PrototypeTools.framework.tar -C /mnt1/System/Library/PrivateFrameworks/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/System/Library/PrivateFrameworks/PrototypeTools.framework' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/PrototypeTools.framework.tar' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/AppleInternal.tar -C /mnt1/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/AppleInternal/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/AppleInternal.tar' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt2/mobile/Library/Caches/com.apple.MobileGestalt.plist' 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/usr/libexec/lockdownd "$dir"/$deviceid/$cpid/$version/lockdownd.raw 2> /dev/null
                if [ -e "$dir"/$deviceid/0.0/activation_records/activation_record.plist ]; then
                    "$bin"/lockdownd64patcher "$dir"/$deviceid/$cpid/$version/lockdownd.raw "$dir"/$deviceid/$cpid/$version/lockdownd.patched -u -l 2> /dev/null
                else
                    "$bin"/lockdownd64patcher "$dir"/$deviceid/$cpid/$version/lockdownd.raw "$dir"/$deviceid/$cpid/$version/lockdownd.patched -u -l -b 2> /dev/null
                fi
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/lockdownd.patched root@localhost:/mnt1/usr/libexec/lockdownd 2> /dev/null
            elif [[ "$version" == "9."* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/AppleInternal.tar root@localhost:/mnt1/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/PrototypeTools.framework_ios9.tar root@localhost:/mnt1/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/CoreServices/SystemVersion.plist "$dir"/$deviceid/$cpid/$version/SystemVersion.plist 2> /dev/null
                sed -i -e 's/<\/dict>/<key>ReleaseType<\/key><string>Internal<\/string><key>ProductType<\/key><string>Internal<\/string><\/dict>/g' "$dir"/$deviceid/$cpid/$version/SystemVersion.plist 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/SystemVersion.plist root@localhost:/mnt1/System/Library/CoreServices/SystemVersion.plist 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en.lproj/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en_GB.lproj/ 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/com.apple.springboard_ios9.plist root@localhost:/mnt2/mobile/Library/Preferences/com.apple.springboard.plist 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/PrototypeTools.framework_ios9.tar -C /mnt1/System/Library/PrivateFrameworks/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/System/Library/PrivateFrameworks/PrototypeTools.framework' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/PrototypeTools.framework_ios9.tar' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/AppleInternal.tar -C /mnt1/'
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/AppleInternal/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/AppleInternal.tar' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt2/mobile/Library/Caches/com.apple.MobileGestalt.plist' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileSafari.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/Calendar.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MapsDataClassMigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/MobileSlideShow.migrator/' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/System/Library/DataClassMigrators/iapmigrator.migrator/' 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/usr/libexec/lockdownd "$dir"/$deviceid/$cpid/$version/lockdownd.raw 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/PrivateFrameworks/MobileActivation.framework/Support/mobactivationd "$dir"/$deviceid/$cpid/$version/mobactivationd.raw 2> /dev/null
            fi
            if [ -e "$dir"/$deviceid/0.0/activation_records/activation_record.plist ]; then
                if [ -e "$dir"/$deviceid/0.0/data_ark.plist ]; then
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/data_ark.plist root@localhost:/mnt2/root/Library/Lockdown/data_ark.plist 2> /dev/null
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags schg /mnt2/root/Library/Lockdown/data_ark.plist"
                fi
            fi
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg /mnt1/usr/standalone/firmware/FUD"
            if [[ "$version" == "9.3"* || "$version" == "10."* ]]; then
                # fix Sandbox: hook..execve() killing %s pid %ld[UID: %d]: failure in upcall to containermanagerd for a platform app\n 
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/PrivateFrameworks/MobileContainerManager.framework/Support/containermanagerd "$dir"/$deviceid/$cpid/$version/containermanagerd.raw 2> /dev/null
                "$bin"/containermanagerd64patcher "$dir"/$deviceid/$cpid/$version/containermanagerd.raw "$dir"/$deviceid/$cpid/$version/containermanagerd.patched -f -d 2> /dev/null
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/containermanagerd.patched root@localhost:/mnt1/System/Library/PrivateFrameworks/MobileContainerManager.framework/Support/containermanagerd 2> /dev/null
            fi
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/usr/lib/libmis.dylib" 2> /dev/null
            if [[ "$version" == "9."* ]]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram -c" 2> /dev/null
            fi
        fi
        $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
        sleep 5
        if [ ! -e "$dir"/$deviceid/0.0/activation_records/activation_record.plist ]; then
            if [[ "$version" == "9.3"* || "$version" == "10."* || "$version" == "11."* || "$version" == "12."* ]]; then
                if [ -e "$dir"/$deviceid/$cpid/$version/iBSS.img4 ]; then
                    if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
                        if [[ "$deviceid" == "iPhone10"* || "$cpid" == "0x8015"* ]]; then
                            "$bin"/dfuhelper.sh
                        elif [[ "$cpid" = 0x801* && "$deviceid" != *"iPad"* ]]; then
                            "$bin"/dfuhelper2.sh
                        else
                            "$bin"/dfuhelper3.sh
                        fi
                    fi
                    _wait_for_dfu
                    sudo killall -STOP -c usbd
                    read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
                    if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
                        read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                        echo "[*] Waiting 10 seconds before continuing.."
                        sleep 10
                    elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
                        echo "[*] Ok no problem, continuing.."
                    else
                        echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
                        read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                        echo "[*] Waiting 10 seconds before continuing.."
                        sleep 10
                    fi
                    cd "$dir"/$deviceid/$cpid/$version
                    if [[ "$deviceid" == "iPhone6"* || "$deviceid" == "iPad4"* ]]; then
                        "$bin"/ipwnder -p
                    else
                        "$bin"/gaster pwn
                        "$bin"/gaster reset
                    fi
                    "$bin"/irecovery -f iBSS.img4
                    "$bin"/irecovery -f iBSS.img4
                    "$bin"/irecovery -f iBEC.img4
                    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
                        sleep 1
                        "$bin"/irecovery -c go
                        sleep 2
                    fi
                    "$bin"/irecovery -f devicetree.img4
                    "$bin"/irecovery -c devicetree
                    if [ -e ./trustcache.img4 ]; then
                        "$bin"/irecovery -f trustcache.img4
                        "$bin"/irecovery -c firmware
                    fi
                    "$bin"/irecovery -f kernelcache.img4
                    "$bin"/irecovery -c bootx &
                    cd "$dir"/
                fi
                _kill_if_running iproxy
                echo "[*] Step 1 of downwgrading to iOS $version is now done"
                echo "[*] The device should now boot without any issue and show a progress bar"
                echo "[-] You are NOT done!!"
                echo "[-] You are NOT done!! Do NOT exit out of the script!!!"
                echo "[*] When your device gets to the setup screen, put the device back into dfu mode"
                echo "[*] We will then finish patching your device to allow you to navigate to the lock screen"
                _wait_for_dfu
                sudo killall -STOP -c usbd
                read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
                if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
                    read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                    echo "[*] Waiting 10 seconds before continuing.."
                    sleep 10
                elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
                    echo "[*] Ok no problem, continuing.."
                else
                    echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
                    read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                    echo "[*] Waiting 10 seconds before continuing.."
                    sleep 10
                fi
                if [[ "$version" == "7."* || "$version" == "8."* ]]; then
                    cd "$dir"/$deviceid/$cpid/ramdisk/8.4.1
                elif [[ "$version" == "10.3"* || "$version" == "11."* ||  "$version" == "12."* ]]; then
                    cd "$dir"/$deviceid/$cpid/ramdisk/$r
                else
                    cd "$dir"/$deviceid/$cpid/ramdisk/11.4
                fi
                if [[ "$deviceid" == "iPhone6"* || "$deviceid" == "iPad4"* ]]; then
                    "$bin"/ipwnder -p
                else
                    "$bin"/gaster pwn
                    "$bin"/gaster reset
                fi
                "$bin"/irecovery -f iBSS.img4
                "$bin"/irecovery -f iBSS.img4
                "$bin"/irecovery -f iBEC.img4
                if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
                    sleep 1
                    "$bin"/irecovery -c go
                    sleep 2
                fi
                "$bin"/irecovery -f ramdisk.img4
                "$bin"/irecovery -c ramdisk
                "$bin"/irecovery -f devicetree.img4
                "$bin"/irecovery -c devicetree
                if [ -e ./trustcache.img4 ]; then
                    "$bin"/irecovery -f trustcache.img4
                    "$bin"/irecovery -c firmware
                fi
                "$bin"/irecovery -f kernelcache.img4
                "$bin"/irecovery -c bootx &
                cd "$dir"/
                read -p "[*] Press Enter once your device has fully booted into the SSH ramdisk " r1
                echo "[*] Waiting 6 seconds before continuing.."
                sleep 6
                sudo killall -STOP -c usbd
                read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
                if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
                    read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                    echo "[*] Waiting 10 seconds before continuing.."
                    sleep 10
                elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
                    echo "[*] Ok no problem, continuing.."
                else
                    echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
                    read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                    echo "[*] Waiting 10 seconds before continuing.."
                    sleep 10
                fi
                "$bin"/iproxy 2222 22 &
                if [[ "$version" == "9.3"* || "$version" == "10.0"* || "$version" == "10.1"* || "$version" == "10.2"* ]]; then
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1" 2> /dev/null
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s2 /mnt2" 2> /dev/null
                    # /mnt2/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library/internal/data_ark.plist
                    dataarkplist=$(remote_cmd "/usr/bin/find /mnt2/containers/Data/System -name 'internal'" 2> /dev/null)
                    dataarkplist="$dataarkplist/data_ark.plist"
                    echo $dataarkplist
                    if [ -e "$dir"/$deviceid/0.0/IC-Info.sisv ]; then
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/"
                        "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/IC-Info.sisv root@localhost:/mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv 2> /dev/null
                    fi
                    if [ -e "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist ]; then
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/wireless/Library/Preferences/"
                        "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist root@localhost:/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist 2> /dev/null
                    fi
                    if [[ "$dataarkplist" == "/mnt2/containers/Data/System"* ]]; then
                        folder=$(echo $dataarkplist | sed 's/\/data_ark.plist//g')
                        folder=$(echo $folder | sed 's/\/internal//g')
                        # /mnt2/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library
                        if [[ "$folder" == "/mnt2/containers/Data/System"* ]]; then
                            if [ -e "$dir"/$deviceid/0.0/activation_records ]; then
                                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p $folder/activation_records"
                                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/activation_records root@localhost:$folder 2> /dev/null
                                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg $folder/activation_records"
                            fi
                        fi
                    fi
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/data_ark.plis_ root@localhost:$dataarkplist
                else
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_apfs /dev/disk0s1s$systemdisk /mnt4"
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_apfs /dev/disk0s1s$datadisk /mnt5"
                    # /mnt5/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library/internal/data_ark.plist
                    dataarkplist=$(remote_cmd "/usr/bin/find /mnt5/containers/Data/System -name 'data_ark.plist'" 2> /dev/null)
                    echo $dataarkplist
                    if [ -e "$dir"/$deviceid/0.0/IC-Info.sisv ]; then
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/mobile/Library/FairPlay/iTunes_Control/iTunes/"
                        "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/IC-Info.sisv root@localhost:/mnt5/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv 2> /dev/null
                    fi
                    if [ -e "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist ]; then
                        "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/wireless/Library/Preferences/"
                        "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist root@localhost:/mnt5/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist 2> /dev/null
                    fi
                    if [[ "$dataarkplist" == "/mnt5/containers/Data/System"* ]]; then
                        folder=$(echo $dataarkplist | sed 's/\/data_ark.plist//g')
                        folder=$(echo $folder | sed 's/\/internal//g')
                        # /mnt5/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library
                        if [[ "$folder" == "/mnt5/containers/Data/System"* ]]; then
                            if [ -e "$dir"/$deviceid/0.0/activation_records ]; then
                                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p $folder/activation_records"
                                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/activation_records root@localhost:$folder 2> /dev/null
                                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg $folder/activation_records"
                            fi
                        fi
                    fi
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/data_ark.plis_ root@localhost:$dataarkplist
                fi
                if [[ "$version" == "10."* ]]; then
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/Meridian.app.tar root@localhost:/mnt4/
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt4/Meridian.app.tar -C /mnt4/Applications' 2> /dev/null
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/Meridian.app.tar' 2> /dev/null
                fi
                $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
                sleep 5
            fi
        fi
        _kill_if_running iproxy
        if [ -e "$dir"/$deviceid/$cpid/$version/iBSS.img4 ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
                if [[ "$deviceid" == "iPhone10"* || "$cpid" == "0x8015"* ]]; then
                    "$bin"/dfuhelper.sh
                elif [[ "$cpid" = 0x801* && "$deviceid" != *"iPad"* ]]; then
                    "$bin"/dfuhelper2.sh
                else
                    "$bin"/dfuhelper3.sh
                fi
            fi
            _wait_for_dfu
            sudo killall -STOP -c usbd
            read -p "[*] You may need to unplug and replug your cable, would you like to? " r1
            if [[ "$r1" == "yes" || "$r1" == "y" ]]; then
                read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                echo "[*] Waiting 10 seconds before continuing.."
                sleep 10
            elif [[ "$r1" == "no" || "$r1" == "n" ]]; then
                echo "[*] Ok no problem, continuing.."
            else
                echo "[*] That was not a response I was expecting, I'm going to treat that as a 'yes'.."
                read -p "[*] Unplug and replug the end of the cable that is attached to your Mac and then press the Enter key on your keyboard " r1
                echo "[*] Waiting 10 seconds before continuing.."
                sleep 10
            fi
            cd "$dir"/$deviceid/$cpid/$version
            if [[ "$deviceid" == "iPhone6"* || "$deviceid" == "iPad4"* ]]; then
                "$bin"/ipwnder -p
            else
                "$bin"/gaster pwn
                "$bin"/gaster reset
            fi
            "$bin"/irecovery -f iBSS.img4
            "$bin"/irecovery -f iBSS.img4
            "$bin"/irecovery -f iBEC.img4
            if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
                sleep 1
                "$bin"/irecovery -c go
                sleep 2
            fi
            "$bin"/irecovery -f devicetree.img4
            "$bin"/irecovery -c devicetree
            if [ -e ./trustcache.img4 ]; then
                "$bin"/irecovery -f trustcache.img4
                "$bin"/irecovery -c firmware
            fi
            "$bin"/irecovery -f kernelcache.img4
            "$bin"/irecovery -c bootx &
            cd "$dir"/
        fi
        _kill_if_running iproxy
        echo "done"
        exit 0
    else
        if [[ "$ramdisk" == 1 || "$fix_activation" == 1 || "$dump_blobs" == 1 ]]; then
            remote_cmd "/sbin/mount_apfs /dev/disk0s1s1 /mnt1 2> /dev/null" && {
                echo "[*] /dev/disk0s1s1 is an APFS volume"
            } || {
                echo "[*] /dev/disk0s1s1 is NOT an APFS volume"
            }
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            remote_cmd "/sbin/mount_apfs /dev/disk0s1s1s1 /mnt1 2> /dev/null" && {
                echo "[*] /dev/disk0s1s1s1 is an APFS volume"
            } || {
                echo "[*] /dev/disk0s1s1s1 is NOT an APFS volume"
            }
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            remote_cmd "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1 2> /dev/null" && {
                echo "[*] /dev/disk0s1s1 is an HFS+ volume"
            } || {
                echo "[*] /dev/disk0s1s1 is NOT an HFS+ volume"
            }
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            if [[ "$version" == "7."* || "$version" == "8."* || "$version" == "9."* || "$version" == "10.0"* || "$version" == "10.1"* || "$version" == "10.2"* ]]; then
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1" 2> /dev/null
                if [[ "$version" == "9.0"* || "$version" == "9.1"* || "$version" == "9.2"* ]]; then
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -t hfs /dev/disk0s1s2 /mnt2" 2> /dev/null
                else
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s2 /mnt2" 2> /dev/null
                fi
            else
                echo "[*] Testing for baseband presence"
                systemdisk=8
                datadisk=9
                systemfs=disk0s1s$systemdisk
                datafs=disk0s1s$datadisk
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_apfs /dev/disk0s1s$systemdisk /mnt4"
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount_apfs /dev/disk0s1s$datadisk /mnt5"
            fi
        fi
        if [[ "$dump_blobs" == 1 ]]; then
            mkdir -p "$dir"/$deviceid/0.0/
            if [[ ! -e "$dir"/$deviceid/0.0/apticket.der ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/System/Library/Caches/apticket.der "$dir"/$deviceid/0.0/apticket.der 2> /dev/null
            fi
            if [[ -e "$dir"/$deviceid/0.0/apticket.der ]]; then
                echo "$dir"/$deviceid/0.0/apticket.der
            fi
            $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
            _kill_if_running iproxy
            exit 0
        elif [[ "$dump_nand" == 1 ]]; then
            # dd if=/dev/sda bs=5M conv=fsync status=progress | gzip -c -9 | ssh user@DestinationIP 'gzip -d | dd of=/dev/sda bs=5M'
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            echo "[*] Backing up /dev/disk0 to $dir/$deviceid/disk0.gz, this may take up to 15 minutes.."
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "dd if=/dev/disk0 bs=64k | gzip -1 -" | dd of=disk0.gz bs=64k
            echo "[*] Backing up /dev/disk0s1s1 to $dir/$deviceid/disk0s1s1.gz, this may take up to 15 minutes.."
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "dd if=/dev/disk0s1s1 bs=64k | gzip -1 -" | dd of=disk0s1s1.gz bs=64k
            read -p "would you like to also back up /dev/disk0s1s2 to $dir/$deviceid/disk0s1s2.gz? " r
            if [[ "$r" == "yes" || "$r" == "y" ]]; then
                 echo "[*] Backing up /dev/disk0s1s2 to $dir/$deviceid/disk0s1s2.gz, this may take up to 15 minutes.."
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "dd if=/dev/disk0s1s2 bs=64k | gzip -1 -" | dd of=disk0s1s2.gz bs=64k
            fi
            echo "[*] Disabling auto-boot in nvram to prevent effaceable storage issues.."
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram auto-boot=false" 2> /dev/null
            echo "[*] You can enable auto-boot again at any time by running $0 $version --fix-auto-boot"
            echo "[*] Done"
            $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
            _kill_if_running iproxy
            exit 0
        elif [[ "$restore_nand" == 1 ]]; then
            # dd if=/dev/sda bs=5M conv=fsync status=progress | gzip -c -9 | ssh user@DestinationIP 'gzip -d | dd of=/dev/sda bs=5M'
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            echo "[*] Restoring /dev/disk0 from $dir/disk0.gz, this may take up to 15 minutes.."
            dd if=disk0.gz bs=64k | "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "gzip -d | dd of=/dev/disk0 bs=64k"
            echo "[*] Enabling auto-boot in nvram to allow booting the restored nand after a reboot.."
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram auto-boot=true" 2> /dev/null
            echo "[*] Done"
            $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
            _kill_if_running iproxy
            exit 0
        elif [[ "$restore_mnt1" == 1 ]]; then
            # dd if=/dev/sda bs=5M conv=fsync status=progress | gzip -c -9 | ssh user@DestinationIP 'gzip -d | dd of=/dev/sda bs=5M'
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            echo "[*] Restoring /dev/disk0s1s1 from $dir/disk0s1s1.gz, this may take up to 15 minutes.."
            dd if=disk0s1s1.gz bs=64k | "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "gzip -d | dd of=/dev/disk0s1s1 bs=64k"
            echo "[*] Enabling auto-boot in nvram to allow booting the restored nand after a reboot.."
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram auto-boot=true" 2> /dev/null
            echo "[*] Done"
            $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
            _kill_if_running iproxy
            exit 0
        elif [[ "$restore_mnt2" == 1 ]]; then
            # dd if=/dev/sda bs=5M conv=fsync status=progress | gzip -c -9 | ssh user@DestinationIP 'gzip -d | dd of=/dev/sda bs=5M'
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            echo "[*] Restoring /dev/disk0s1s2 from $dir/disk0s1s2.gz, this may take up to 15 minutes.."
            dd if=disk0s1s2.gz bs=64k | "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "gzip -d | dd of=/dev/disk0s1s2 bs=64k"
            echo "[*] Enabling auto-boot in nvram to allow booting the restored nand after a reboot.."
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram auto-boot=true" 2> /dev/null
            echo "[*] Done"
            $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
            _kill_if_running iproxy
            exit 0
        elif [[ "$disable_NoMoreSIGABRT" == 1 ]]; then
            # dd if=/dev/sda bs=5M conv=fsync status=progress | gzip -c -9 | ssh user@DestinationIP 'gzip -d | dd of=/dev/sda bs=5M'
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            echo "[*] Disabling NoMoreSIGABRT on /dev/disk0s1s2.."
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/bin/dd if=/dev/disk0s1s2 of=/mnt1/out.img bs=512 count=8192'
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/out.img "$dir"/$deviceid/$cpid/$version/NoMoreSIGABRT.img
            "$bin"/Kernel64Patcher "$dir"/$deviceid/$cpid/$version/NoMoreSIGABRT.img "$dir"/$deviceid/$cpid/$version/NoMoreSIGABRT.patched -o
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/NoMoreSIGABRT.patched root@localhost:/mnt1/out.img
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/bin/dd if=/mnt1/out.img of=/dev/disk0s1s2 bs=512 count=8192'
            echo "[*] Done"
            $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
            _kill_if_running iproxy
            exit 0
        elif [[ "$NoMoreSIGABRT" == 1 ]]; then
            # dd if=/dev/sda bs=5M conv=fsync status=progress | gzip -c -9 | ssh user@DestinationIP 'gzip -d | dd of=/dev/sda bs=5M'
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1" 2> /dev/null
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2" 2> /dev/null
            echo "[*] Enabling NoMoreSIGABRT on /dev/disk0s1s2.."
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/bin/dd if=/dev/disk0s1s2 of=/mnt1/out.img bs=512 count=8192'
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 root@localhost:/mnt1/out.img "$dir"/$deviceid/$cpid/$version/NoMoreSIGABRT.img
            "$bin"/Kernel64Patcher "$dir"/$deviceid/$cpid/$version/NoMoreSIGABRT.img "$dir"/$deviceid/$cpid/$version/NoMoreSIGABRT.patched -n
            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/$cpid/$version/NoMoreSIGABRT.patched root@localhost:/mnt1/out.img
            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/bin/dd if=/mnt1/out.img of=/dev/disk0s1s2 bs=512 count=8192'
            echo "[*] Done"
            $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
            _kill_if_running iproxy
            exit 0
        elif [[ "$fix_activation" == 1 ]]; then
            if [[ "$version" == "9.3"* || "$version" == "10.0"* || "$version" == "10.1"* || "$version" == "10.2"* ]]; then
                # /mnt2/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library/internal/data_ark.plist
                dataarkplist=$(remote_cmd "/usr/bin/find /mnt2/containers/Data/System -name 'internal'" 2> /dev/null)
                dataarkplist="$dataarkplist/data_ark.plist"
                echo $dataarkplist
                if [ -e "$dir"/$deviceid/0.0/IC-Info.sisv ]; then
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/"
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/IC-Info.sisv root@localhost:/mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv 2> /dev/null
                fi
                if [ -e "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist ]; then
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt2/wireless/Library/Preferences/"
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist root@localhost:/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist 2> /dev/null
                fi
                if [[ "$dataarkplist" == "/mnt2/containers/Data/System"* ]]; then
                    folder=$(echo $dataarkplist | sed 's/\/data_ark.plist//g')
                    # /mnt2/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library/internal
                    if [[ "$folder" == "/mnt2/containers/Data/System"* ]]; then
                        if [ -e "$dir"/$deviceid/0.0/activation_records ]; then
                            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p $folder/activation_records"
                            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/activation_records root@localhost:$folder 2> /dev/null
                            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg $folder/activation_records"
                        fi
                    fi
                fi
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/data_ark.plis_ root@localhost:$dataarkplist
            else
                # /mnt5/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library/internal/data_ark.plist
                dataarkplist=$(remote_cmd "/usr/bin/find /mnt5/containers/Data/System -name 'data_ark.plist'" 2> /dev/null)
                echo $dataarkplist
                if [ -e "$dir"/$deviceid/0.0/IC-Info.sisv ]; then
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/mobile/Library/FairPlay/iTunes_Control/iTunes/"
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/IC-Info.sisv root@localhost:/mnt5/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv 2> /dev/null
                fi
                if [ -e "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist ]; then
                    "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt5/wireless/Library/Preferences/"
                    "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/$deviceid/0.0/com.apple.commcenter.device_specific_nobackup.plist root@localhost:/mnt5/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist 2> /dev/null
                fi
                if [[ "$dataarkplist" == "/mnt5/containers/Data/System"* ]]; then
                    folder=$(echo $dataarkplist | sed 's/\/data_ark.plist//g')
                    # /mnt5/containers/Data/System/58954F59-3AA2-4005-9C5B-172BE4ADEC98/Library/internal
                    if [[ "$folder" == "/mnt5/containers/Data/System"* ]]; then
                        if [ -e "$dir"/$deviceid/0.0/activation_records ]; then
                            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p $folder/activation_records"
                            "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -r -P 2222 "$dir"/$deviceid/0.0/activation_records root@localhost:$folder 2> /dev/null
                            "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/chflags -R schg $folder/activation_records"
                        fi
                    fi
                fi
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/data_ark.plis_ root@localhost:$dataarkplist
            fi
            if [[ "$version" == "10.3"* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/Meridian.app.tar root@localhost:/mnt4/
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt4/Meridian.app.tar -C /mnt4/Applications' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/Meridian.app.tar' 2> /dev/null
            elif [[ "$version" == "10."* ]]; then
                "$bin"/sshpass -p "alpine" scp -o StrictHostKeyChecking=no -P 2222 "$dir"/jb/Meridian.app.tar root@localhost:/mnt1/
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt1/Meridian.app.tar -C /mnt1/Applications' 2> /dev/null
                "$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/Meridian.app.tar' 2> /dev/null
            fi
            $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
            _kill_if_running iproxy
            echo "done"
            exit 0
        fi
        ssh -o StrictHostKeyChecking=no -p2222 root@localhost
        $("$bin"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" 2> /dev/null &)
        _kill_if_running iproxy
    fi
fi
} | tee logs/"$(date +%T)"-"$(date +%F)"-"$(uname)"-"$(uname -r)".log
