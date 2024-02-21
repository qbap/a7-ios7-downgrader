# a7-ios7-downgrader

i made this little script that lets you downgrade a7 devices to older ios

as of the time of this writing this script supports

iPhone 5s

and supports booting any version of ios 7

but only ios 7.0.2 works with the jailbreak related portion of the script

please refer to the jailbreak section of this readme for more info

future support may be added for newer versions

8.4.1** gets stuck on slide to upgrade screen

9.3.2** gets stuck on progress bar on first boot

# contact

if you need to reach me for any reason, you can msg me on telegram at [wilm271](https://t.me/wilm271)

use this option if you need to contact me for issues with this script

do NOT abuse this option of being able to contact me, or i will take it away

# data loss

this script deletes everything on your phone, including the main os

pls backup your data before using this script

dual boot support might be added in the future but is not supported rn

use at your own risk

# jailbreak status

jb bootstrap tar extracts successfully onto idevice and does not kernel panic upon boot

cydia is successfully installed and device functions normally

~~cydia closes upon launch but interestingly enough the actual layout of the Cydia app does load for a split second before it closes, and if you type cydia:// into safari it opens the Cydia app also~~

cydia launch daemon runs but only if I modify the launch daemon plist to make it run as root and then chown the file to make it owned by root instead of mobile 

~~launch daemon script is able to modify the entirety of /var but rootfs is still write protected as of the time of writing~~

~~i now know that we have to patch a check in the kernel for mount_common to be able remount / as rw~~

~~the existing open source patches on the internet for this are for armv7 only and not for arm64~~

~~i have aquired armv7 patches for both tfp0 and rootfs rw, but they need to be ported over to arm64~~

~~once someone updates the kernel patcher to work on arm64 kernelcache, we should have tfp0 and rootfs rw~~

~~see [kernel_patcher/notes.txt](https://github.com/y08wilm/a7-ios7-downgrader/blob/main/kernel_patcher/notes.txt) for more info~~

~~if someone can get this done, we should be able to get jailbreak and cydia working~~

we now have full rootfs rw with the help of an appleinternal development kernel

release kernels can not remount / as rw but development kernels can

so with the help of this development kernel we can modify fstab to make / mount as rw on boot

i tested writing to rootfs from a launch daemon script and it works

we also got patched versions of these dylibs to work

libmis.dylib "code sign bypass"

libsandbox.dylib "userspace sandbox bypass"

xpcd_cache.dylib "launch daemons (?)"

see https://www.theiphonewiki.com/wiki/Talk:Pangu8 for more info on these dylibs

~~now all that is left is figuring out how to bootstrap cydia properly (?)~~

~~cydia app opens but closes immediately, possibly caused by `setuid(0)` not working (?)~~

~~setuid requires chown and chmod to be done properly, so it is possible that might be the issue~~

cydia now works perfectly on ios ~~7.0~~ 7.0.2 ~~but you may need to unplug and replug the power cable on the iphone a couple dozen times~~

when the screen goes black due to auto lock on lock screen you can just plug in a power cable and it will make the screen turn back on

i highly recommend turning on assistivetouch and disabling auto lock in settings on your iphone

tweaks do not work, but cydia itself does work

# requirements

mac os high sierra 10.13** newer versions might work but are not tested

intel mac** amd is NOT supported

stable internet connection

at least 20gb free space on hdd

usb type A port** usb-c is NOT supported

already jailbroken device** cause the script has to backup `apticket.der`, `sep-firmware.img4`, `Baseband`, and `keybags` from your device before you can downgrade to older ios

# preparing your device

note that downgrading to ios 10.3.3 may not be required, it is just what i happened to do

you may not have to downgrade to ios 10.3.3, i just havent tested on latest ios 12 sep only ios 10.3.3 sep

use [Legacy-iOS-Kit](https://github.com/LukeZGD/Legacy-iOS-Kit) or [LeetDown](https://github.com/rA9stuff/LeetDown/releases) to downgrade your device to ios 10.3.3

side note if you are trying to use [LeetDown](https://github.com/rA9stuff/LeetDown/) to downgrade an icloud locked device, you have to use [LeetDown v1.0.3](https://github.com/rA9stuff/LeetDown/releases/tag/1.0.3)

if you are trying to use [Silver](https://www.appletech752.com/downloads.html) to icloud bypass your device, make sure you put it into dfu mode immediately after the first progress bar on the iphone finishes when using [LeetDown v1.0.3](https://github.com/rA9stuff/LeetDown/releases/tag/1.0.3) and only then run the untethered bypass with [Silver](https://www.appletech752.com/downloads.html). if you reach the second progress bar on the device when restoring to ios 10.3.3 then you have to start all over again

it is also worth noting that [LeetDown v1.0.3](https://github.com/rA9stuff/LeetDown/releases/tag/1.0.3) is the only one that works reliably under mac os high sierra 10.13

use [totally.not.spyware.lol](https://totally.not.spyware.lol/) to jailbreak your ios 10.3.3 device

this website may require several, if not several dozen attempts to jailbreak your device successfully

then install dropbear on cydia from `apt.netsirkl64.com` repo

and then go and install `openssh` and `mterminal` as well

dropbear enables ssh on ios 10 and openssh enables sftp on ios 10

open mterminal and type `su -`

it will ask for password, the password is `alpine`

then you should type `dropbear -R -p 2222`

this will then enable dropbear ssh to work over wifi

go into settings and write down the local wifi ip of your device https://www.howtogeek.com/796854/iphone-ip-address/

# issues

[seprmvr64?tab=readme-ov-file#caveats](https://github.com/mineek/seprmvr64?tab=readme-ov-file#caveats)

you can connect only to an OPEN wifi connection

passcode and touch id does not work

device becomes unresponsive once screen is locked or goes to sleep

home button does not work when jailbroken, but works fine unjailbroken on ios 7.0.4-7.1.2

~~safari does not work when jailbroken~~ might be fixed on latest commit

~~mail app does not work when jailbroken~~ might be fixed on latest commit

~~app store does not work when jailbroken, but works fine unjailbroken on ios 7.0.4-7.1.2~~ might be fixed on latest commit

ios 8 gets stuck on slide to upgrade screen** please pr a fix for this, thanks

# working

wifi, if using a wifi connection that does not have a password

bluetooth** tested working with airpods 2nd gen

~~app store when unjailbroken on ios 7.0.4-7.1.2~~ might work on latest commit regardless

# not tested

hactivation** https://trainghiemso.vn/cach-ha-iphone-5-ipad-4-tu-10-3-3-xuong-8-4-1-khong-can-shsh-blobs/

playing music with the screen locked

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

`./script.sh 7.0.2`

and follow the steps, as it will install ios 7.0.2 onto your phone

whenever the script asks for a password it is either your mac password or `alpine`

when the script says "waiting for device in dfu mode" it means u gotta put it back into dfu

uhh and when it gets to the partitioning step, make terminal full screen, it has easy to read instructions on top

all you gotta do at that step is press the keys on your keyboard it tells you to

cydia will be installed and work as normal, just tweaks do not work yet

# technical breakdown 

newer cydia does check `/.cydia_no_stash`

https://github.com/sbingner/cydia/blob/master/MobileCydia.mm#L8981

if that file is present it SKIPS stashing

ios 7 cydia does NOT check `/.cydia_no_stash`

https://github.com/sbingner/cydia/blob/2b6abb5670bfa1bb1cb3273e3e7531bcab0e418c/MobileCydia.mm#L10207

stashing is the process of moving critical system files from the system partition to the user partition to free up disk space on the system partition

this process of moving critical system files breaks safari, maps, mail, among other things such as app store on ios 7

the only way to fix this, as it turns out, is to follow this chain of command

## first boot

use RELEASE kernel, no rootfs r/w, no libmis.dylib, and no libsandbox.dylib

this effectively means a stock oem first boot on ios 7.0.2

the only difference from stock being that we are disabling CommCenter and hacktivating the device. CommCenter, if left enabled, causes the entire os to become extremely slow and unoperable. according to online docs, CommCenter is only used for calling but cellular is not possible since the device is hacktivated as it is

once booted, enable assistive touch and disable screen lock timer then put the phone back into dfu

## second boot

boot into ssh and copy over libmis.dylib, libsandbox.dylib, and updated fstab to remount / as rw

then boot into ios but with DEVELOPMENT kernel instead of RELEASE kernel

this jailbreaks the device 

now the user MUST connect the device to an open wifi network, and open cydia

once cydia is opened it will prepare filesystem, once done open cydia again

refresh sources and update cydia to the latest version

this should then, in theory, let us use cydia without having to stash critical system files

put the phone back into dfu

## third boot

unstash /Applications, /Library/Ringtones, and /usr/share and ensure `/.cydia_no_stash` is present and readable

this enables a manual stashing mode on cydia

reboot back into ios

safari, maps, mail, etc should now be working

# chart of compatibility

| Firmware | App Store | Safari  | Home btn | Vol keys | Pwr btn | CommCenter | Root fs r/w | Jailbreak |
|----------|-----------|---------|----------|--------------------|------------|-------------|-----------|
| 7.0.1    | &#9745;   | &#9745; | &#9744;  | &#9744;  | &#9744; | &#9744;    | &#9744;     | &#9744;
| 7.0.2    | &#9745;   | &#9745; | &#9744;  | &#9745;  | &#9744; | &#9744;    | &#9745;     | &#9745;
| 7.0.3    | &#9745;   | &#9745; | &#9745;  | &#9745;  | &#9745; | &#9744;    | &#9744;     | &#9744;
| 7.0.4    | &#9745;   | &#9745; | &#9745;  | &#9745;  | &#9745; | &#9744;    | &#9744;     | &#9744;
| 7.0.6    | &#9745;   | &#9745; | &#9745;  | &#9745;  | &#9745; | &#9744;    | &#9744;     | &#9744;
| 7.1.2    | &#9745;   | &#9745; | &#9745;  | &#9745;  | &#9745; | &#9745;    | &#9744;     | &#9744;

# chart technical breakdown

7.0.6 boots fine unjailbroken, home button, safari, siri, app store all working. ios boots into an infinite spin lock when using dev kernel. this means no jailbreak on ios 7.0.6 is possible. xpcd_cache.dylib is untested on this version

7.0.3 & 7.0.4 boots fine unjailbroken, home button, safari, siri, app store all working. ~~when booting dev kernel it results in flickering screen~~ if you delete `xpcd_cache.dylib` it boots into an infinite spin lock when using the dev kernel. this means no jailbreak on this version is possible.

7.0.2 boots fine unjailbroken, safari is working. home button, pwr button and volume keys do NOT work. ~~when booting dev kernel it results in flickering screen~~ if you delete `xpcd_cache.dylib` it boots fine with the dev kernel with no flickering screen. this means working safari while jailbroken but again home button, pwr button and volume keys are not working.** vol keys are now working with the help of appleinternal shit

7.0.1 & 7.0 boots fine unjailbroken, safari is working. home button, pwr button and volume keys do NOT work. when booting dev kernel it boots fine and cydia functions as normal, but tweak injection does not work. if `xpcd_cache.dylib` is installed, the wallpaper is black, but there is no flickering screen.

7.1.2 has working CommCenter, no need to disable it

see https://github.com/y08wilm/a7-ios7-downgrader?tab=readme-ov-file#technical-breakdown as to why safari and other apps stop working after "preparing filesystem" on cydia. tldr you need to update cydia to a version that supports `/.cydia_no_stash` and then run the script again and when it asks you if you want to skip the ramdisk type "no", then press any key once booted into ramdisk and wait about a minute for it to unstash critical system files and type "alpine" hit enter and then type "exit" and hit enter. the script will then guide you thru the steps to boot back into ios. safari and other apps should then work.

# credits

- [Nathan](https://github.com/verygenericname) for the ssh ramdisk and [iBoot64Patcher fork](https://github.com/verygenericname/iBoot64Patcher)
- [Mineek](https://github.com/mineek) for [seprmvr64](https://github.com/mineek/seprmvr64) and other patches** i want to give a very special thanks to [Mineek](https://github.com/mineek), if it werent for them this entire project would have not been possible. you are amazing and i appreciate all that you do, thank you so much
- [nyuszika7h](https://github.com/nyuszika7h) for the script to help get into DFU
- [tihmstar](https://github.com/tihmstar) for [pzb](https://github.com/tihmstar/partialZipBrowser)/original [iBoot64Patcher](https://github.com/tihmstar/iBoot64Patcher)/original [liboffsetfinder64](https://github.com/tihmstar/liboffsetfinder64)/[img4tool](https://github.com/tihmstar/img4tool)
- [Tom](https://github.com/guacaplushy) for a couple patches and bugfixes
- [xerub](https://github.com/xerub) for [img4lib](https://github.com/xerub/img4lib) and [restored_external](https://github.com/xerub/sshrd) in the ramdisk
- [Cryptic](https://github.com/Cryptiiiic) for [iBoot64Patcher](https://github.com/Cryptiiiic/iBoot64Patcher) fork, and [liboffsetfinder64](https://github.com/Cryptiiiic/liboffsetfinder64) fork
- [libimobiledevice](https://github.com/libimobiledevice) for several tools used in this project (irecovery, ideviceenterrecovery etc), and [nikias](https://github.com/nikias) for keeping it up to date
- [Nick Chan](https://github.com/asdfugil) general help with patches and iBoot payload stuff
- [Serena](https://github.com/SerenaKit) for helping with boot ramdisk.
- [planetbeing](https://github.com/planetbeing/) for dmg tool from [xpwn](https://github.com/planetbeing/xpwn)
- [exploit3dguy](https://github.com/exploit3dguy/) for [iPatcher](https://github.com/exploit3dguy/iPatcher) which is used for patching iBoot on ios 7
- [dora2-ios](https://github.com/dora2-iOS) for [iPwnder](https://iarchive.app/Download/ipwnder_macosx)
- [NyanSatan](https://github.com/NyanSatan) for [fixkeybag](https://github.com/NyanSatan/fixkeybag)
