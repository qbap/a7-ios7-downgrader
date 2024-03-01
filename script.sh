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
_download_ramdisk_boot_files() {
    # $deviceid arg 1
    # $replace arg 2
    # $version arg 3
    
    ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'$3'")' | ./jq -s '.[0] | .url' --raw-output)

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

    rm -rf BuildManifest.plist

    mkdir -p ramdisk

    ./pzb -g BuildManifest.plist "$ipswurl"

    if [ ! -e ramdisk/kernelcache.dec ]; then
        # Download kernelcache
        ./pzb -g $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) "$ipswurl"
        # Decrypt kernelcache
        # note that as per src/decrypt.rs it will not rename the file
        cargo run decrypt $1 $3 $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) -l
        # so we shall rename the file ourselves
        mv $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1).dec ramdisk/kcache.raw
        mv $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1).im4p ramdisk/kernelcache.dec
    fi

    if [ ! -e ramdisk/iBSS.dec ]; then
        # Download iBSS
        ./pzb -g $(awk "/""$2""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
        # Decrypt iBSS
        cargo run decrypt $1 $3 $(awk "/""$2""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//') -l
        mv $(awk "/""$2""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//').dec ramdisk/iBSS.dec
    fi

    if [ ! -e ramdisk/iBEC.dec ]; then
        # Download iBEC
        ./pzb -g $(awk "/""$2""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
        # Decrypt iBEC
        cargo run decrypt $1 $3 $(awk "/""$2""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//') -l
        mv $(awk "/""$2""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//').dec ramdisk/iBEC.dec
    fi

    if [ ! -e ramdisk/DeviceTree.dec ]; then
        # Download DeviceTree
        ./pzb -g $(awk "/""$2""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
        # Decrypt DeviceTree
        cargo run decrypt $1 $3 $(awk "/""$2""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash.*production[/]//') -l
        mv $(awk "/""$2""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash.*production[/]//').dec ramdisk/DeviceTree.dec
    fi

    if [ ! -e ramdisk/RestoreRamDisk.dmg ]; then
        # Download RestoreRamDisk
        ./pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
        # Decrypt RestoreRamDisk
        cargo run decrypt $1 $3 "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -l
        mv "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".dec ramdisk/RestoreRamDisk.dmg
    fi
    
    rm -rf BuildManifest.plist
    
    # we need to download restore ramdisk for ios 8.4.1
    # in this example we are using a modified copy of the ssh tar from SSHRD_Script https://github.com/verygenericname/SSHRD_Script
    # this modified copy of the ssh tar fixes a few issues on ios 8 and adds some executables we need
    if [ ! -e ramdisk/ramdisk.img4 ]; then
        hdiutil resize -size 60M ramdisk/RestoreRamDisk.dmg
        hdiutil attach -mountpoint /tmp/ramdisk ramdisk/RestoreRamDisk.dmg
        sudo diskutil enableOwnership /tmp/ramdisk
        sudo ./gnutar -xvf iram.tar -C /tmp/ramdisk
        hdiutil detach /tmp/ramdisk
        ./img4tool -c ramdisk/ramdisk.im4p -t rdsk ramdisk/RestoreRamDisk.dmg
        ./img4tool -c ramdisk/ramdisk.img4 -p ramdisk/ramdisk.im4p -m IM4M
        ./ipatcher ramdisk/iBSS.dec ramdisk/iBSS.patched
        ./ipatcher ramdisk/iBEC.dec ramdisk/iBEC.patched -b "amfi=0xff cs_enforcement_disable=1 -v rd=md0 nand-enable-reformat=1 -progress"
        ./img4 -i ramdisk/iBSS.patched -o ramdisk/iBSS.img4 -M IM4M -A -T ibss
        ./img4 -i ramdisk/iBEC.patched -o ramdisk/iBEC.img4 -M IM4M -A -T ibec
        ./img4 -i ramdisk/kernelcache.dec -o ramdisk/kernelcache.img4 -M IM4M -T rkrn
        ./img4 -i ramdisk/devicetree.dec -o ramdisk/devicetree.img4 -A -M IM4M -T rdtr
    fi
}
_download_boot_files() {
    # $deviceid arg 1
    # $replace arg 2
    # $version arg 3

    ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'$3'")' | ./jq -s '.[0] | .url' --raw-output)

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

    rm -rf BuildManifest.plist

    mkdir -p $1/$3

    ./pzb -g BuildManifest.plist "$ipswurl"

    if [ ! -e $1/$3/kernelcache.dec ]; then
        # Download kernelcache
        ./pzb -g $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) "$ipswurl"
        # Decrypt kernelcache
        # note that as per src/decrypt.rs it will not rename the file
        cargo run decrypt $1 $3 $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1) -l
        # so we shall rename the file ourselves
        mv $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1).dec $1/$3/kcache.raw
        mv $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1).im4p $1/$3/kernelcache.dec
        mv $(awk "/""$2""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1).kpp $1/$3/kpp.bin
    fi

    if [ ! -e $1/$3/iBSS.dec ]; then
        # Download iBSS
        ./pzb -g $(awk "/""$2""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
        # Decrypt iBSS
        cargo run decrypt $1 $3 $(awk "/""$2""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//') -l
        mv $(awk "/""$2""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//').dec $1/$3/iBSS.dec
    fi

    if [ ! -e $1/$3/iBEC.dec ]; then
        # Download iBEC
        ./pzb -g $(awk "/""$2""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
        # Decrypt iBEC
        cargo run decrypt $1 $3 $(awk "/""$2""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//') -l
        mv $(awk "/""$2""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//').dec $1/$3/iBEC.dec
    fi

    if [ ! -e $1/$3/DeviceTree.dec ]; then
        # Download DeviceTree
        ./pzb -g $(awk "/""$2""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1) "$ipswurl"
        # Decrypt DeviceTree
        cargo run decrypt $1 $3 $(awk "/""$2""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash.*production[/]//') -l
        mv $(awk "/""$2""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash.*production[/]//').dec $1/$3/DeviceTree.dec
    fi

    if [ ! -e $1/$3/RestoreRamDisk.dmg ]; then
        # Download RestoreRamDisk
        ./pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
        # Decrypt RestoreRamDisk
        cargo run decrypt $1 $3 "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -l
        mv "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".dec $1/$3/RestoreRamDisk.dmg
    fi
    
    rm -rf BuildManifest.plist
    
    if [ ! -e $1/$3/iBSS.patched ]; then    
        if [[ "$3" == *"9"* ]]; then
            ./iBoot64Patcher $1/$3/iBSS.dec $1/$3/iBSS.patched
            ./iBoot64Patcher $1/$3/iBEC.dec $1/$3/iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1 PE_i_can_has_debugger=1  amfi_unrestrict_task_for_pid=0x0 amfi_allow_any_signature=0x1 amfi_get_out_of_my_way=0x1"
        else
            ./ipatcher $1/$3/iBSS.dec $1/$3/iBSS.patched
            ./ipatcher $1/$3/iBEC.dec $1/$3/iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1 PE_i_can_has_debugger=1"
        fi
        if [[ "$3" == *"8"* ]]; then
            ./img4 -i $1/$3/iBSS.patched -o $1/$3/iBSS.img4 -M IM4M -A -T ibss
            ./img4 -i $1/$3/iBEC.patched -o $1/$3/iBEC.img4 -M IM4M -A -T ibec
            ./seprmvr64lite jb/12A4297e_kcache.raw $1/$3/kcache.patched
            ./Kernel64Patcher $1/$3/kcache.patched $1/$3/kcache2.patched -m -e -s -b -a
            ./kerneldiff jb/12A4297e_kcache.raw $1/$3/kcache2.patched $1/$3/kc.bpatch
            ./img4 -i jb/12A4297e_kernelcache.dec -o $1/$3/kernelcache.img4 -M IM4M -T rkrn -P $1/$3/kc.bpatch
            ./img4 -i jb/12A4297e_kernelcache.dec -o $1/$3/kernelcache -M IM4M -T krnl -P $1/$3/kc.bpatch
        elif [[ "$3" == *"9"* ]]; then
            ./img4 -i $1/$3/iBSS.patched -o $1/$3/iBSS.img4 -M IM4M -A -T ibss
            ./img4 -i $1/$3/iBEC.patched -o $1/$3/iBEC.img4 -M IM4M -A -T ibec
            ./seprmvr64lite $1/$3/kcache.raw $1/$3/kcache.patched
            # we need to apply mount_common patch for rootfs rw and vm_map_enter patch for tweak injection
            ./Kernel64Patcher $1/$3/kcache.patched $1/$3/kcache2.patched -m -e -s -b
            #./Kernel64Patcher_2 $1/$3/kcache2.patched $1/$3/kcache3.patched -f
            cp $1/$3/kcache2.patched $1/$3/kcache3.patched
            pyimg4 im4p create -i $1/$3/kcache3.patched -o $1/$3/kernelcache.im4p.img4 --extra $1/$3/kpp.bin -f rkrn --lzss
            pyimg4 im4p create -i $1/$3/kcache3.patched -o $1/$3/kernelcache.im4p --extra $1/$3/kpp.bin -f krnl --lzss
            pyimg4 img4 create -p $1/$3/kernelcache.im4p.img4 -o $1/$3/kernelcache.img4 -m IM4M
            pyimg4 img4 create -p $1/$3/kernelcache.im4p -o $1/$3/kernelcache -m IM4M
        elif [[ "$3" == *"7"* ]]; then
            ./img4 -i $1/$3/iBSS.patched -o $1/$3/iBSS.img4 -M IM4M -A -T ibss
            ./img4 -i $1/$3/iBEC.patched -o $1/$3/iBEC.img4 -M IM4M -A -T ibec
            ./seprmvr64lite $1/$3/kcache.raw $1/$3/kcache.patched
            # we need to apply mount_common patch for rootfs rw and vm_map_enter patch for tweak injection
            ./Kernel64Patcher $1/$3/kcache.patched $1/$3/kcache2.patched -m -e
            ./Kernel64Patcher_2 $1/$3/kcache2.patched $1/$3/kcache3.patched -f
            ./kerneldiff $1/$3/kcache.raw $1/$3/kcache3.patched $1/$3/kc.bpatch
            ./img4 -i $1/$3/kernelcache.dec -o $1/$3/kernelcache.img4 -M IM4M -T rkrn -P $1/$3/kc.bpatch
            ./img4 -i $1/$3/kernelcache.dec -o $1/$3/kernelcache -M IM4M -T krnl -P $1/$3/kc.bpatch
        fi
        ./dtree_patcher $1/$3/DeviceTree.dec $1/$3/DeviceTree.patched -n
        ./img4 -i $1/$3/DeviceTree.patched -o $1/$3/devicetree.img4 -A -M IM4M -T rdtr
    fi
}
_download_root_fs() {
    # $deviceid arg 1
    # $replace arg 2
    # $version arg 3

    ipswurl=$(curl -k -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | ./jq '.firmwares | .[] | select(.version=="'$3'")' | ./jq -s '.[0] | .url' --raw-output)

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

    rm -rf BuildManifest.plist

    mkdir -p $1/$3

    ./pzb -g BuildManifest.plist "$ipswurl"
    
    if [ ! -e $1/$3/OS.tar ]; then
        if [ ! -e $1/$3/OS.dmg ]; then
            if [[ "$3" == "8.0" ]]; then
                # https://archive.org/download/Apple_iPhone_Firmware/Apple%20iPhone%206.1%20Firmware%208.0%20(8.0.12A4297e)%20(beta2)/
                ./aria2c https://ia903400.us.archive.org/4/items/Apple_iPhone_Firmware/Apple%20iPhone%206.1%20Firmware%208.0%20%288.0.12A4297e%29%20%28beta2%29/media_ipsw.rar
                mv media_ipsw.rar $1/$3/media_ipsw.rar
                cd ./$1/$3
                ../../7z x media_ipsw.rar
                ../../7z x $(find . -name '*.ipsw*')
                ../../dmg extract 058-01244-038.dmg OS.dmg -k 45f6fbb943e0b9079ae340662e0c408e73c9e0c9bffefef04a8acb89691558660ca75942
                cd ../../
            else
                # Download root fs
                ./pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
                # Decrypt root fs
                # note that as per src/decrypt.rs it will rename the file to OS.dmg by default
                cargo run decrypt $1 $3 "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -l
                osfn="$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)"
                mv $(echo $osfn | sed "s/dmg/bin/g") $1/$3/OS.dmg
            fi
        fi
        ./dmg build $1/$3/OS.dmg $1/$3/rw.dmg
        hdiutil attach -mountpoint /tmp/ios $1/$3/rw.dmg
        sudo diskutil enableOwnership /tmp/ios
        sudo mkdir /tmp/ios2
        sudo rm -rf /tmp/ios2
        sudo cp -a /tmp/ios/. /tmp/ios2/
        sudo tar -xvf ./jb/cydia.tar -C /tmp/ios2
        sudo ./gnutar -cvf $1/$3/OS.tar -C /tmp/ios2 .
        hdiutil detach /tmp/ios
        rm -rf /tmp/ios
        sudo rm -rf /tmp/ios2
        ./irecovery -f /dev/null
    fi

    rm -rf BuildManifest.plist
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

for cmd in curl cargo ssh scp killall sudo grep; do
    if ! command -v "${cmd}" > /dev/null; then
        if [ "$cmd" = "cargo" ]; then
            echo "[-] Command '${cmd}' not installed, please install it!";
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
            exit
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
cargo install taco
cargo run
if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
    ./dfuhelper.sh
fi
_wait_for_dfu
check=$(./irecovery -q | grep CPID | sed 's/CPID: //')
replace=$(./irecovery -q | grep MODEL | sed 's/MODEL: //')
deviceid=$(./irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
echo $deviceid
# we need a shsh file that we can use in order to boot the ios 8 ramdisk
# in this case we are going to use the ones from SSHRD_Script https://github.com/verygenericname/SSHRD_Script
./img4tool -e -s other/shsh/"${check}".shsh -m IM4M
_download_ramdisk_boot_files $deviceid $replace 8.4.1
_download_boot_files $deviceid $replace $1
_download_root_fs $deviceid $replace $1
if [ -e $deviceid/$1/iBSS.img4 ]; then
    read -p "would you like to skip the ramdisk and boot ios $1? " r
    if [[ "$r" = 'yes' || "$r" = 'y' ]]; then
        # if we already have installed ios using this script we can just boot the existing kernelcache
        _wait_for_dfu
        cd $deviceid/$1
        ../../ipwnder -p
        ../../irecovery -f iBSS.img4
        ../../irecovery -f iBSS.img4
        ../../irecovery -f iBEC.img4
        ../../irecovery -f devicetree.img4
        ../../irecovery -c devicetree
        ../../irecovery -f kernelcache.img4
        ../../irecovery -c bootx &
        cd ../../
        exit
    fi
fi
if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
    ./dfuhelper.sh
fi
_wait_for_dfu
cd ramdisk
../ipwnder -p
../irecovery -f iBSS.img4
../irecovery -f iBSS.img4
../irecovery -f iBEC.img4
../irecovery -f ramdisk.img4
../irecovery -c ramdisk
../irecovery -f devicetree.img4
../irecovery -c devicetree
../irecovery -f kernelcache.img4
../irecovery -c bootx &
cd ..
read -p "pls press the enter key once device is in the ramdisk " r
./iproxy 2222 22 &
sleep 2
read -p "would you like to wipe this phone and install ios $1? " r
if [[ "$r" = 'yes' || "$r" = 'y' ]]; then
    if [ ! -e apticket.der ]; then
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -t hfs -o ro,nosuid,nodev /dev/disk0s1s2 /mnt2"
        ./sshpass -p "alpine" scp -P 2222 root@localhost:/mnt1/System/Library/Caches/apticket.der ./apticket.der
        ./sshpass -p "alpine" scp -P 2222 root@localhost:/mnt1/usr/standalone/firmware/sep-firmware.img4 ./sep-firmware.img4
        ./sshpass -p "alpine" scp -r -P 2222 root@localhost:/mnt1/usr/local/standalone/firmware/Baseband ./Baseband
        ./sshpass -p "alpine" scp -r -P 2222 root@localhost:/mnt2/keybags ./keybags
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt1"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/umount /mnt2"
    fi
    if [ ! -e apticket.der ]; then
        echo "missing ./apticket.der, which is required in order to proceed. exiting.."
        exit
    fi
    if [ ! -e sep-firmware.img4 ]; then
        echo "missing ./sep-firmware.img4, which is required in order to proceed. exiting.."
        exit
    fi
    if [ ! -e Baseband ]; then
        echo "missing ./Baseband, which is required in order to proceed. exiting.."
        exit
    fi
    if [ ! -e keybags ]; then
        echo "missing ./keybags, which is required in order to proceed. exiting.."
        exit
    fi
    # this command erases the nand so we can create new partitions
    remote_cmd "lwvm init"
    sleep 2
    $(./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" &)
    _kill_if_running iproxy
    echo "device should now reboot into recovery, pls wait"
    echo "once in recovery you should follow instructions online to go back into dfu"
    if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
        ./dfuhelper.sh
    fi
    _wait_for_dfu
    cd ramdisk
    ../ipwnder -p
    ../irecovery -f iBSS.img4
    ../irecovery -f iBSS.img4
    ../irecovery -f iBEC.img4
    ../irecovery -f ramdisk.img4
    ../irecovery -c ramdisk
    ../irecovery -f devicetree.img4
    ../irecovery -c devicetree
    ../irecovery -f kernelcache.img4
    ../irecovery -c bootx &
    cd ..
    read -p "pls press the enter key once device is in the ramdisk" r
    ./iproxy 2222 22 &
    echo "https://ios7.iarchive.app/downgrade/installing-filesystem.html"
    echo "partition 1"
    echo "step 1, press the letter n on your keyboard and then press enter"
    echo "step 2, press number 1 on your keyboard and press enter"
    echo "step 3, press enter again"
    if [[ "$1" == *"9"* ]]; then
        echo "step 4, type 1264563 and then press enter"
    elif [[ "$1" == *"8"* ]]; then
        echo "step 4, type 1264563 and then press enter"
    else
        echo "step 4, type 864563 and then press enter"
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
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs -o suid,dev /dev/disk0s1s2 /mnt2"
    scp -P 2222 ./$deviceid/$1/OS.tar root@localhost:/mnt2
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/OS.tar -C /mnt1"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv -v /mnt1/private/var/* /mnt2"
    # very important
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir -p /mnt1/usr/local/standalone/firmware/Baseband"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir /mnt2/keybags"
    ./sshpass -p "alpine" scp -r -P 2222 ./Baseband root@localhost:/mnt1/usr/local/standalone/firmware
    ./sshpass -p "alpine" scp -P 2222 ./apticket.der root@localhost:/mnt1/System/Library/Caches/
    ./sshpass -p "alpine" scp -P 2222 ./sep-firmware.img4 root@localhost:/mnt1/usr/standalone/firmware/
    if [[ "$1" == *"9"* ]]; then
        ./sshpass -p "alpine" scp -r -P 2222 ./keybags root@localhost:/mnt2
        ./sshpass -p "alpine" scp -P 2222 ./fstab root@localhost:/mnt1/etc/
    else
        ./sshpass -p "alpine" scp -r -P 2222 ./keybags root@localhost:/mnt2
        ./sshpass -p "alpine" scp -P 2222 ./jb/fstab root@localhost:/mnt1/etc/
    fi
    #./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/Applications/PreBoard.app"
    read -p "would you like to also delete Setup.app? " r
    if [[ "$r" = 'yes' || "$r" = 'y' ]]; then
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/Applications/Setup.app"
        if [[ "$1" == *"9"* || "$1" == *"8"* ]]; then
            read -p "would you like to install data_ark.plist to /var? " r
            if [[ "$r" = 'yes' || "$r" = 'y' ]]; then
                ./sshpass -p "alpine" scp -P 2222 ./data_ark.plist.tar root@localhost:/mnt2/
                ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist.tar -C /mnt2"
            fi
        else
            ./sshpass -p "alpine" scp -P 2222 ./data_ark.plist.tar root@localhost:/mnt2/
            ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist.tar -C /mnt2"
        fi
    fi
    ./sshpass -p "alpine" scp -P 2222 ./jb/com.saurik.Cydia.Startup.plist root@localhost:/mnt1/System/Library/LaunchDaemons
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown root:wheel /mnt1/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/OS.tar"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/log/asl/SweepStore"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/Library/PreinstalledAssets/*"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/Library/Preferences/.GlobalPreferences.plist"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/.forward"
    if [[ "$1" == *"9"* || "$1" == *"8"* ]]; then
        # these plists should in theory trick ios into thinking we already migrated& went thru Setup.app
        ./sshpass -p "alpine" scp -P 2222 ./jb/com.apple.purplebuddy.plist root@localhost:/mnt2/mobile/Library/Preferences/
        ./sshpass -p "alpine" scp -P 2222 ./jb/com.apple.purplebuddy.notbackedup.plist root@localhost:/mnt2/mobile/Library/Preferences/
        ./sshpass -p "alpine" scp -P 2222 ./jb/com.apple.migration.plist root@localhost:/mnt2/mobile/Library/Preferences/
    fi
    if [[ "$1" == *"8"* ]]; then
        ./sshpass -p "alpine" scp -P 2222 ./jb/untether.tar root@localhost:/mnt1/
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt1/untether.tar -C /mnt1/'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'mv /mnt1/usr/libexec/CrashHousekeeping /mnt1/usr/libexec/CrashHousekeeping_o'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'cd /mnt1/usr/libexec/ && ln -s ../../wtfis/untether CrashHousekeeping'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/.installed_wtfis"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chown root:wheel /mnt1/.installed_wtfis"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt1/.installed_wtfis"
    fi
    ./sshpass -p "alpine" scp -P 2222 ./$deviceid/$1/kernelcache root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches
    # stashing on ios 8 not only causes apps to break, but it also breaks your wifi loll
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/.cydia_no_stash"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chown root:wheel /mnt1/.cydia_no_stash"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt1/.cydia_no_stash"
    if [[ "$1" == *"7"* ]]; then
        ./sshpass -p "alpine" scp -P 2222 ./jb/AppleInternal.tar root@localhost:/mnt1/
        ./sshpass -p "alpine" scp -P 2222 ./jb/PrototypeTools.framework.tar root@localhost:/mnt1/
        ./sshpass -p "alpine" scp -P 2222 ./jb/SystemVersion.plist root@localhost:/mnt1/System/Library/CoreServices/SystemVersion.plist
        ./sshpass -p "alpine" scp -P 2222 ./jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en.lproj/
        ./sshpass -p "alpine" scp -P 2222 ./jb/SpringBoard-Internal.strings root@localhost:/mnt1/System/Library/CoreServices/SpringBoard.app/en_GB.lproj/
        ./sshpass -p "alpine" scp -P 2222 ./jb/com.apple.springboard.plist root@localhost:/mnt2/mobile/Library/Preferences/com.apple.springboard.plist
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/PrototypeTools.framework.tar -C /mnt1/System/Library/PrivateFrameworks/'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/System/Library/PrivateFrameworks/PrototypeTools.framework'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/PrototypeTools.framework.tar'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar -xvf /mnt1/AppleInternal.tar -C /mnt1/'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/usr/sbin/chown -R root:wheel /mnt1/AppleInternal/'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt1/AppleInternal.tar'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt2/mobile/Library/Caches/com.apple.MobileGestalt.plist'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plist /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plis_"
    #elif [[ "$1" == *"9"* ]]; then
        #./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/sbin/umount /mnt2'
        #./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/bin/dd if=/dev/disk0s1s2 of=/mnt1/out.img bs=512 count=8192'
        #./sshpass -p "alpine" scp -P 2222 root@localhost:/mnt1/out.img ./$deviceid/$1/NoMoreSIGABRT.img
        #./Kernel64Patcher ./$deviceid/$1/NoMoreSIGABRT.img ./$deviceid/$1/NoMoreSIGABRT.patched -n
        #./sshpass -p "alpine" scp -P 2222 ./$deviceid/$1/NoMoreSIGABRT.patched root@localhost:/mnt1/out.img
        #./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost '/bin/dd if=/mnt1/out.img of=/dev/disk0s1s2 bs=512 count=8192'
    fi
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/usr/lib/libmis.dylib"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram oblit-inprogress=5"
    $(./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" &)
    if [ -e $deviceid/$1/iBSS.img4 ]; then
        if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
            ./dfuhelper.sh
        fi
        _wait_for_dfu
        cd $deviceid/$1
        ../../ipwnder -p
        ../../irecovery -f iBSS.img4
        ../../irecovery -f iBSS.img4
        ../../irecovery -f iBEC.img4
        ../../irecovery -f devicetree.img4
        ../../irecovery -c devicetree
        ../../irecovery -f kernelcache.img4
        ../../irecovery -c bootx &
        cd ../../
    fi
    _kill_if_running iproxy
    echo "done"
    exit
else
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1"
    if [[ "$1" == *"7"* ]]; then
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs -o suid,dev /dev/disk0s1s2 /mnt2"
        ./sshpass -p "alpine" scp -P 2222 ./$deviceid/$1/kernelcache root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plist /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plis_"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/System/Library/Caches/com.apple.dyld/enable-dylibs-to-override-cache"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/.cydia_no_stash"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chown root:wheel /mnt1/.cydia_no_stash"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt1/.cydia_no_stash"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm /mnt1/Applications'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'mv $(find /mnt2/stash -name Applications) /mnt1/'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm /mnt1/Library/Ringtones'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'mv $(find /mnt2/stash -name Ringtones) /mnt1/Library'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm /mnt1/Library/Wallpaper'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'mv $(find /mnt2/stash -name Wallpaper) /mnt1/Library'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm /mnt1/usr/lib/pam'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'mv $(find /mnt2/stash -name pam) /mnt1/usr/lib'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm /mnt1/usr/include'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'mv $(find /mnt2/stash -name include) /mnt1/usr/'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm /mnt1/usr/share'
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'mv $(find /mnt2/stash -name share) /mnt1/usr/'
        ./sshpass -p "alpine" scp -P 2222 ./jb/fstab root@localhost:/mnt1/etc/
         read -p "would you like to also delete Setup.app? " r
        if [[ "$r" = 'yes' || "$r" = 'y' ]]; then
            ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/Applications/Setup.app"
            ./sshpass -p "alpine" scp -P 2222 ./data_ark.plist.tar root@localhost:/mnt2/
            ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist.tar -C /mnt2"
        fi
    #for ios 8 and up it is critical to not ever mount /mnt2 as rw from ssh ever again after first mount
    #you can however mount /mnt2 as read only on ios 8 and up with the commented out command listed below
    #else
        #./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -t hfs -o suid,dev /dev/disk0s1s2 /mnt2"
    fi
    ssh -p2222 root@localhost
    $(./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" &)
fi
if [ -e $deviceid/$1/iBSS.img4 ]; then
    if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
        ./dfuhelper.sh
    fi    
    _wait_for_dfu
     cd $deviceid/$1
    ../../ipwnder -p
    ../../irecovery -f iBSS.img4
    ../../irecovery -f iBSS.img4
    ../../irecovery -f iBEC.img4
    ../../irecovery -f devicetree.img4
    ../../irecovery -c devicetree
    ../../irecovery -f kernelcache.img4
    ../../irecovery -c bootx &
    cd ../../
    exit
fi
