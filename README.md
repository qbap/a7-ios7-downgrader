hi fellow haters

im wilma!! yeahyeah, f you too!

# a7-ios7-downgrader

i made this little script that lets you downgrade a7 devices to older ios

as of the time of this writing this script supports

iPhone 5s **iPhone6,1

and supports the following ios versions

7.0.6

7.1.2

preliminary support has been added for 

iPhone 5s **iPhone6,2

pls let me know if these devices work

and

8.4.1** gets stuck on slide to upgrade screen

9.3.2** gets stuck on progress bar on first boot

# data loss

this script deletes everything on your phone, including the main os

pls backup your data before using this script

dual boot support might be added in the future but is not supported rn

use at your own risk

# requirements

mac os high sierra 10.13** newer versions might work but are not tested

intel mac** amd is NOT supported

stable internet connection

at least 20gb free space on hdd

usb type A port** usb-c is NOT supported

# issues

[seprmvr64?tab=readme-ov-file#caveats](https://github.com/mineek/seprmvr64?tab=readme-ov-file#caveats)

you can connect only to an OPEN wifi connection

passcode and touch id does not work

kernel panics if screen is locked for more then 5 minutes** might not panic if music is playing in background, havent tested that yet

ios 8 gets stuck on slide to upgrade screen** cmon people pls pr a fix for this asap so i can try injecting etasonJB into the Tips.app

# working

wifi, if using a wifi connection that does not have a password

bluetooth** tested working with airpods 2nd gen

app store

# not tested

Evasi0n7** requires ios 7.0.6 and needs to be patched using https://github.com/UInt2048/7.0/

hactivation** https://trainghiemso.vn/cach-ha-iphone-5-ipad-4-tu-10-3-3-xuong-8-4-1-khong-can-shsh-blobs/

# setup.app bypass

it installs a modified data_ark.plist to the device to enable the app store to work as well

when u try to sign in it will say incorrect password and send 2fa code to your other devices

retype ur password on the iphone but this time put the 2fa code at the end

for example if your password is `ilikenekos13` and the 2fa code is 275 831

you would type `ilikenekos13275831` as the password to sign into the app store

and it will log in with no issues

when downloading apps you have to go to purchased apps tab and download the last compatible version

tested working on my iphone 5s on ios 7.1.2

# how to use

`xcode-select install`

`git clone --recursive https://github.com/y08wilm/a7-ios7-downgrader && cd a7-ios7-downgrader`

`chmod +x script.sh`

`chmod +x clean.sh`

connect iphone in dfu mode

`./script.sh`

type `7.1.2` for the ios version to downgrade to

and follow the steps

whenever the script asks for a password it is either your mac password or `alpine`

when the script says "waiting for device in dfu mode" it means u gotta put it back into dfu

uhh and when it gets to the partitioning step, make terminal full screen, it has easy to read instructions on top

all you gotta do at that step is press the keys on your keyboard it tells you to