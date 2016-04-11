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
	ForceInactiveSMSClientCheckin -s "SiteCode" -to "reports@contoso.com" -from "reports@contoso.com" -smtp "mail.contoso.com"

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
		[string]$emailSubject="SMS Client Reportt",
		
		[parameter(Mandatory=$false)]
		[alias("body")]
		[string]$emailBody="SMS Client Report - See Attachment"
	)
	
	$smsPathLocation = "$smsSiteCode" + ":\"
	Set-Location $smsPathLocation
	[string]$dateStamp = Get-Date -UFormat "%Y%m%d_%H%M%S"
	$tempFolder = get-item env:temp
	$sccmCheckinResults = new-object 'system.collections.generic.dictionary[string,string]'	

	$inactiveDevices = Get-CMDevice | where {$_.ClientActiveStatus -eq 0 -and $_.ClientType -eq 1} | Select Name
	Foreach ($inactiveDevice in $inactiveDevices)
	{
		$computerName = $inactiveDevice.Name
		$errorAction 
		If(Test-Connection $computerName -ErrorAction SilentlyContinue)
		{
			$success = $true
			Try
			{
				$wmiPath = "\\" + $computerName + "\root\ccm:SMS_Client"
				$smsWMI = [wmiclass] $wmiPath 
				[void]$smsWMI.RequestMachinePolicy()
			}
			Catch
			{
				$success = $false
				$sccmCheckinResults.Add($computerName,"WMI Error")
			}
			if($success)
			{
				$sccmCheckinResults.Add($computerName,"Success")
			}
		}
		else
		{
			$sccmCheckinResults.Add($computerName,"Unpingable")
		}
	}
	
	#wait 5 minutes before re-check
	sleep 300
	
	$sccmResults = $sccmCheckinResults.GetEnumerator()
	foreach($sccmResult in $sccmResults)
	{
		if($sccmResult.Value -eq "Success")
		{
			$sccmDevice = Get-CMDevice -name $sccmResult.Key
			if($sccmDevice.ClientActiveStatus -eq 0)
			{
				$sccmCheckinResults.Remove($sccmResult.Key)
				$sccmCheckinResults.Add($sccmResult.Key,"Inactive After Checkin")
			}
		}
	}
	
	$sccmCheckinResults.GetEnumerator() | Sort-Object -property Value | ConvertTo-HTML | Out-File "$($tempFolder.value)\$dateStamp-SCCMClientReport.html"
	Send-MailMessage -To $emailRecipient -Subject $emailSubject -smtpServer $emailServer -From $emailSender -body $emailBody -Attachments "$($tempFolder.value)\$dateStamp-SCCMClientReport.html"
}
