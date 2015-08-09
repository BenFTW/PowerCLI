Function Enable-MemHotAdd($vm){
    $vmview = Get-vm $vm | Get-View 
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="mem.hotadd"
    $extra.Value="true"
    $vmConfigSpec.extraconfig += $extra

    $vmview.ReconfigVM($vmConfigSpec)
}

Function Enable-vCpuHotAdd($vm){
    $vmview = Get-vm $vm | Get-View 
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="vcpu.hotadd"
    $extra.Value="true"
    $vmConfigSpec.extraconfig += $extra

    $vmview.ReconfigVM($vmConfigSpec)
}


Function Disable-MemHotAdd($vm){
    $vmview = Get-vm $vm | Get-View 
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="mem.hotadd"
    $extra.Value="false"
    $vmConfigSpec.extraconfig += $extra

    $vmview.ReconfigVM($vmConfigSpec)
}

Function Disable-vCpuHotAdd($vm){
    $vmview = Get-vm $vm | Get-View 
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="vcpu.hotadd"
    $extra.Value="false"
    $vmConfigSpec.extraconfig += $extra

    $vmview.ReconfigVM($vmConfigSpec)
}

Function Off-VM
 {
 <#
.SYNOPSIS

Initiates a VMware VM Guest shutdown and verifies the system is powered off
.DESCRIPTION

Uses the Shutdown-VM cmdlet to initiate a guest shutdown, then refreshes the status with
the Get-VM cmdlet

      Author: Ben "The Slowest Zombie" Peterson
     Version: 1.0
Requirements: PowerShell 3.0
.PARAMETER Name

Identifies one or more virtual machines to power off.
.PARAMETER WaitCycles

The number of times to refresh the virtual machine state before giving up
.PARAMETER WaitTimer

The number of seconds to wait between each refresh of the virtual machine state
.EXAMPLE

 .\Off-VM Virtual05
Shuts down a virtual machine named Virtual05.
.EXAMPLE

Get-VM Virtual* | Off-VM
Shuts down all virtual machines whose names begin with Virtual.
This seems to be non-functional
.EXAMPLE

Off-VM Virtual02,Virtual03 -WaitCycles 1 -WaitTimer 30
Shuts down two virtual machines. Only one status refresh is attempted after 30 seconds.
.LINK

Author Homepage: http://slowestzombie.net/it_lives
#>

    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [String[]]
        $Name,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=1)]
        [ValidateRange(1,64)]
        [Int]
        $WaitCycles = 5,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=2)]
        [ValidateRange(0,64)]
        [Int]
        $WaitTimer = 1
        )

    foreach ($VM in $Name) {
        Write-Verbose $VM": Selected"
        $VMProper = Get-VM $VM
        switch (($VMProper).PowerState)
            {
                "PoweredOn" { 
                    Write-Verbose $VM": Powered On"
                    $VMProper | Shutdown-VMGuest -Confirm:$false | Out-Null
                    #Write-Host $VM": Waiting for shutdown to complete" -NoNewline
                    $i = $WaitCycles
                    do {
                        Write-Progress -Activity $VM": Waiting for shutdown to complete" -Status "Refreshing status $i more times" -PercentComplete ( (($WaitCycles - $i) / $WaitCycles) * 100 )
                        Start-Sleep -Seconds $WaitTimer
                        $status = Get-VM $VM
                        $i--
                        } #do
                    until ($status.PowerState -eq "PoweredOff" -or $i -eq 0)
                    Write-Progress -Activity $VM": Waiting for shutdown to complete" -Status "Refreshing status $i more times" -PercentComplete 100 -Completed
                    if ($status.PowerState -ne "PoweredOff") {
                        Write-Error $VM": Did not power off in the expected time" -ErrorAction Continue
                        } else {
                        $Status
                        Write-Verbose $VM": Powered Off"
                        } #if
                    } #PoweredOn
                "PoweredOff" {
                    Write-Verbose $VM": Powered Off"
                    } #PoweredOff
                default {
                    Write-Warning $VM": Not found or in unexpected state"
                    } #default
            } #switch
        } # Foreach

 } #function Off-VM

 Function Get-HotAdd () {
 Get-VM $vmlist | Get-View | Select Name, @{N="PowerState";E={(Get-VM $_.Name).PowerState}}, @{N="OperatingSystem";E={$_.Guest.GuestFullName}}, @{N="CpuHotAddEnabled";E={$_.Config.CpuHotAddEnabled}}, @{N="MemoryHotAddEnabled";E={$_.Config.MemoryHotAddEnabled}}
}

#List all VMs with name, OS, and Hot Add status
#Filter out incompatible OS and systems with Hot Add already enabled

$vmlist = Get-Content "C:\Users\Ben\Desktop\VMList.txt"


$HotaddStatus = Get-HotAdd | Where-Object {($_.OperatingSystem -in "Microsoft Windows Server 2003 (32-bit)", "Microsoft Windows Server 2008 R2 (64-bit)", "Microsoft Windows Server 2003 (64-bit)", "Microsoft Windows Server 2008 (64-bit)", "Microsoft Windows Server 2008 (32-bit)") -or !($_.OperatingSystem)} | Where-Object {$_.MemoryHotAddEnabled -eq $false}

$HotaddStatus | Foreach-object {
    [string]$VMtoChange = $($_.Name)
    $VMOriginalState = $($_.PowerState)

    if ($VMOriginalState -eq "PoweredOn") {
        Write-Output $VMtoChange": Shutting Down"
        Off-VM $VMtoChange -WaitTimer 10 -WaitCycles 9
        }
        
    Write-Output $VMtoChange": Enabling Memory HotAdd"
    Enable-MemHotAdd $VMtoChange
    
    if (($_.OperatingSystem -in "Microsoft Windows Server 2008 (64-bit)", "Microsoft Windows Server 2008 R2 (64-bit)") -or !($_.OperatingSystem)) {
        Write-Output $VMtoChange": Enabling CPU HotAdd"
        Enable-vCpuHotAdd $VMtoChange
        }

    if ($VMOriginalState -eq "PoweredOn") { 
        Write-Output $VMtoChange": Powereing On"
        Start-VM $VMtoChange | Out-Null
        }
    }

