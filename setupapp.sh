    read -p "would you like to also delete Setup.app? " r
    read -p "what is your device id? " deviceid
    if [[ "$r" = 'yes' || "$r" = 'y' ]]; then
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "rm -rf /mnt1/Applications/Setup.app"
        ./sshpass -p "alpine" scp -P 2222 ./jb/data_ark.plist.tar root@localhost:/mnt2/
        # yeah so this doesnt do shit on ios 7.x, it is still unactivated on ios 7.x
        # however app store works and there is no hello screen when u boot
        ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist.tar -C /mnt2"
        if [[ "$1" == *"8"* ]]; then
            # this actually works reliably on ios 8 beta 4 /w full factoryactivation
            # gotta love a patched mobactivationd+ data_ark.plist
            ./sshpass -p "alpine" scp -P 2222 ./jb/data_ark.plist_2.tar root@localhost:/mnt2/
            ./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "tar -xvf /mnt2/data_ark.plist_2.tar -C /mnt2"
            ./sshpass -p "alpine" scp -P 2222 root@localhost:/mnt1/System/Library/PrivateFrameworks/MobileActivation.framework/Support/mobactivationd ./$deviceid/$1/mobactivationd.raw
            # patch _set_brick_state, dealwith_activation, handle_deactivate& check_build_expired
            ./mobactivationd64patcher ./$deviceid/$1/mobactivationd.raw ./$deviceid/$1/mobactivationd.patched -g -b -c -d
            ./sshpass -p "alpine" scp -P 2222 ./$deviceid/$1/mobactivationd.patched root@localhost:/mnt1/System/Library/PrivateFrameworks/MobileActivation.framework/Support/mobactivationd
        fi
    fi

