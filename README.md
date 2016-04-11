# ForceInactiveSMSClientCheckin
ForceInactiveSMSClientCheckin is a maintenance script for System Center Configuration Manager (SCCM) agents. 
This script is designed to be executed from a SMS Site server or administrative workstation. It can be executed one time or on a reoccuring schedule. The goal of this script is to address the issue noticed in SCCM 2012 R2 where healthy clients stop reporting in to the SCCM server. It is uncertain what the percise cause of this behavior is, however in many cases it has been identified that a manual Machine Policy Retrieval resolves the issue. 

This script queries all SCCM devices which have a Client Activity status listed as "Inactive" and attempts to make a WMI connection to that workstation and issue a manual Machine Policy Retrieval. This script will then wait 5 minutes and any computers that the script successfully issued a manual Machine Policy Retrieval on, it will check the status again. 

The script will generate a basic HTML report listing machine names and results:

1. **Unpingable:** machine failed the "Test-Connection" cmdlet. Computer may be offline or no longer exists.
2. **WMI Error:** The WMI command returned an error. May indicate a health issue with the computer
3. **Inactive After Checkin:** The WMI command was initially successful, but a check again after 5 minutes shows that the Client Activity status is Inactive. May be a health issue with the client
4. **Success:** WMI Command was issued successfully and the client now reports an active status.
