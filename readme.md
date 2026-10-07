      db                    mm                  `7MM"""YMM   db                                               `7MM  `7MM      `7MM"""Yp, `7MM                     `7MM      
     ;MM:                   MM                    MM    `7                                                      MM    MM        MM    Yb   MM                       MM      
    ,V^MM.    `7MM  `7MM  mmMMmm   ,pW"Wq.        MM   d   `7MM  `7Mb,od8  .gP"Ya  `7M'    ,A    `MF' ,6"Yb.    MM    MM        MM    dP   MM   ,pW"Wq.   ,p6"bo    MM  ,MP'
   ,M  `MM      MM    MM    MM    6W'   `Wb       MM""MM     MM    MM' "' ,M'   Yb   VA   ,VAA   ,V  8)   MM    MM    MM        MM"""bg.   MM  6W'   `Wb 6M'  OO    MM ;Y   
   AbmmmqMA     MM    MM    MM    8M     M8       MM   Y     MM    MM     8M""""""    VA ,V  VA ,V    ,pm9MM    MM    MM        MM    `Y   MM  8M     M8 8M         MM;Mm   
  A'     VML    MM    MM    MM    YA.   ,A9       MM         MM    MM     YM.    ,     VVV    VVV    8M   MM    MM    MM        MM    ,9   MM  YA.   ,A9 YM.    ,   MM `Mb. 
.AMA.   .AMMA.  `Mbod"YML.  `Mbmo  `Ybmd9'      .JMML.     .JMML..JMML.    `Mbmmd'      W      W     `Moo9^Yo..JMML..JMML.    .JMMmmmd9  .JMML. `Ybmd9'   YMbmd'  .JMML. YA.
                                                                                                                                                                            
                                                                                                                                                                            
AutoFirewallBlock searches for every .exe in the main directory of a program and in all of its subdirectories.
Each file found is blocked in the Windows Firewall, both incoming and outgoing communication.


Requirements

- Windows 8 / Server 2012 or newer (Windows PowerShell 5.1 is included)
- Administrator rights (the script asks for them automatically)


Installation

1. Extract AutoFirewallBlock to a location of your choice.
   autofirewallblock.bat and autofirewallblock.ps1 must stay in the same directory.


Block a program
1. Double-click autofirewallblock.bat and confirm the administrator prompt.
2. Choose [1] "Block a program folder".
3. Enter (or paste) the main directory of the program, e.g. C:\Program Files\SomeApp
   Paths with spaces and quotes are fine.
4. AutoFirewallBlock now makes sure the program is completely offline:
   - If the Windows Firewall is switched off for a network profile, it offers to switch it on
     (otherwise the rules have no effect there).
   - Folders with the same name in ProgramData, AppData or Program Files (x86) are listed.
     They often contain updaters, launchers or helpers - answer "y" to block them too.
   - Running processes of the program are shown and can be closed, so already open connections end.
5. Done. Running it again for the same folder replaces the old rules instead of creating duplicates.


After a program update
Updates can add new .exe files. Choose [4] "Re-scan blocked folders" (or run with -Refresh)
to block them as well.


Unblock a program
1. Start autofirewallblock.bat
2. Choose [2] "Unblock a program folder" and pick the folder from the list.

Rules created by older versions of AutoFirewallBlock (named "AFB_exe_..." / "AFB_dll_..." without a group)
can be removed with menu item [5].


Command line

  autofirewallblock.bat -Path "C:\Program Files\SomeApp"      block a folder
  autofirewallblock.bat -Path "C:\Program Files\SomeApp" -IncludeRelated -StopProcesses
                                    completely offline: also related folders, close running processes
  autofirewallblock.bat -Path "C:\Program Files\SomeApp" -IncludeDll
  autofirewallblock.bat -Refresh                               re-scan all blocked folders after updates
  autofirewallblock.bat -Unblock "C:\Program Files\SomeApp"   remove the rules of a folder
  autofirewallblock.bat -List                                  show all blocked folders


Notes

- The Windows Firewall filters network traffic by the process (.exe) that owns the connection.
  Rules for .dll files therefore normally have no effect; they are only created on request (-IncludeDll).
- A program can still reach the network through other programs it starts (e.g. it opens your web browser,
  or uses a Windows service). Those are not part of its folder and are not blocked.
- Drive roots (e.g. C:\) and the Windows folder are refused, so you cannot cut off your whole system by accident.
- All rules can also be found in wf.msc (Windows key + R, "wf.msc"). They are named "AFB_exe_<folder>_<n> (<file>)"
  and grouped as "AutoFirewallBlock: <folder>", so you can sort or filter by the "Group" column.






 ,,                   
*MM                   
 MM                   
 MM,dMMb.  `7M'   `MF'
 MM    `Mb   VA   ,V  
 MM     M8    VA ,V   
 MM.   ,M9     VVV    
 P^YbmdP'      ,V     
              ,V      
           OOb"   
                                             ,,                                                               
                                             ,,                                                                 ,,  
      db                    mm             `7MM                                  .g8""8q.                     `7MM  
     ;MM:                   MM               MM                                .dP'    `YM.                     MM  
    ,V^MM.    `7MMpMMMb.  mmMMmm   .gP"Ya    MM   ,pW"Wq.  `7MMpdMAo.  .gP"Ya  dM'      `MM `7M'    ,A    `MF'  MM  
   ,M  `MM      MM    MM    MM    ,M'   Yb   MM  6W'   `Wb   MM   `Wb ,M'   Yb MM        MM   VA   ,VAA   ,V    MM  
   AbmmmqMA     MM    MM    MM    8M""""""   MM  8M     M8   MM    M8 8M"""""" MM.      ,MP    VA ,V  VA ,V     MM  
  A'     VML    MM    MM    MM    YM.    ,   MM  YA.   ,A9   MM   ,AP YM.    , `Mb.    ,dP'     VVV    VVV      MM  
.AMA.   .AMMA..JMML  JMML.  `Mbmo  `Mbmmd' .JMML. `Ybmd9'    MMbmmd'   `Mbmmd'   `"bmmd"'        W      W     .JMML.
                                                             MM                                                     
                                                           .JMML.                                                   