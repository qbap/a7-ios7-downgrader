<div align="center">
<img src="https://files.catbox.moe/x7b0e2.png" height="128" width="128" style="border-radius:25%">
   <h1> Semaphorin 
      <br/> Downgrade & Jailbreak Utility using seprmvr64
   </h1>
</div>

<h6 align="center"> Supports* iOS 7.0.1-7.1.2/8.0 Beta 4  </h6>

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
| 8.0b4    | &#9745;   | &#9745;     | &#9745;    | &#9744;   | &#9745;   | &#9745;  | &#9745;     | &#9745;   | &#9745; | &#9745;  | &#9745;    | &#9745;|

## How do I use this?

This script deletes everything on your phone, including the main os. Make sure to backup all of your data before using this script, as it will be unrecoverable after. Use this script at your own risk, we are not responsible for any damages caused by you using this script.

To use this app, you need to downgrade to a supported version, and have a supported device.

`xcode-select install` to install `git` on macos

`git clone https://github.com/y08wilm/Semaphorin && cd Semaphorin`

## Support

We now have a Discord server where you can get help with this project

You can join with this discord invite link https://discord.gg/WQWDBBYJTb

If for some reason that invite link does not work, please contact [wilm271](https://t.me/wilm271) on telegram

The Discord server is strictly for semaphorin support only, do not bring personal issues into our server

## First run

Connect device in DFU mode

`sudo ./semaphorin.sh <the version you are downgrading to> --restore`

For example you may write `sudo ./semaphorin.sh 7.1.2 --restore`

The script has to backup important files from your current iOS version before you can downgrade.

When the script asks `what ios version are you running right now?` type your current ios version and then hit the enter key on your keyboard

It should then begin the process of downgrading your device, please follow the on screen instructions

Your device will be jailbroken automatically.

If you are on ios 7 please hit "go" in the wtfis app on your home screen to patch sandbox to allow cydia substrate to work properly.

## Subsequent runs after downgrade is finished

Connect device in DFU mode

`sudo ./semaphorin.sh <the version you downgraded to previously> --boot`

For example, if you downgraded to iOS 7.1.2, you would use `sudo ./semaphorin.sh 7.1.2 --boot`.

It should boot to your requested iOS version normally and jailbroken.

## Setup.app bypass

We will not be providing any support for any method of deleting `/Applications/Setup.app` with our script

This is only to comply with [r/jailbreak](https://www.reddit.com/r/jailbreak/) and [r/LegacyJailbreak](https://www.reddit.com/r/LegacyJailbreak/) rules and guidelines

The script will downgrade your ios version and jailbreak the downgraded os very easily

But in order to get to the home screen you must first delete `/Applications/Setup.app` on iOS to which we will not be providing any support for at this time.

## Troubleshooting

   ### Deep sleep, device won't turn on after locking it, have to reboot.
   The issue that causes deep sleep is unfortunately **unfixable**. There is, however, a workaround to this:
      
      1. Add [this repo](julioverne.github.io) to Cydia after setup
      
      2. Search for the tweak Fiona
      
      3. Install it
      
      4. Profit
   *Note: This does slightly affect battery life due to the way it works.

   ### Unsupported version/OS
   The script only officially works on macOS 10.13 up to 10.15 (High Sierra to Catalina) due to some limitations on the developer's end. You have to install one of those versions to use the script. Please do not ask us about this.

Linux support is not planned either, do not ask about this either.

   ### Unable to connect to WiFi networks, incorrect password.
   This is caused by an issue that's *impossible* to fix. You need to connect to an open WiFi network

   You can create one using the Internet Sharing feature on macOS or [linux-wifi-hotspot](https://github.com/lakinduakash/linux-wifi-hotspot) on, you guessed it, Linux if you prefer using another computer for it. 

   ### No apps on the Home Screen (iOS 8.0)
   This is a weird issue with older versions, the workaround is easy, however.

   After the first unlock after setup, when the apps are absent, open the Control Center (swipe up) and press the calculator icon. Once open, you can exit out of Calculator. This should fix the icons.

   ### Cydia is absent (on iPads)
   iPads have uicache issues with most jailbreaking tools. To open Cydia, enter `cydia://` in the address bar. 

 
## iOS 9.3 Support

Keybags do not unlock on iOS <=9.2.1 but they do on iOS 9.3

The issue we are having with iOS 9.3 currently is that there's a ton of sandbox errors during the boot process.

See [here](https://files.catbox.moe/wn83g9.mp4) for a video example of why we need sandbox patches for iOS 9

Once we have sandbox patched out properly on iOS 9.3, downgrading to it should work properly.

## Quirks

Passcode & TouchID do not work. If the device ever asks you for a passcode, it will normally accept anything as the passcode due to an unfixable issue.

If you lock the screen while the phone is on, it will cause a deep sleep bug which causes the phone to be frozen at a black screen until you force reboot the device. Check the Troubleshooting section for more information.

The App Store is broken on iOS 8 and 9

Encrypted WiFi networks do **not** work when tether downgrading with this tool. This is caused by an issue with SEP. Check the Troubleshooting section for more information

Respringing is currently broken on iOS 7.0.x. In order to respring on those versions you should open the wtfis app on the home screen and hit "go".

In order for tweaks to work on ios 7.1.x, you need to open the wtfis app on the home screen and hit "go". This patches the sandbox, allowing for tweak injection to work correctly.


## Requirements

macOS High Sierra to Catalina. The script only officially supports these versions.

Java 8 https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u262-b10/openlogic-openjdk-8u262-b10-mac-x64.pkg

Python. You can download it for macOS High Sierra from https://www.python.org/ftp/python/3.7.6/python-3.7.6-macosx10.6.pkg 

*Note: This should automatically be installed by the script.

pyimg4 just run `pip3 install pyimg4` before running the script. The script should do this automatically too

Intel Mac. Hackintoshes with AMD CPUs will **NOT** work with this.

Stable internet connection. Please don't try using this with dial up...

At least 20GB free on your device

USB Type-A port and Lightning cable. USB Type-C ports will **NOT** work with this.


Working iDevice: The script has to backup `apticket.der`, `sep-firmware.img4`, `Baseband`, and `keybags` from your device before you can downgrade to an older iOS version.

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
