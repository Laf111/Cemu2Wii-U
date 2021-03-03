======================================================================================================
> SyncSaves_Cemu-WiiU : automated FTP interface to sync saves between WiiU and CEMU
======================================================================================================

Input Data is : MLC_FOLDER (mlc01 folder)

03/03/2021 V1 : (fork of the code of BatchFw V22-3)
    > Use the scripts of BatchFw and remove all the dependencies to the project.
    > 3 entry points 
        - getOnlineFiles.bat : get and save under .\WiiuFiles\OnlineFiles online files needed for CEMU for all users found
          (except opt.bin and seeprom.bin that you need to dump manually from the Wii-U using NANDDUMPER)
        - importWiiuSaves.bat : get saves from the Wii-U for games that exist in MLC_FOLDER and on the Wii-U
          Backup existing save then replace files
        - exportSavesToWiiu.bat : inject saves to the Wii-U for games that exist in MLC_FOLDER and on the Wii-U
          Backup existing save then replace files
      Use powershell instead of Rar.exe to compress files (backups)
      Remove the first column in the files created by scanWiiU.bat (game's title in BatchFw)
      
      In import/export scripts : 
        - remove the playing time support (for now CEMU does not use saveinfo.xml to save this information)
        - remove wiiuSaveMode = BOTH case, choices left to define Wii-U accounts to treat : "all", "select"
        - Get game's title from the <longname_en> node in meta/meta.xml (to remove Batch Wii-U title database dependency)
      
      
      
    > save the last configuration in ./lastConfiguration.txt (MLC_FOLDER path for now)
    > shortcut creation for the 3 main scrits?
    > exe encapsulation of batch code (create binary files of this project) with the script buildExe.bat

