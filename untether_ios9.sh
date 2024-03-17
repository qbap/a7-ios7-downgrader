./sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'cp /mnt1/usr/libexec/CrashHousekeeping /mnt1/usr/libexec/CrashHousekeeping_o'
./sshpass -p "alpine" scp -P 2222 ./jb/untether_ios9 root@localhost:/mnt1/usr/libexec/CrashHousekeeping
