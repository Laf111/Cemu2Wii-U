# SyncSaves_Cemu-WiiU

#
SyncSaves_Cemu-WiiU is an **automated FTP interface to sync saves** between the WiiU and CEMU (a mlc01 folder : MLC_FOLDER)


It uses scripts adapted from [BatchFw](https://github.com/Laf111/CEMU-Batch-Framework) with more restrictions. Contrary to BatchFw that allows multiple saves per user, only syncrhonize mode is implemented here. **You'll not be able to play using both saves (CEMU and Wii-U ones) on CEMU**

But there's another limitation (while waiting for CEMU to handle saves files as the wii-u does) : 

SyncSaves_Cemu-WiiU does not have access to the settings.xml file of CEMU install (where CEMU save game's stats).
And i dont want to do this since :
- it's done in BatchFw,
- and the mlc folder given could an external one (not included in CEMU's install)

**The last time played is computed using the current time. It means that games stats will be upated with the current time even if you do not play the game since you dumped it from your Wii-U. It results in false last time played when running the game on the WiiU.**

This limitation does not exist in BatchFw that get the game's stats from the settings.xml of CEMU. 

#
**Version of CEMU supported >= 1.15.19 (supporting Wii-U account handling) !**
#

4 main scripts (3 adapted from BatchFw):

- **changeAccount.bat** : change the account (8000000X) used (remane folders in a MLC_PATH). So you can rename your existing CEMU accounts to match your Wii-U ones before synchronizing or bypass the CEMU version limitation with using only the 80000001 account (the only one supported on CEMU < 1.15.19) or .
- **getOnlineFiles.bat** : get and save under .\WiiuFiles\OnlineFiles online files needed for CEMU for all users found
  (except opt.bin and seeprom.bin that you need to dump manually from the Wii-U using NANDDUMPER)
- **importWiiuSaves.bat** : get saves from the Wii-U for games that also exist in MLC_FOLDER (backup existing CEMU saves before overwrite files)
- **exportSavesToWiiu.bat** : inject saves to the Wii-U for games that exist in MLC_FOLDER and on the Wii-U filesystem (backup existing Wii-U saves before overwrite files)

TODO : 

- Check import/export scripts.
- Create an install.bat script to create shortcuts on the desktop fo the 4 scripts externalised
- Remember last configuration (to avoid browsing to the MLC folder systematically)
- add Wii-U scripts from BatchFw : createWiiuSDcard.bat + ftpSetWiiuFirmwareUpdateMode.bat 

# 
**IMPORTANT : if you get the files from the repository : use the script ./fixBatFiles.bat (used to produce a release) to force the ANSI encoding and remove trailing spaces in all files (this script also put files in read only) because GitHub will format all files from ANSI to UTF-8 and it might break silentlty some scripts.**
#
