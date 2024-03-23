sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | gptfdisk /dev/rdisk0s1
n # new partition
1 # partition number 1
# first sector start at beginning of disk 
1264563 # last sector
# hit enter again to leave at default
n # new partition
2 # partion number 2
# hit enter to use default first sector
# hit enter again to extend partition to end of disk
# hit enter again to leave at default
w # write changes to disk
y # confirm changes
EOF