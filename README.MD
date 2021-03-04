# SyncSaves_Cemu-WiiU

SyncSaves_Cemu-WiiU is an **automated FTP interface to sync saves** between the WiiU and CEMU (a mlc01 folder : MLC_FOLDER)



It uses scripts adapted from "[BatchFw](https://github.com/Laf111/CEMU-Batch-Framework)" with more restrictions. Contrary to BatchFw that allows multiple saves per user, only syncrhonize mode is implemented here. **You'll not be able to play using both saves (CEMU and Wii-U ones) on CEMU**

There's another limitation : 

With SyncSaves_Cemu-WiiU as it does not have access to the settings.xml file of CEMU install.
And i dont want to do this since :
- it's done in BatchFw,
- and the mlc folder given could an external one (not included in CEMU's install)

**the last time played is computed using the current time. It means that games stats will be upated with the current time even if you do not play the game since you dump-it from your Wii-U. It results in false last time played when running the game on the WiiU.**

This limitation does not exist in BatchFw that get the game's stats from the settings.xml of CEMU. 

4 main scripts (3 adapted from BatchFw):

- **changeAccount.bat** : change the account (800000X) used 
- **getOnlineFiles.bat** : get and save under .\WiiuFiles\OnlineFiles online files needed for CEMU for all users found
  (except opt.bin and seeprom.bin that you need to dump manually from the Wii-U using NANDDUMPER)
- **importWiiuSaves.bat** : get saves from the Wii-U for games that also exist in MLC_FOLDER (backup existing CEMU saves before overwrite files)
- **exportSavesToWiiu.bat** : inject saves to the Wii-U for games that exist in MLC_FOLDER and on the Wii-U filesystem (backup existing Wii-U saves before overwrite files)

