# SyncSaves_Cemu-WiiU

#
SyncSaves_Cemu-WiiU is an **automated FTP interface** between the WiiU and CEMU (a mlc01 folder : MLC_FOLDER)

- dump wii-u onlines files needed fo CEMU (for all acounts : Mii head, Friends list, certificates and account.dat). You'll only have to dump opt.bin and seeprom.bin using NANDDUMPER manually.

- import Wii-U saves to a MLC folder

- export CEMU saves to Wii-U

- prepare a SD card for the Wii-U containing HBL and essentials 'legal' apps

- en/disable remotely the firmware auto-update feature on the Wii-U

- change the account (8000000X) used (remane folders in a MLC_PATH)



It uses scripts adapted from [BatchFw](https://github.com/Laf111/CEMU-Batch-Framework) with more restrictions. 

SyncSaves_Cemu-WiiU does not have access to the settings.xml file of CEMU install since the input mlc folder could be an "external" one (not included in a CEMU install's folder and eventually shared by multiple CEMU's versions)

So you'll have to define manually (if it's not already done) Wii-U accounts (and user's name) in CEMU configuration (General Settings / Accounts tab).

Every import or export process, backups of saves are done under ./WiiuFiles/Backups/\%DATE\%\_[CEMU|WiiU]\_saves and can be restored (to Wii-U or CEMU side).


#
**Version of CEMU supported >= 1.15.19 (supporting Wii-U accounts handling) !**
#

#
Install (optional):

Launch setup.bat to create shortcuts on your desktop (or any location).

#
Scripts available to user :

- **createWiiuSDcard.bat** : format (using Fat32Format.exe) an prepare a SD card for the Wii-U containing HBL and essentials apps
- **ftpSetWiiuFirmwareUpdateMode.bat** : en/disable remotely the firmware auto-update feature on the Wii-U
- **getOnlineFiles.bat** : get and save under .\WiiuFiles\OnlineFiles online files needed for CEMU for all users found
  (except opt.bin and seeprom.bin that you need to dump manually from the Wii-U using NANDDUMPER)
- **importWiiuSaves.bat** : get saves from the Wii-U for games that also exist in MLC_FOLDER (backup existing CEMU saves before overwrite files)
- **exportSavesToWiiu.bat** : inject saves to the Wii-U for games that exist in MLC_FOLDER and on the Wii-U filesystem (backup existing Wii-U saves before overwrite files)
- **changeAccount.bat** : change the account (8000000X) used (remane folders in a MLC_PATH). So you can rename your existing CEMU accounts to match your Wii-U ones before if you want to synchronize your saves between CEMU and the Wii-U or if you want bypass the CEMU version limitation above with using only the 80000001 account (the only one supported on CEMU < 1.15.19).

TODO : 

- Check import/export scripts.

- **restoreBackup.bat** : change the account (8000000X) used (remane folders in a MLC_PATH). So you can rename your existing CEMU accounts to match your Wii-U ones 

# 
**IMPORTANT : if you get the files from the repository : use the script ./fixBatFiles.bat (used to produce a release) to force the ANSI encoding and remove trailing spaces in all files (this script also put files in read only) because GitHub will format all files from ANSI to UTF-8 and it might break silentlty some scripts.**
#
