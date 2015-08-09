<#
.SYNOPSIS

Finds snapshots ready to delete
.DESCRIPTION

Searches for snapshots older than a pre-configured time, or a time designated
in the snapshot name.
Snapshot names must start with ### Days or ### Hours for special retention
Example: 24d For support case 106
Example: 12 hour - Installing Windows Updates

      Author: Ben "The Slowest Zombie" Peterson
     Version: 1.0
Requirements: PowerShell 3.0, PowerCLI 5
.PARAMETER Report

Sends an email report of snapshots identified for removal
.PARAMETER Report

Sends an email report. Defaults to True
.PARAMETER RemoveSnapshots

Takes corrective action for expired snapshots
.EXAMPLE

 .\Audit-Snapshots
Gets all snapshots and deletes them where appropriate, then emails a report
.LINK

Author Homepage: http://benftw.com
#>

    Param(
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=0)]
        [switch]
        $Report = $false,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=1)]
        [switch]
        $RemoveSnapshots = $true
        )

if (!(Get-PSSnapin VMware.VimAutomation.Core -erroraction silentlycontinue)) { Add-PSSnapin VMware.VimAutomation.Core -ErrorAction Stop }

[string]$VMServer = ($global:DefaultVIServers | Select-Object -First 1).Name
$EmailSettings = @{
    To = "email@contoso.com"
    From = "email@contoso.com"
    Subject = "$VMServer Snapshot Audit" 
    SmtpServer = "mail.contoso.com"
    UseSsl = $true
    BodyAsHtml = $true
    }


$VMListDelete = $ActionList = @()
[string]$ExpireType = $null
$FilterList = "VEEAM BACKUP TEMPORARY SNAPSHOT"
$FilterStarts = "clone-temp-"
$DoNotDeleteString = "DND"
$DefaultExpirationHours = 48

$FilterRegexHours = '^\d+\s?[H]{1}'
$FilterRegexDays = '^\d+\s?[D]{1}'



$VMListRaw = Get-VM | Get-Snapshot # | Where-Object { ($_.Name -notin $FilterList) -and ($_.Name.StartsWith($DoNotDeleteString,"CurrentCultureIgnoreCase")) }

$VMListFiltered = $VMListRaw | Where-Object { $_.Name -in $FilterList -or $_.Name.StartsWith($FilterStarts) }
$VMListDoNotDelete = $VMListRaw | Where-Object { $_.Name.StartsWith($DoNotDeleteString,"CurrentCultureIgnoreCase") }

$VMList = $VMListRaw | Where-Object { $_ -notin $VMListFiltered -and $_ -notin $VMListDoNotDelete }


Foreach ($VM in $VMList) {
    #Reset variables
    $Expiration = 9999
    $ExpireType = "Invalid"

    #Identify snapshots with a custom expiration length
    if ($VM.Name -match $FilterRegexHours) { $Expiration = $VM.Name.ToLower().Split("h")[0]; $ExpireType = "Hours" }
    if ($VM.Name -match $FilterRegexDays)  { $Expiration = $VM.Name.ToLower().Split("d")[0]; $ExpireType = "Days" }

    #Determine the date a snapshot is expired
    Switch ($ExpireType)
        {
            "Hours" { $TimeOut = (Get-Date).AddHours(-$Expiration) }
            "Days"  { $TimeOut = (Get-Date).AddDays(-$Expiration) }
            default { $TimeOut = (Get-Date).AddHours(-$DefaultExpirationHours); $ExpireType = "Hours (Default)"; $Expiration = $DefaultExpirationHours }
        }

    #Build list of expired snapshots
    if ($VM.Created -lt $TimeOut) { 
        $ActionList += "Remove Snapshot: $($VM.VM) - Aged over "+$Expiration+$ExpireType + '<br>'
        $VMListDelete += $VM
        }
    }

#Remove Snapshots
if ($RemoveSnapshots) {
    $VMListDelete
    $VMListDelete | Remove-Snapshot -Confirm:$false -RunAsync
    }

#Reporting
if ($Report) {

$Header = @"
<style>
BODY{}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:thistle}
TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:palegoldenrod}
</style>
"@

    $VMListDelete_Report = $VMListDelete | ConvertTo-Html -Fragment -PreContent '<h2>Snapshots to Delete:</h2>' -Property VM,Name,Description,Created
    $VMListFiltered_Report = $VMListFiltered | ConvertTo-Html -Fragment -PreContent '<h2>Automatically Protected Snapshots:</h2>' -Property VM,Name,Description,Created
    $VMListDoNotDelete_Report = $VMListDoNotDelete | ConvertTo-Html -Fragment -PreContent '<h2>Manually Protected Snapshots:</h2>' -Property VM,Name,Description,Created
    $VMListAllOthers = $VMList | Where-Object { $_ -notin $VMListDelete -and $_ -notin $VMListFiltered -and $_ -notin $VMListDoNotDelete } | ConvertTo-Html -Fragment -PreContent '<h2>Non-Expired Snapshots:</h2>' -Property VM,Name,Description,Created
    $FullReport = $ActionList + $VMListDelete_Report + $VMListFiltered_Report + $VMListDoNotDelete_Report + $VMListAllOthers
    
    $EmailReport = ConvertTo-Html -Body $FullReport -Title "SnapShot Audit Report" -PreContent $Header | Out-String
    Write-Host "Sending Email"
    Send-MailMessage @EmailSettings -Body $EmailReport
    }