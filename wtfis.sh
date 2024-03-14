        ./Darwin/sshpass -p "alpine" scp -P 2222 ./jb/wtfis.app_ios7.tar root@localhost:/mnt1/
        ./Darwin/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'tar --preserve-permissions -xvf /mnt1/wtfis.app_ios7.tar -C /mnt1/Applications'
        ./Darwin/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "touch /mnt1/.installed_wtfis"
        ./Darwin/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chown root:wheel /mnt1/.installed_wtfis"
        ./Darwin/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 777 /mnt1/.installed_wtfis"
