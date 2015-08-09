<#
.SYNOPSIS

Gets time settings for ESXi hosts
.DESCRIPTION

Lists NTP configuration and current time for all reachable VM hosts

      Author: Ben "The Slowest Zombie" Peterson
     Version: 1.0
Requirements: PowerShell 3.0, PowerCLI 5
.LINK

Author Homepage: http://benftw.com
#>

$list = @()

foreach ( $vmhost in (Get-VMHost)) {
    $listitem = New-Object -TypeName psobject    
    [string]$vmhostname = $vmhost.name
    [string]$NTPStatus = ($vmhost | Get-VMHostService | Where-Object { $_.key -eq "ntpd" }).running
    [string]$NTPServer = $vmhost | Get-VMHostNtpServer

    get-view -ViewType HostSystem -Property Name, ConfigManager.DateTimeSystem -filter @{"Name" = "$vmhost"}| %{    
        #get host datetime system
        $dts = get-view $_.ConfigManager.DateTimeSystem
        $CurrentTime = $dts.QueryDateTime()
        }

    $listitem = [PSCustomObject]@{
            Name = $vmhostname
            NTPisRunning = $NTPStatus
            NTPServer = $NTPServer
            CurrentTime = $CurrentTime
            }
    $list += $listitem
    }

$list