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
_download_boot_files_jb() {
    # $deviceid arg 1
    # $replace arg 2
    # $version arg 3
    
    mkdir -p $1/$3

    if [ "$1" = "iPhone6,1" ]; then
        ipswurl="https://secure-appldnld.apple.com/iOS7/091-9500.20130918.bgy5t/iphone6,1_7.0_11a466_restore.ipsw"
        if [ ! -e $1/$3/kernelcache.dec ]; then
            ./pzb -g Firmware/dfu/iBSS.n51ap.RELEASE.im4p "$ipswurl"
            ./pzb -g Firmware/dfu/iBEC.n51ap.RELEASE.im4p "$ipswurl"
            ./pzb -g kernelcache.release.n51 "$ipswurl"
            ./pzb -g Firmware/all_flash/all_flash.n51ap.production/DeviceTree.n51ap.im4p "$ipswurl"
            mv iBSS.n51ap.RELEASE.im4p $1/$3/iBSS.n51ap.RELEASE.im4p
            mv iBEC.n51ap.RELEASE.im4p $1/$3/iBEC.n51ap.RELEASE.im4p
            mv kernelcache.release.n51 $1/$3/kernelcache.release.n51
            mv DeviceTree.n51ap.im4p $1/$3/DeviceTree.n51ap.im4p
            ./img4 -i $1/$3/iBSS.n51ap.RELEASE.im4p -o $1/$3/iBSS.dec -k 7e90fe7330257620f0213dff247d9f28e6bbba5ec2868c369e47cd47e75f1d352f20228c0bee22a756b9a934cec1b584
            ./img4 -i $1/$3/iBEC.n51ap.RELEASE.im4p -o $1/$3/iBEC.dec -k 230c1b4044e61af6f4039dd506e0a4fcff2ebe36b5cad824a68560cc8e351d37d17fc5356564dc493f80d339ce982964
            ./ipatcher $1/$3/iBSS.dec $1/$3/iBSS.patched
            ./ipatcher $1/$3/iBEC.dec $1/$3/iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1 PE_i_can_has_debugger=1"
            ./img4 -i $1/$3/iBSS.patched -o $1/$3/iBSS.img4 -M IM4M -A -T ibss
            ./img4 -i $1/$3/iBEC.patched -o $1/$3/iBEC.img4 -M IM4M -A -T ibec
            ./img4 -i $1/$3/kernelcache.release.n51 -o $1/$3/kernelcache.dec -k 1f002ce72b2bd39660ed5c5efb9bcd22d32e8ec93e2f53ebf5a6a3089b4a7575e41c5846803c5f374a734d5711e537b5 -D
            ./img4 -i $1/$3/kernelcache.release.n51 -o $1/$3/kcache.raw -k 1f002ce72b2bd39660ed5c5efb9bcd22d32e8ec93e2f53ebf5a6a3089b4a7575e41c5846803c5f374a734d5711e537b5
            ./seprmvr64lite jb/11A24581c_kcache.raw $1/$3/kcache.patched
            ./kerneldiff jb/11A24581c_kcache.raw $1/$3/kcache.patched $1/$3/kc.bpatch
            ./img4 -i jb/11A24581c_kernelcache.dec -o $1/$3/kernelcache.img4 -M IM4M -T rkrn -P $1/$3/kc.bpatch
            ./img4 -i jb/11A24581c_kernelcache.dec -o $1/$3/kernelcache -M IM4M -T krnl -P $1/$3/kc.bpatch
            ./img4 -i $1/$3/DeviceTree.n51ap.im4p -o $1/$3/dtree.raw -k a0c6cda2b9735cd54d394b7f3d6f51c6f23becd34081751134cc8d1bbcf7eb1bcfa5993c612007aecb0b27de05ae6ee8
            ./img4 -i $1/$3/dtree.raw -o $1/$3/devicetree.img4 -A -M IM4M -T rdtr
        fi
    elif [ "$1" = "iPhone6,2" ]; then
        ipswurl="https://secure-appldnld.apple.com/iOS7/091-9498.20130918.lllkt/iphone6,2_7.0_11a466_restore.ipsw"
        if [ ! -e $1/$3/kernelcache.dec ]; then
            ./pzb -g Firmware/dfu/iBSS.n53ap.RELEASE.im4p "$ipswurl"
            ./pzb -g Firmware/dfu/iBEC.n53ap.RELEASE.im4p "$ipswurl"
            ./pzb -g kernelcache.release.n53 "$ipswurl"
            ./pzb -g Firmware/all_flash/all_flash.n53ap.production/DeviceTree.n53ap.im4p "$ipswurl"
            mv iBSS.n53ap.RELEASE.im4p $1/$3/iBSS.n53ap.RELEASE.im4p
            mv iBEC.n53ap.RELEASE.im4p $1/$3/iBEC.n53ap.RELEASE.im4p
            mv kernelcache.release.n53 $1/$3/kernelcache.release.n53
            mv DeviceTree.n53ap.im4p $1/$3/DeviceTree.n53ap.im4p
            ./img4 -i $1/$3/iBSS.n53ap.RELEASE.im4p -o $1/$3/iBSS.dec -k b44f3bcd69620c181a8783ca5bfc60b0fefac2548bf1855b97a8b9569e31c87e175c5ee4d21c073a19d23ce3df6cee90
            ./img4 -i $1/$3/iBEC.n53ap.RELEASE.im4p -o $1/$3/iBEC.dec -k e08ff10d31b4c68673aabf5a2c22ce3cd41927285caaac1659ccf11cbd4c081948aeaf014497e6f8cdf77a371782879c
            ./ipatcher $1/$3/iBSS.dec $1/$3/iBSS.patched
            ./ipatcher $1/$3/iBEC.dec $1/$3/iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1 PE_i_can_has_debugger=1"
            ./img4 -i $1/$3/iBSS.patched -o $1/$3/iBSS.img4 -M IM4M -A -T ibss
            ./img4 -i $1/$3/iBEC.patched -o $1/$3/iBEC.img4 -M IM4M -A -T ibec
            ./img4 -i $1/$3/kernelcache.release.n53 -o $1/$3/kernelcache.dec -k 2af87a1af1b954ea84b24384e35d96d87434e7f374f5366a6f25814a0ea04a0865e9b1348f1885816adfdab84cfe6b4b -D
            ./img4 -i $1/$3/kernelcache.release.n53 -o $1/$3/kcache.raw -k 2af87a1af1b954ea84b24384e35d96d87434e7f374f5366a6f25814a0ea04a0865e9b1348f1885816adfdab84cfe6b4b
            ./seprmvr64lite jb/11A24581c_kcache.raw $1/$3/kcache.patched
            ./kerneldiff jb/11A24581c_kcache.raw $1/$3/kcache.patched $1/$3/kc.bpatch
            ./img4 -i jb/11A24581c_kernelcache.dec -o $1/$3/kernelcache.img4 -M IM4M -T rkrn -P $1/$3/kc.bpatch
            ./img4 -i jb/11A24581c_kernelcache.dec -o $1/$3/kernelcache -M IM4M -T krnl -P $1/$3/kc.bpatch
            ./img4 -i $1/$3/DeviceTree.n53ap.im4p -o $1/$3/dtree.raw -k e556e32fe658e374e5fda8e0d0cd7d10fed7a316853e51005b9bcad9442a1a1432d2ddf04ec163279601b6aad982edca
            ./img4 -i $1/$3/dtree.raw -o $1/$3/devicetree.img4 -A -M IM4M -T rdtr
        fi
    fi
}
_download_root_fs_jb() {
    # $deviceid arg 1
    # $replace arg 2
    # $version arg 3
    
    mkdir -p $1/$3

    if [ "$1" = "iPhone6,1" ]; then
        ipswurl="https://secure-appldnld.apple.com/iOS7/091-9500.20130918.bgy5t/iphone6,1_7.0_11a466_restore.ipsw"
        if [ ! -e $1/$3/OS.tar ]; then
            ./pzb -g 038-4572-394.dmg "$ipswurl"
            mv 038-4572-394.dmg $1/$3/038-4572-394.dmg
            ./dmg extract $1/$3/038-4572-394.dmg $1/$3/OS.dmg -k 170dd7944f0583cb1356022c55de3c950bf97743eeee600cbe6c9586ad9b93dfeb27951f
            ./dmg build $1/$3/OS.dmg $1/$3/rw.dmg
            hdiutil attach -mountpoint /tmp/ios $1/$3/rw.dmg
            sudo diskutil enableOwnership /tmp/ios
            sudo mkdir /tmp/ios2
            sudo rm -rf /tmp/ios2
            sudo cp -a /tmp/ios/. /tmp/ios2/
            sudo tar --lzma -xvf ./jb/cydia.tar.lzma -C /tmp/ios2
            sudo ./gnutar -cvf $1/$3/OS.tar -C /tmp/ios2 .
            hdiutil detach /tmp/ios
            rm -rf /tmp/ios
            sudo rm -rf /tmp/ios2
        fi
    elif [ "$1" = "iPhone6,2" ]; then
        ipswurl="https://secure-appldnld.apple.com/iOS7/091-9498.20130918.lllkt/iphone6,2_7.0_11a466_restore.ipsw"
        if [ ! -e $1/$3/OS.tar ]; then
            ./pzb -g 038-6622-334.dmg "$ipswurl"
            mv 038-6622-334.dmg $1/$3/038-6622-334.dmg
            ./dmg extract $1/$3/038-6622-334.dmg $1/$3/OS.dmg -k 9012b18043cab2fc9df516b71ac2f9f9403bfdb732fc99f01e73cbe0095635b5df92c9fb
            ./dmg build $1/$3/OS.dmg $1/$3/rw.dmg
            hdiutil attach -mountpoint /tmp/ios $1/$3/rw.dmg
            sudo diskutil enableOwnership /tmp/ios
            sudo mkdir /tmp/ios2
            sudo rm -rf /tmp/ios2
            sudo cp -a /tmp/ios/. /tmp/ios2/
            sudo tar --lzma -xvf ./jb/cydia.tar.lzma -C /tmp/ios2
            sudo ./gnutar -cvf $1/$3/OS.tar -C /tmp/ios2 .
            hdiutil detach /tmp/ios
            rm -rf /tmp/ios
            sudo rm -rf /tmp/ios2
        fi
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
        if [ "$3" = "7.0.2" ]; then
            if [ "$1" = "iPhone6,1" ]; then
                echo "ok"
            elif [ "$1" = "iPhone6,2" ]; then
                echo "ok"
            else
                echo "this version is not supported"
            fi
            ./ipatcher $1/$3/iBSS.dec $1/$3/iBSS.patched
            ./ipatcher $1/$3/iBEC.dec $1/$3/iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1 PE_i_can_has_debugger=1"
            ./img4 -i $1/$3/iBSS.patched -o $1/$3/iBSS.img4 -M IM4M -A -T ibss
            ./img4 -i $1/$3/iBEC.patched -o $1/$3/iBEC.img4 -M IM4M -A -T ibec
            ./seprmvr64lite jb/11A24580o_kcache.raw $1/$3/kcache.patched
            ./kerneldiff jb/11A24580o_kcache.raw $1/$3/kcache.patched $1/$3/kc.bpatch
            ./img4 -i jb/11A24580o_kernelcache.dec -o $1/$3/kernelcache.img4 -M IM4M -T rkrn -P $1/$3/kc.bpatch
            ./img4 -i jb/11A24580o_kernelcache.dec -o $1/$3/kernelcache -M IM4M -T krnl -P $1/$3/kc.bpatch
            ./seprmvr64lite $1/$3/kcache.raw $1/$3/kcache2.patched
            ./kerneldiff $1/$3/kcache.raw $1/$3/kcache2.patched $1/$3/kc2.bpatch
            ./img4 -i $1/$3/kernelcache.dec -o $1/$3/kernelcache2.img4 -M IM4M -T rkrn -P $1/$3/kc2.bpatch
            ./img4 -i $1/$3/kernelcache.dec -o $1/$3/kernelcache2 -M IM4M -T krnl -P $1/$3/kc2.bpatch
            ./img4 -i $1/$3/DeviceTree.dec -o $1/$3/devicetree.img4 -A -M IM4M -T rdtr
        else
            ./ipatcher $1/$3/iBSS.dec $1/$3/iBSS.patched
            ./ipatcher $1/$3/iBEC.dec $1/$3/iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1 PE_i_can_has_debugger=1"
            ./img4 -i $1/$3/iBSS.patched -o $1/$3/iBSS.img4 -M IM4M -A -T ibss
            ./img4 -i $1/$3/iBEC.patched -o $1/$3/iBEC.img4 -M IM4M -A -T ibec
            ./seprmvr64lite $1/$3/kcache.raw $1/$3/kcache.patched
            ./kerneldiff $1/$3/kcache.raw $1/$3/kcache.patched $1/$3/kc.bpatch
            ./img4 -i $1/$3/kernelcache.dec -o $1/$3/kernelcache.img4 -M IM4M -T rkrn -P $1/$3/kc.bpatch
            ./img4 -i $1/$3/kernelcache.dec -o $1/$3/kernelcache -M IM4M -T krnl -P $1/$3/kc.bpatch
            ./img4 -i $1/$3/DeviceTree.dec -o $1/$3/devicetree.img4 -A -M IM4M -T rdtr
        fi
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
        if [ "$3" = "7.0.2" ]; then
            if [ "$1" = "iPhone6,1" ]; then
                echo "ok"
            elif [ "$1" = "iPhone6,2" ]; then
                echo "ok"
            else
                echo "this version is not supported"
            fi
            # Download root fs
            ./pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
            # Decrypt root fs
            # note that as per src/decrypt.rs it will rename the file to OS.dmg by default
            cargo run decrypt $1 $3 "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -l
            osfn="$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)"
            mv $(echo $osfn | sed "s/dmg/bin/g") $1/$3/OS.dmg
            ./dmg build $1/$3/OS.dmg $1/$3/rw.dmg
            hdiutil attach -mountpoint /tmp/ios $1/$3/rw.dmg
            sudo diskutil enableOwnership /tmp/ios
            sudo mkdir /tmp/ios2
            sudo rm -rf /tmp/ios2
            sudo cp -a /tmp/ios/. /tmp/ios2/
            sudo tar --lzma -xvf ./jb/cydia.tar.lzma -C /tmp/ios2
            sudo ./gnutar -cvf $1/$3/OS.tar -C /tmp/ios2 .
            hdiutil detach /tmp/ios
            rm -rf /tmp/ios
            sudo rm -rf /tmp/ios2
            ./irecovery -f /dev/null
        else
            # Download root fs
            ./pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
            # Decrypt root fs
            # note that as per src/decrypt.rs it will rename the file to OS.dmg by default
            cargo run decrypt $1 $3 "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -l
            osfn="$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."OS"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)"
            mv $(echo $osfn | sed "s/dmg/bin/g") $1/$3/OS.dmg
            ./dmg build $1/$3/OS.dmg $1/$3/rw.dmg
            hdiutil attach -mountpoint /tmp/ios $1/$3/rw.dmg
            sudo diskutil enableOwnership /tmp/ios
            sudo ./gnutar -cvf $1/$3/OS.tar -C /tmp/ios .
            hdiutil detach /tmp/ios
            rm -rf /tmp/ios
            ./irecovery -f /dev/null
        fi
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
if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
    ./dfuhelper.sh
fi
_wait_for_dfu
check=$(./irecovery -q | grep CPID | sed 's/CPID: //')
replace=$(./irecovery -q | grep MODEL | sed 's/MODEL: //')
deviceid=$(./irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
echo $deviceid
if [ -e $deviceid/$1/iBSS.img4 ]; then
    read -p "would you like to skip the ramdisk and boot ios $1? " response76
    if [[ "$response76" = 'yes' || "$response76" = 'y' ]]; then
        # if we already have installed ios using this script we can just boot the existing kernelcache
        _wait_for_dfu
        cd $deviceid/$1
        ../../ipwnder -p
        ../../irecovery -f iBSS.img4
        ../../irecovery -f iBSS.img4
        ../../irecovery -f iBEC.img4
        ../../irecovery -f devicetree.img4
        ../../irecovery -c devicetree
        if [ "$1" = "7.0.2" ]; then
            read -p "would you like enable root fs r/w on ios $1? " response79
            if [[ "$response79" = 'yes' || "$response79" = 'y' ]]; then
                ../../irecovery -f kernelcache.img4
            else
                ../../irecovery -f kernelcache2.img4
            fi
        fi
        ../../irecovery -c bootx &
        cd ../../
        exit
    fi
fi
# we need a shsh file that we can use in order to boot the ios 8 ramdisk
# in this case we are going to use the ones from SSHRD_Script https://github.com/verygenericname/SSHRD_Script
./img4tool -e -s other/shsh/"${check}".shsh -m IM4M
_download_ramdisk_boot_files $deviceid $replace 8.4.1
if [ "$1" = "7.0" ]; then
    _download_boot_files_jb $deviceid $replace $1
    _download_root_fs_jb $deviceid $replace $1
else
    _download_boot_files $deviceid $replace $1
    _download_root_fs $deviceid $replace $1
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
read -p "pls press the enter key once device is in the ramdisk " pause1
./iproxy 2222 22 &
sleep 2
read -p "would you like to wipe this phone and install ios $1? " response1
if [[ "$response1" = 'yes' || "$response1" = 'y' ]]; then
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
    read -p "pls press the enter key once device is in the ramdisk" pause1
    ./iproxy 2222 22 &
    echo "https://ios7.iarchive.app/downgrade/installing-filesystem.html"
    echo "partition 1"
    echo "step 1, press the letter n on your keyboard and then press enter"
    echo "step 2, press number 1 on your keyboard and press enter"
    echo "step 3, press enter again"
    echo "step 4, type 786438 and then press enter"
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
    ./sshpass -p "alpine" scp -P 2222 ./$deviceid/$1/OS.tar root@localhost:/mnt2
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/OS.tar -C /mnt1"
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
    #./sshpass -p "alpine" scp -P 2222 ./com.saurik.Cydia.Startup.plist root@localhost:/mnt1/System/Library/LaunchDaemons
    if [ "$1" = "7.0.2" ]; then
        ./sshpass -p "alpine" scp -P 2222 ./jb/Services.plist root@localhost:/mnt1/System/Library/Lockdown/Services.plist
    fi
    #./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir /mnt1/usr/libexec/y08wilm/"
    #./sshpass -p "alpine" scp -P 2222 ./startup root@localhost:/mnt1/usr/libexec/y08wilm/
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/OS.tar"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/log/asl/SweepStore"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/Library/PreinstalledAssets/*"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/Library/Preferences/.GlobalPreferences.plist"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt2/mobile/.forward"
    ./sshpass -p "alpine" scp -P 2222 ./fixkeybag root@localhost:/mnt1/usr/libexec/
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown root:wheel /mnt1/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist"
    if [ "$1" = "7.0.2" ]; then
        ./sshpass -p "alpine" scp -P 2222 ./$deviceid/$1/kernelcache2 root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plist /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plis_"
    else
        ./sshpass -p "alpine" scp -P 2222 ./$deviceid/$1/kernelcache root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches
    fi
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/usr/lib/libmis.dylib"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram oblit-inprogress=5"
    $(./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" &)
    if [ "$1" = "7.0.2" ]; then
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
            ../../irecovery -f kernelcache2.img4
            ../../irecovery -c bootx &
            cd ../../
        fi
        _kill_if_running iproxy
        echo "first phase of downgrading and jailbreaking your phone done"
        echo "once device boots up to the lock screen, turn on assistivetouch and disable auto lock"
        echo "then once you have done those two things, put the phone back into dfu mode"
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
        read -p "pls press the enter key once device is in the ramdisk" pause1
        ./iproxy 2222 22 &
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs -o suid,dev /dev/disk0s1s2 /mnt2"
        if [ "$1" = "7.0.2" ]; then
            ./sshpass -p "alpine" scp -P 2222 ./jb/fstab root@localhost:/mnt1/etc/
        else
            ./sshpass -p "alpine" scp -P 2222 ./fstab root@localhost:/mnt1/etc/
        fi
        ./sshpass -p "alpine" scp -P 2222 ./jb/libmis.dylib root@localhost:/mnt1/usr/lib/
        ./sshpass -p "alpine" scp -P 2222 ./jb/libsandbox.dylib root@localhost:/mnt1/usr/lib/
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir /mnt1/System/Library/Caches/com.apple.xpcd/"
        ./sshpass -p "alpine" scp -P 2222 ./jb/xpcd_cache.dylib root@localhost:/mnt1/System/Library/Caches/com.apple.xpcd/
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plist /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plis_"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/System/Library/Caches/com.apple.dyld/enable-dylibs-to-override-cache"
        $(./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot &" &)
    fi
else
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs /dev/disk0s1s1 /mnt1"
    ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/mount -w -t hfs -o suid,dev /dev/disk0s1s2 /mnt2"
    if [ "$1" = "7.0.2" ]; then
        ./sshpass -p "alpine" scp -P 2222 ./$deviceid/$1/kernelcache2 root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches
        ./sshpass -p "alpine" scp -P 2222 ./jb/libmis.dylib root@localhost:/mnt1/usr/lib/
        ./sshpass -p "alpine" scp -P 2222 ./jb/libsandbox.dylib root@localhost:/mnt1/usr/lib/
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mkdir /mnt1/System/Library/Caches/com.apple.xpcd/"
        ./sshpass -p "alpine" scp -P 2222 ./jb/xpcd_cache.dylib root@localhost:/mnt1/System/Library/Caches/com.apple.xpcd/
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mv /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plist /mnt1/System/Library/LaunchDaemons/com.apple.CommCenter.plis_"
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/System/Library/Caches/com.apple.dyld/enable-dylibs-to-override-cache"
    else
        ./sshpass -p "alpine" scp -P 2222 ./$deviceid/$1/kernelcache root@localhost:/mnt1/System/Library/Caches/com.apple.kernelcaches
    fi
    ./sshpass -p "alpine" scp -P 2222 ./startup root@localhost:/mnt1/usr/libexec/y08wilm/
    if [ "$1" = "7.0.2" ]; then
        ./sshpass -p "alpine" scp -P 2222 ./jb/fstab root@localhost:/mnt1/etc/
    else
        ./sshpass -p "alpine" scp -P 2222 ./fstab root@localhost:/mnt1/etc/
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
    if [ "$1" = "7.0.2" ]; then
        read -p "would you like enable root fs r/w on ios $1? " response79
        if [[ "$response79" = 'yes' || "$response79" = 'y' ]]; then
            ../../irecovery -f kernelcache.img4
        else
            ../../irecovery -f kernelcache2.img4
        fi
    fi
    ../../irecovery -c bootx &
    cd ../../
    exit
fi
