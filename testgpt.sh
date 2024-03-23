sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | gptfdisk /dev/rdisk0s1
  n # new partition
  1 # partition number 1
    # hit enter 
  1264563
    # hit enter again
  n # new partition
  2 # partion number 2
    # hit enter 
    # hit enter again
    # hit enter again
  w # write changes to disk
  y # confirm changes
EOF