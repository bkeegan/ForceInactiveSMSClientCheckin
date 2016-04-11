<# 
.SYNOPSIS 
	Forces a manual machine policy retrieval of SMS clients that report no activity.
.DESCRIPTION 
	Forces a manual machine policy retrieval of SMS clients that report no activity. Windows Clients only.
	Requires installation of SCCM client and latest SCCM cmdlets
.NOTES 
    File Name  : ForceInactiveSMSClientCheckin.ps1
    Author     : Brenton keegan - brenton.keegan@gmail.com 
    Licenced under GPLv3  
.LINK 
	https://github.com/bkeegan/ForceInactiveSMSClientCheckin
    License: http://www.gnu.org/copyleft/gpl.html
	Cmdlet Library: https://www.microsoft.com/en-us/download/details.aspx?id=46681
.EXAMPLE 
	ForceInactiveSMSClientCheckin -s "SiteCode" -srv "sms.contoso.com" -to "reports@contoso.com" -from "reports@contoso.com" -smtp "mail.contoso.com"

#> 

#imports
import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"


Function ForceInactiveSMSClientCheckin
{
[cmdletbinding()]
	Param
	(
		[parameter(Mandatory=$true)]
		[alias("s")]
		[string]$smsSiteCode,
		
		[parameter(Mandatory=$true)]
		[alias("srv")]
		[string]$smsSiteServer,
		
		[parameter(Mandatory=$true)]
		[alias("To")]
		[string]$emailRecipient,
		
		[parameter(Mandatory=$true)]
		[alias("From")]
		[string]$emailSender,
		
		[parameter(Mandatory=$true)]
		[alias("smtp")]
		[string]$emailServer,
		
		[parameter(Mandatory=$false)]
		[alias("Subject")]
		[string]$emailSubject="SMS Client Report",
		
		[parameter(Mandatory=$false)]
		[alias("body")]
		[string]$emailBody="SMS Client Report - See Attachment"
	)
	
	#variable init
	$smsPathLocation = "$smsSiteCode" + ":\" #name os PSDrive to set location to to issue SCCM cmdlets
	#if the PSdrive does not exist with the sitecode, create it (this may occur if the script is running as NT Authority\System)
	If(!(Get-PSDrive | where {$_.Name -eq $smsSiteCode}))
	{
		New-PSDrive -Name $smsSiteCode -PSProvider "CMSite" -root $smsSiteServer
	}
	
	Set-Location $smsPathLocation #set location of SMS Site
	[string]$dateStamp = Get-Date -UFormat "%Y%m%d_%H%M%S" #timestamp for naming report
	$tempFolder = get-item env:temp #temp folder
	$successfulComputers = @() #store list of successfully updates computers - used to recheck after
	$sccmCheckinResults = new-object 'system.collections.generic.dictionary[string,string]'	#dictionary object to store results

	#get sccm devices which have "Inactive" for "ClientActivity". Only selects Windows clients (ClientType = 1)
	$inactiveDevices = Get-CMDevice | where {$_.ClientActiveStatus -eq 0 -and $_.ClientType -eq 1} | Select Name
	Foreach ($inactiveDevice in $inactiveDevices)
	{
		$computerName = $inactiveDevice.Name
		If(Test-Connection $computerName -ErrorAction SilentlyContinue)
		{
			$success = $true
			Try
			{
				#attempt to connect to SMS WMI and issue RequestMachinePolicy command
				$wmiPath = "\\" + $computerName + "\root\ccm:SMS_Client"
				$smsWMI = [wmiclass] $wmiPath 
				[void]$smsWMI.RequestMachinePolicy()
			}
			Catch
			{
				#if above produces an error, logged in dictionary object here.
				$success = $false
				$sccmCheckinResults.Add($computerName,"WMI Error")
			}
			if($success)
			{
				#if successful, logged to dictionary object, also store name in array to check again after complete
				$successfulComputers += $computerName
				$sccmCheckinResults.Add($computerName,"Success")
			}
		}
		else
		{
			#record unpingable computers
			$sccmCheckinResults.Add($computerName,"Unpingable")
		}
	}
	
	#wait 5 minutes before re-check. Assume endpoint clients need a few minutes to become flagged as active after issuing a manual check. 
	sleep 300
	#check computers that successfully executed a Machine Policy Retrieval. If still flagged as inactive after 5 minutes there may be a problem with the SCCM client.
	foreach($successfulComputer in $successfulComputers)
	{
		$sccmDevice = Get-CMDevice -name $successfulComputer
		if($sccmDevice.ClientActiveStatus -eq 0)
		{
			$sccmCheckinResults.Remove($successfulComputer)
			$sccmCheckinResults.Add($successfulComputer,"Inactive After Checkin")
		}
	}
	
	#generate HTML Report
	$sccmCheckinResults.GetEnumerator() | Sort-Object -property Value | ConvertTo-HTML | Out-File "$($tempFolder.value)\$dateStamp-SCCMClientReport.html"
	#send email to specified recipient and attach HTML report
	Send-MailMessage -To $emailRecipient -Subject $emailSubject -smtpServer $emailServer -From $emailSender -body $emailBody -Attachments "$($tempFolder.value)\$dateStamp-SCCMClientReport.html"
}
