<div align="center">
<img src="https://apt.netsirkl64.com/CydiaIcon.png" height="128" width="128" style="border-radius:25%">
   <h1> a7-ios7-downgrader 
      <br/> <h2>seprmvr64, tether downgrade&jailbreak utility for a7</h2>
   </h1>
</div>

<h6 align="center"> Should Support iOS/iPadOS 7.0.1 - 7.1.2  </h6>

# Chart of compatibility

| Firmware | App Store | Safari  | Home btn | Vol keys | Pwr btn | CommCenter | Root fs r/w | Jailbreak | Tweaks |
|----------|-----------|---------|----------|----------|---------|------------|-------------|-----------|--------|
| 7.0.1    | &#9745;   | &#9745; | &#9744;  | &#9744;  | &#9744; | &#9744;    | &#9744;     | &#9744;   | &#9744;
| 7.0.2    | &#9745;   | &#9745; | &#9744;  | &#9745;  | &#9744; | &#9744;    | &#9745;     | &#9745;   | &#9745;
| 7.0.3    | &#9745;   | &#9745; | &#9745;  | &#9745;  | &#9745; | &#9744;    | &#9744;     | &#9744;   | &#9744;
| 7.0.4    | &#9745;   | &#9745; | &#9745;  | &#9745;  | &#9745; | &#9744;    | &#9744;     | &#9744;   | &#9744;
| 7.0.6    | &#9745;   | &#9745; | &#9745;  | &#9745;  | &#9745; | &#9744;    | &#9744;     | &#9744;   | &#9744;
| 7.1.2    | &#9745;   | &#9745; | &#9745;  | &#9745;  | &#9745; | &#9745;    | &#9744;     | &#9744;   | &#9744;

## How do I use this?

to use this app, you need to be on a supported version, and have an a7 device

`xcode-select install`

`git clone --recursive https://github.com/y08wilm/a7-ios7-downgrader && cd a7-ios7-downgrader`

`chmod +x script.sh`

connect iphone in dfu mode

if you have an iphone 5s, which is compatible with jb

`sudo ./script.sh 7.0.2`

otherwise

`sudo ./script.sh 7.1.2`

which is unjailbroken

and follow the steps, as it will restore that ios onto your phone

whenever the script asks for a password it is either your mac password or `alpine`

when the script says "waiting for device in dfu mode" it means u gotta put it back into dfu

when it gets to the partitioning step, make terminal full screen, it has easy to read instructions on top

all you gotta do at that step is press the keys on your keyboard it tells you to

if you have an iphone 5s and used ios 7.0.2, cydia will be installed and work as normal

## How was this done? 
 - It removes `/System/Library/LaunchDaemons/com.apple.CommCenter.plist`
 - [INTERNAL_INSTALL_LEGAL](https://www.theiphonewiki.com/wiki/INTERNAL_INSTALL_LEGAL)
 - https://vk.com/wall-43001537_167085
 - [11A24580o](https://iarchive.app/Download/11A24580o.zip)
 - [/.cydia_no_stash](https://github.com/sbingner/cydia/blob/master/MobileCydia.mm#L8981)
 - [cydia.tar.lzma](https://drive.google.com/open?id=17aHoLEXsHKwf39JCxC5R9MIhO4iARtqI)
 - [Kernel64Patcher](https://github.com/y08wilm/Kernel64Patcher)
 - [seprmvr64](https://github.com/mineek/seprmvr64)

## TODO
 - Try getting launch daemons to start automatically on boot, such as ssh
 - Add a boot splash screen
 - Test iPad mini 2 compatibility with [11A24580o](https://iarchive.app/Download/11A24580o.zip) kernel for jailbreak

## Quirks

passcode& touch id does not work, if the device ever asks you for a passcode it will accept anything as the passcode

for tweaks to work, make sure do not hit restart springboard when cydia asks you to. instead, use assistivetouch to go to the home screen& go into the settings app and hit general and erase all content and settings. this does not delete any of ur data and will instead restart the springboard. if you don't do it this way, you will be stuck on a spinning circle after hitting restart springboard on cydia. do not do this more then once in the same boot otherwise springboard may crash

app store does not work after you hit "erase all content and settings" due to a crash in `com.apple.StreamingUnzipService` caused by cydia substrate. to fix this, put the phone back into dfu and run the script again. install apps as needed from the app store while cydia substrate isnt loaded and then "erase all content and settings" again to load cydia substrate again

wifi does not work unless you connect to an open wifi network, in other words the wifi network must not have a password

home button does not work unless you are using ios 7.0.3 or higher, which is incompatible with this jailbreak i made. so if you want jailbreak, looks like you are shit outa luck for home button to work until someone designs a Kernel64Patcher for ios 7.0.3 or higher on arm64 kernels. the needed patches are `vm_map_enter`, `vm_map_protect`, and `mount_common` in order to jailbreak ios 7.0.3 or higher. the current kernel patcher we are using in this script only works on dev kernels, not release kernels, and is missing `mount_common` patch

this script deletes everything on your phone, including the main os. pls backup all your data before using this script, as it will be unrecoverable after. use this script at your own risk, i am not responsible for any damages caused by you using this script

## Contact

if you need to reach me for any reason, you can msg me on telegram at [wilm271](https://t.me/wilm271)

use this option if you need to contact me for issues with this script

do not abuse this option of being able to contact me, or i will take it away

## Requirements

mac os high sierra 10.13** newer versions might work but are not tested

intel mac** amd is NOT supported

stable internet connection

at least 20gb free space on hdd

usb type A port** usb-c is NOT supported

working iphone** cause the script has to backup `apticket.der`, `sep-firmware.img4`, `Baseband`, and `keybags` from your device before you can downgrade to older ios

## Setup.app bypass

this script deletes Setup.app during the process of tether downgrading your device

it also installs a modified data_ark.plist to the device to enable the app store to work as well

when u try to sign in it may say incorrect password and send 2fa code to your other devices

if it doesnt say incorrect password but it sent a 2fa code to your other devices, sign out

retype ur password on the iphone but this time put the 2fa code at the end

for example if your password is `ilikenekos13` and the 2fa code is 275 831

you would type `ilikenekos13275831` as the password to sign into the app store

and it will log in with no issues

when downloading apps you have to go to purchased apps tab and download the last compatible version

tested working on my iphone 5s on ios 7.0.2 while jailbroken with cydia installed

## Technical breakdown

this script uses seprmvr64& tether downgrades your device

seprmvr64 is a tool developed by mineek that patches the kernel to allow ios to work with an incompatible sep

this script also jailbreaks your device using my own method of jailbreaking ios 7

it is an entirely new, undocumented jailbreak that i designed myself and here i will give a bit of a breakdown

armv7 kernel patchers exist for ios 7, see https://github.com/y08wilm/a7-ios7-downgrader/tree/811e90d38565422e00b0e5b6aeb4128cae1cfb79/kernel_patcher

howerver those kernel patches do not work on arm64 devices such as the iphone 5s

that kernel patcher that i just linked has very important patches necessary for jailbreaking ios 7

namely `vm_map_enter` patch which is required for cydia substrate to be able to inject into running processes

as it turns out you need to also patch `vm_map_protect` for cydia substrate to work

and also `mount_common` patch which is required for being able to mount rootfs as rw

so without an open source arm64 kernel patcher in existence, i decided to try to find an alternative solution

upon a lot of digging, i learned that dev kernels allow you to mount rootfs as rw without a `mount_common` patch

so i decrypted an appleinternal kernel, namely `11A24580o`, and used that to boot ios

i quickly learned that, in doing so, ios 7.0.3+ is unbootable as it results in an infinite spinning circle on boot

but ios 7.0.1 and 7.0.2 boots just fine when using that kernel

and? rootfs rw worked first try

also, ios is unbearably slow on any version older then ios 7.1.2 due to CommCenter acting a fool

as it turns out, the only way to fix this is to outright disable CommCenter by removing it from ssh

CommCenter is not needed since it is only for calling and bcz we are using Setup.app bypass we will not have working calling

had a bit of a struggle trying to figure out how to install cydia onto the device with proper permissions so that it would open

but once i got cydia installed successfully using the script, i opened cydia and it worked

but uh, after "preparing filesystem" on cydia, guess what? a ton of system apps stopped working

safari, maps, mail, etc. poof, not working, every time you try to open it the app just crashes immediately

at the time app store also did not work while jailbroken, cause i was trying to use `libmis.dylib` and `libsandbox.dylib`

`libmis.dylib` is in charge of amfi bypass

`libsandbox.dylib` is in charge of sandbox bypass

those dylibs, as it turns out, breaks `profiled` which in turn breaks app store

but luckily both of those dylibs are not needed bcz `PE_i_can_has_debugger=1` bypasses sandbox and `amfi=0xff cs_enforcement_disable=1` bypasses amfi

after removing those dylibs, app store started working by safari, maps, mail, etc. were still broken

as it turns out, "preparing filesystem" was the culprit, after a lot of investigating

so i tried to stop cydia from "preparing filesystem" by adding `/.cydia_no_stash` but it didnt work

newer cydia does check `/.cydia_no_stash`

https://github.com/sbingner/cydia/blob/master/MobileCydia.mm#L8981

if that file is present it skips "preparing filesystem" aka stashing

ios 7 cydia does NOT check `/.cydia_no_stash`

https://github.com/sbingner/cydia/blob/2b6abb5670bfa1bb1cb3273e3e7531bcab0e418c/MobileCydia.mm#L10207

stashing is the process of moving critical system files from the system partition to the user partition to free up disk space on the system partition

this process of moving critical system files breaks safari, maps, mail, among other things on ios 7

the only way to fix this, as it turns out, is to do this

first boot

use RELEASE kernel, no rootfs r/w, no libmis.dylib, and no libsandbox.dylib

this effectively means a stock oem first boot on ios 7.0.2

the only difference from stock being that we are disabling CommCenter and hacktivating the device. CommCenter, if left enabled, causes the entire os to become extremely slow and unoperable. according to online docs, CommCenter is only used for calling but cellular is not possible since the device is hacktivated as it is

once booted, enable assistive touch and disable screen lock timer then put the phone back into dfu

second boot

boot into ssh and copy updated fstab to remount / as rw

then boot into ios but with DEVELOPMENT kernel instead of RELEASE kernel

this jailbreaks the device 

now the user MUST connect the device to an open wifi network, and open cydia

once cydia is opened it will prepare filesystem, once done open cydia again

refresh sources and update cydia to the latest version

this should then, in theory, let us use cydia without having to stash critical system files

put the phone back into dfu

third boot

boot into ssh ramdisk

unstash /Applications, /Library/Ringtones, and /usr/share and ensure `/.cydia_no_stash` is present and readable

this enables a manual stashing mode on cydia

reboot back into ios

safari, maps, mail, etc should now be working

now came the very tricky part of trying to get tweaks to work

as i said before, `vm_map_enter` and `vm_map_protect` is required for cydia substrate to inject tweaks into processes

see https://iphonedev.wiki/Cydia_Substrate#MobileHooker for more info on how cydia substrate hooks into processes

the only way to get tweaks to work on ios 7 is to patch `vm_map_enter` and `vm_map_protect` in the kernel

so, i used student discount on https://binary.ninja/purchase/, and manually patched the `11A24580o` kernel

once i figured out how to patch the kernel in binary ninja, i had to figure out how to make my own `Kernel64Patcher`

spent an entire day learning how `Kernel64Patcher` works and made my own patches in a fork of it

compiled the patcher and we are now using it in this project

works perfectly, now we have arm64 kernel patches for `vm_map_enter` and `vm_map_protect`

however, the kernel patches i made only work on dev kernels and not release kernels

regardless, we now have the necessary kernel patches in order for cydia substrate to work on arm64

`vm_map_enter`
ffffff8000283d64 -> nop

`vm_map_protect`
ffffff80002864a0 -> nop

but if you try to install a tweak on cydia, and hit restart springboard in cydia, it gets infinite spinning circle

idk why it does, but it does. and as it turns out the only way to fix this is to use assistivetouch to go to the home screen& go into the settings app and hit general and erase all content and settings. this does not delete any of ur data and will instead restart the springboard

tweaks will then start working

but dont use "erase all content and settings" more then once in the same boot otherwise springboard may crash

## Credits

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
