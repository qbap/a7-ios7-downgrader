<div align="center">
<img src="https://files.catbox.moe/x7b0e2.png" height="128" width="128" style="border-radius:25%">
   <h1> Semaphorin 
      <br/> seprmvr64, downgrade& jailbreak utility
   </h1>
</div>

<h6 align="center"> Should Support iOS/iPadOS 7.0.1 - 8.0b4  </h6>

# IF YOUR DEVICE SUPPORTS [LEGACY-IOS-KIT](https://github.com/LukeZGD/Legacy-iOS-Kit), YOU SHOULD REALLY USE THAT OVER THIS.

# Chart of compatibility

| iOS      | iPhone 5s | iPad Mini 2 | iPad Air 1 | App Store | Home btn  | Vol keys | Root fs r/w | Cydia     | Tweaks  | Respring | Sideloadly | iTunes |
|----------|-----------|-------------|------------|-----------|-----------|----------|-------------|-----------|---------|----------|------------|--------|
| 7.0.1    | &#9745;   | &#9744;     | &#9744;    | &#9745;   | &#9744;   | &#9744;  | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.0.2    | &#9745;   | &#9744;     | &#9744;    | &#9745;   | &#9744;   | &#9745;  | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.0.3    | &#9745;   | &#9745;     | &#9744;    | &#9745;   | &#9745;   | &#9745;  | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.0.4    | &#9745;   | &#9745;     | &#9744;    | &#9745;   | &#9745;   | &#9745;  | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.0.6    | &#9745;   | &#9745;     | &#9744;    | &#9745;   | &#9745;   | &#9745;  | &#9745;     | &#9745;   | &#9745; | &#9744;  | &#9745;    | &#9745;|
| 7.1      | &#9745;   | &#9745;     | &#9745;    | &#9745;   | &#9745;   | &#9745;  | &#9745;     | &#9745;   | &#9745; | &#9745;  | &#9745;    | &#9745;|
| 7.1.1    | &#9745;   | &#9745;     | &#9745;    | &#9745;   | &#9745;   | &#9745;  | &#9745;     | &#9745;   | &#9745; | &#9745;  | &#9745;    | &#9745;|
| 7.1.2    | &#9745;   | &#9745;     | &#9745;    | &#9745;   | &#9745;   | &#9745;  | &#9745;     | &#9745;   | &#9745; | &#9745;  | &#9745;    | &#9745;|
| 8.0b4    | &#9745;   | &#9744;     | &#9744;    | &#9744;   | &#9745;   | &#9745;  | &#9745;     | &#9745;   | &#9745; | &#9745;  | &#9745;    | &#9745;|

## How do I use this?

this script deletes everything on your phone, including the main os. pls backup all your data before using this script, as it will be unrecoverable after. use this script at your own risk, we are not responsible for any damages caused by you using this script

to use this app, you need to downgrade to a supported version, and have a supported device

`xcode-select install` to install `git` on macos

`git clone --recursive https://github.com/y08wilm/Semaphorin && cd Semaphorin`

## Support

we now have a discord server where you can get help with this project

you can join with this discord invite link https://discord.gg/WQWDBBYJTb

if for some reason that invite link does not work, please contact [wilm271](https://t.me/wilm271) on telegram

the discord server is strictly for semaphorin support only, do not bring personal issues into our server

## First run

connect iphone in dfu mode

`sudo ./semaphorin.sh <the version you are downgrading to> --restore`

for example you may write `sudo ./semaphorin.sh 7.1.2 --restore`

the script has to backup important files from your current ios version before you can downgrade

when the script asks `what ios version are you running right now?` type your current ios version and hit enter

it should then begin the process of downgrading your device, please follow the on screen instructions

your device will be jailbroken

if you are on ios 7 please hit "go" in the wtfis app on your home screen to patch sandbox to allow cydia substrate to work properly

## Subsequent runs after downgrade is finished

connect iphone in dfu mode

`sudo ./semaphorin.sh <the version you downgraded to previously> --boot`

for example you may write `sudo ./semaphorin.sh 7.1.2 --boot` if you downgraded to ios 7.1.2 earlier

it should then boot ios as normal and be jailbroken

## Setup.app bypass

we will not be providing any support for any method of deleting `/Applications/Setup.app` with our script

this is only to comply with [r/jailbreak](https://www.reddit.com/r/jailbreak/) and [r/LegacyJailbreak](https://www.reddit.com/r/LegacyJailbreak/) rules and guidelines

the script will downgrade your ios version and jailbreak the downgraded os very easily

but in order to get to the home screen you must first delete `/Applications/Setup.app` on ios

which we will not be providing any support for at this time

## Contact

if you need to reach me for any reason, you can msg me on telegram at [wilm271](https://t.me/wilm271)

use this option if you need to contact me for issues with this script

do not abuse this option of being able to contact me, or i will take it away
 
## iOS 9.3 Support

keybags do not unlock on ios <=9.2.1 but they do on ios 9.3

the issue we are having with ios 9.3 atm is a ton of sandbox errors during boot

see https://files.catbox.moe/wn83g9.mp4 for a video example of why we need sandbox patches for ios 9

once we have sandbox patched out properly on ios 9.3 we should be good to go

## Quirks

passcode& touch id does not work, if the device ever asks you for a passcode it will accept anything as the passcode

if you lock the screen while the phone is on, it will cause a deep sleep bug which causes the phone to be frozen at a black screen until you force reboot the device

app store does not work on ios 8 or 9

wifi does not work unless you connect to an open wifi network, in other words the wifi network must not have a password

respring does not work on ios 7.0.x properly, so in order to respring on those versions you should open the wtfis app on the home screen and hit "go"

in order for tweaks to work on ios 7.1.x, open the wtfis app on the home screen and hit "go" and it will patch the sandbox to allow tweaks to work

when booting ios 8 you will find that you wont see any app icons on the home screen when you first slide to unlock. to fix this, slide up from the bottom of the screen and tap on calculator. once in the calculator app, press the home button and then you will be at the home screen and all your app icons will appear as normal

## Requirements

mac os high sierra 10.13** catalina should work but anything newer then that may not work

java 8** https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u262-b10/openlogic-openjdk-8u262-b10-mac-x64.pkg

python3** you can download it for macos high sierra from https://www.python.org/ftp/python/3.7.6/python-3.7.6-macosx10.6.pkg

pyimg4** just run `pip3 install pyimg4` before running the script

intel mac** amd is NOT supported

stable internet connection

at least 20gb free space on hdd

usb type A port** usb-c is NOT supported

working iphone** cause the script has to backup `apticket.der`, `sep-firmware.img4`, `Baseband`, and `keybags` from your device before you can downgrade to older ios

## Credits

- [johndoe123](https://twitter.com/iarchiveml) for the a7 ios 7 [downgrade guide](https://ios7.iarchive.app/downgrade/) which made this entire project possible
- [LukeZGD](https://github.com/LukeZGD/) for the updated [cydia.tar](https://github.com/LukeZGD/Legacy-iOS-Kit/raw/main/resources/jailbreak/freeze.tar) for jailbreaking older ios versions
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
