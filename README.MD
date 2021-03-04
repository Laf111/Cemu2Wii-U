# SyncSaves_Cemu-WiiU : automated FTP interface to sync saves between WiiU and CEMU


Use the scripts of "[BatchFw](https://github.com/Laf111/CEMU-Batch-Framework)" and remove all the dependencies to the project.

**ATTENTION : contrary to BatchFw that allows multiple saves per user, only syncrhonize mode is implemented. You cannot keep both saves (CEMU and Wii-U ones)**


4 main scripts (3 adapted from BatchFw):

- **changeAccount.bat** : change the account (800000X) used 
- **getOnlineFiles.bat** : get and save under .\WiiuFiles\OnlineFiles online files needed for CEMU for all users found
  (except opt.bin and seeprom.bin that you need to dump manually from the Wii-U using NANDDUMPER)
- **importWiiuSaves.bat** : get saves from the Wii-U for games that exist in MLC_FOLDER and on the Wii-U
  Backup existing save then replace files
- **exportSavesToWiiu.bat** : inject saves to the Wii-U for games that exist in MLC_FOLDER and on the Wii-U
  Backup existing save then replace files  
  Use powershell instead of Rar.exe to compress files (backups)
  Remove the first column in the files created by scanWiiU.bat (game's title in BatchFw)


