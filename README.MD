# SyncSaves_Cemu-WiiU

**SyncSaves_Cemu-WiiU** is an automated FTP interface to sync saves between the WiiU and CEMU (a mlc01 folder : MLC_FOLDER)



It uses scripts adapted from "[BatchFw](https://github.com/Laf111/CEMU-Batch-Framework)" with more restrictions. Contrary to BatchFw that allows multiple saves per user, only syncrhonize mode is implemented here. **You'll not be able to play using both saves (CEMU and Wii-U ones) on CEMU**


4 main scripts (3 adapted from BatchFw):

- **changeAccount.bat** : change the account (800000X) used 
- **getOnlineFiles.bat** : get and save under .\WiiuFiles\OnlineFiles online files needed for CEMU for all users found
  (except opt.bin and seeprom.bin that you need to dump manually from the Wii-U using NANDDUMPER)
- **importWiiuSaves.bat** : get saves from the Wii-U for games that also exist in MLC_FOLDER (backup existing CEMU saves before overwrite files)
- **exportSavesToWiiu.bat** : inject saves to the Wii-U for games that exist in MLC_FOLDER and on the Wii-U filesystem (backup existing Wii-U saves before overwrite files)

