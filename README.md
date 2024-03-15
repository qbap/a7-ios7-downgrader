<div align="center">
<img src="https://apt.netsirkl64.com/CydiaIcon.png" height="128" width="128" style="border-radius:25%">
   <h1> a7-ios7-downgrader 
      <br/> seprmvr64, downgrade&jailbreak utility
   </h1>
</div>

<h6 align="center"> Should Support iOS/iPadOS 7.0.1 - 8.0b4  </h6>

# Chart of compatibility

| Firmware | App Store | Home btn  | Vol keys | CommCenter | Root fs r/w | Jailbreak | Tweaks  | Respring | Sideloadly | iTunes |
|----------|-----------|-----------|----------|------------|-------------|-----------|---------|----------|------------|--------|
| 7.0.1    | &#9745;   | &#9744;   | &#9744;  | &#9745;    | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.0.2    | &#9745;   | &#9744;   | &#9745;  | &#9745;    | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.0.3    | &#9745;   | &#9745;   | &#9745;  | &#9745;    | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.0.4    | &#9745;   | &#9745;   | &#9745;  | &#9745;    | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.0.6    | &#9745;   | &#9745;   | &#9745;  | &#9745;    | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.1.2    | &#9745;   | &#9745;   | &#9745;  | &#9745;    | &#9745;     | &#9745;   | &#9745; | &#9745;  | &#9745;    | &#9745;|
| 8.0b4    | &#9744;   | &#9745;   | &#9745;  | &#9745;    | &#9745;     | &#9745;   | &#9745; | &#9745;  | &#9745;    | &#9745;|

## How do I use this?

this script deletes everything on your phone, including the main os. pls backup all your data before using this script, as it will be unrecoverable after. use this script at your own risk, i am not responsible for any damages caused by you using this script

to use this app, you need to be on a supported version, and have an a7 device

`xcode-select install`

`git clone --recursive https://github.com/y08wilm/a7-ios7-downgrader && cd a7-ios7-downgrader`

`chmod +x script.sh`

connect iphone in dfu mode

`sudo ./script.sh 7.1.2 <your ios version>`

or

`sudo ./script.sh 8.0 <your ios version>` **ios 8.0 does not have working app store

replace `<your ios version>` with the version of ios you are running rn

so if u r on ios 11.4.1 type 11.4.1

**if you are on 12.5.6 or 12.5.7, make sure you type 12.5.5 instead. this is because https://www.theiphonewiki.com/wiki/Firmware_Keys/12.x#iPhone does not have firmware keys for newer versions of ios 12 and the script will fail

**if u are on 10.3.3, make sure you type 11.0 instead. this is bcz our amfi patch for the ramdisk does not work on ios 10.3.3 and the ramdisk will not boot properly

this is used to be able to mount filesystems on ramdisk and backup the necessary files we need to downgrade

which is unjailbroken

and follow the steps, as it will restore that ios onto your phone

whenever the script asks for a password it is either your mac password or `alpine`

when the script says "waiting for device in dfu mode" it means u gotta put it back into dfu

when it gets to the partitioning step, make terminal full screen, it has easy to read instructions on top

all you gotta do at that step is press the keys on your keyboard it tells you to

cydia will be installed and work as normal

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
 - Test iPad mini 2 compatibility
 
 ## iOS 8+ Support

as of right now the script supports up to ios 8 beta 4

the keybags dont unlock on newer versions of ios 8 and thus results in a slide to upgrade screen

this means iphone 6 support on ios 8 is out of the question

but ios 9 support may be more feasible in the near future

to support newer versions of ios, and subsequently iphone 6 and later we must first

get a static sandbox patch working with `Kernel64Patcher` as it is required for ios 9 to boot with seprmvr64

see https://files.catbox.moe/wn83g9.mp4 for a video example of why we need sandbox patches for ios 9

## Quirks

passcode& touch id does not work, if the device ever asks you for a passcode it will accept anything as the passcode

if you lock the screen while the phone is on, it will cause a deep sleep bug which causes the phone to be frozen at a black screen until you force reboot the device

app store does not work on ios 8*

wifi does not work unless you connect to an open wifi network, in other words the wifi network must not have a password

respring does not work on ios 7.0.x properly, so in order to respring on those versions you should open the wtfis app on the home screen and hit "go"

in order for tweaks to work on ios 7.1.x, open the wtfis app on the home screen and hit "go" and it will patch the sandbox to allow tweaks to work

when booting ios 8 you will find that you wont see any app icons on the home screen when you first slide to unlock. to fix this, slide up from the bottom of the screen and tap on calculator. once in the calculator app, press the home button and then you will be at the home screen and all your app icons will appear as normal

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

it also installs a modified `data_ark.plist` to the device to enable the app store to work as well

when u try to sign in it may say incorrect password and send 2fa code to your other devices

if it doesnt say incorrect password but it sent a 2fa code to your other devices, sign out

retype ur password on the iphone but this time put the 2fa code at the end

for example if your password is `ilikenekos13` and the 2fa code is 275 831

you would type `ilikenekos13275831` as the password to sign into the app store

and it will log in with no issues

when downloading apps you have to go to purchased apps tab and download the last compatible version

tested working on my iphone 5s on ios 7.0.2 while jailbroken with cydia installed

## Credits

- [TheRealClarity](https://github.com/TheRealClarity) for ios 7& 8 semi untethered sandbox patches to enable tweaks to work
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
