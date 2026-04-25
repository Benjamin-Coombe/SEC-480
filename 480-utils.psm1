#Requires -Modules VCF.PowerCLI
<#
.SYNOPSIS
    480-Utils PowerShell Module
.DESCRIPTION
    A utility module for VMware vSphere automation built across Milestones 5 and 6.
    Covers VM cloning, networking, start/stop control, and IP/MAC retrieval.
.NOTES
    Course: SYS480 / CYB480
    Milestones: 5 and 6
#>

# ============================================================
#  CONFIGURATION & CONNECTION
# ============================================================

<#
.SYNOPSIS
    Loads a JSON configuration file for the 480 environment.
.PARAMETER ConfigPath
    Path to the JSON config file. Defaults to ./480.conf.json
.OUTPUTS
    PSCustomObject with config values.
#>
function Get-480Config {
    param(
        [string]$ConfigPath = "./480.conf.json"
    )

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "[ERROR] Config file not found at: $ConfigPath" -ForegroundColor Red
        return $null
    }

    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-Host "[INFO] Config loaded from $ConfigPath" -ForegroundColor Cyan
        return $config
    }
    catch {
        Write-Host "[ERROR] Failed to parse config file: $_" -ForegroundColor Red
        return $null
    }
}

<#
.SYNOPSIS
    Connects to a vCenter or ESXi server.
.PARAMETER Server
    FQDN or IP of the vSphere server. Prompts if not provided.
.PARAMETER User
    Username for authentication. Prompts if not provided.
#>
function Connect-480Server {
    param(
        [string]$Server,
        [string]$User
    )

    if (-not $Server) { $Server = Read-Host "Enter vSphere server address" }
    if (-not $User)   { $User   = Read-Host "Enter username" }

    try {
        $conn = Connect-VIServer -Server $Server -User $User -Force
        Write-Host "[INFO] Connected to $Server as $User" -ForegroundColor Green
        return $conn
    }
    catch {
        Write-Host "[ERROR] Could not connect to $Server : $_" -ForegroundColor Red
        return $null
    }
}


# ============================================================
#  MILESTONE 5 — CLONING
# ============================================================

<#
.SYNOPSIS
    Creates a linked clone from the "Base" snapshot of a source VM.
.PARAMETER SourceVMName
    Name of the source VM to clone from. Prompts if not provided.
.PARAMETER CloneName
    Name of the new linked clone. Prompts if not provided.
.PARAMETER DatastoreName
    Target datastore name. Prompts if not provided.
.PARAMETER ESXiHost
    ESXi host where the clone will run. Prompts if not provided.
.PARAMETER FolderName
    Destination folder. Defaults to "Discovered virtual machine".
.PARAMETER SnapshotName
    Snapshot to link from. Defaults to "Base".
#>
function New-LinkedClone {
    param(
        [string]$SourceVMName,
        [string]$CloneName,
        [string]$DatastoreName,
        [string]$ESXiHost,
        [string]$FolderName    = "Discovered virtual machine",
        [string]$SnapshotName  = "Base"
    )

    if (-not $SourceVMName) { $SourceVMName  = Read-Host "Source VM name" }
    if (-not $CloneName)    { $CloneName     = Read-Host "New clone name" }
    if (-not $DatastoreName){ $DatastoreName = Read-Host "Datastore name" }
    if (-not $ESXiHost)     { $ESXiHost      = Read-Host "ESXi host" }

    # Validate source VM
    $sourceVM = Get-VM -Name $SourceVMName -ErrorAction SilentlyContinue
    if (-not $sourceVM) {
        Write-Host "[ERROR] Source VM '$SourceVMName' not found." -ForegroundColor Red
        return $null
    }

    # Validate snapshot
    $snapshot = Get-Snapshot -VM $sourceVM -Name $SnapshotName -ErrorAction SilentlyContinue
    if (-not $snapshot) {
        Write-Host "[ERROR] Snapshot '$SnapshotName' not found on '$SourceVMName'." -ForegroundColor Red
        return $null
    }

    # Validate datastore
    $datastore = Get-Datastore -Name $DatastoreName -ErrorAction SilentlyContinue
    if (-not $datastore) {
        Write-Host "[ERROR] Datastore '$DatastoreName' not found." -ForegroundColor Red
        return $null
    }

    # Validate ESXi host
    $vmhost = Get-VMHost -Name $ESXiHost -ErrorAction SilentlyContinue
    if (-not $vmhost) {
        Write-Host "[ERROR] ESXi host '$ESXiHost' not found." -ForegroundColor Red
        return $null
    }

    # Validate folder (non-fatal — falls back to root)
    $folder = Get-Folder -Name $FolderName -ErrorAction SilentlyContinue
    if (-not $folder) {
        Write-Host "[WARN] Folder '$FolderName' not found. Using default folder." -ForegroundColor Yellow
        $folder = $null
    }

    # Check for duplicate name
    $existing = Get-VM -Name $CloneName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "[ERROR] A VM named '$CloneName' already exists." -ForegroundColor Red
        return $null
    }

    try {
        Write-Host "[INFO] Creating linked clone '$CloneName' from '$SourceVMName'..." -ForegroundColor Cyan
        $cloneSpec = @{
            Name            = $CloneName
            VM              = $sourceVM
            LinkedClone     = $true
            ReferenceSnapshot = $snapshot
            Datastore       = $datastore
            VMHost          = $vmhost
        }
        if ($folder) { $cloneSpec["Location"] = $folder }

        $newVM = New-VM @cloneSpec
        Write-Host "[SUCCESS] Linked clone '$CloneName' created." -ForegroundColor Green
        return $newVM
    }
    catch {
        Write-Host "[ERROR] Failed to create linked clone: $_" -ForegroundColor Red
        return $null
    }
}

<#
.SYNOPSIS
    Creates a full clone from the "Base" snapshot of a source VM.
    Internally creates a temporary linked clone, then clones that to a full VM,
    then removes the temporary linked clone.
.PARAMETER SourceVMName
    Name of the source VM. Prompts if not provided.
.PARAMETER CloneName
    Name of the new full clone. Prompts if not provided.
.PARAMETER DatastoreName
    Target datastore. Prompts if not provided.
.PARAMETER ESXiHost
    ESXi host where the clone will run. Prompts if not provided.
.PARAMETER FolderName
    Destination folder. Defaults to "Discovered virtual machine".
.PARAMETER SnapshotName
    Snapshot to clone from. Defaults to "Base".
#>
function New-FullClone {
    param(
        [string]$SourceVMName,
        [string]$CloneName,
        [string]$DatastoreName,
        [string]$ESXiHost,
        [string]$FolderName   = "Discovered virtual machine",
        [string]$SnapshotName = "Base"
    )

    if (-not $SourceVMName) { $SourceVMName  = Read-Host "Source VM name" }
    if (-not $CloneName)    { $CloneName     = Read-Host "New full clone name" }
    if (-not $DatastoreName){ $DatastoreName = Read-Host "Datastore name" }
    if (-not $ESXiHost)     { $ESXiHost      = Read-Host "ESXi host" }

    $tempName = "$CloneName-temp-linked"
    Write-Host "[INFO] Creating intermediate linked clone '$tempName'..." -ForegroundColor Cyan

    $linked = New-LinkedClone `
        -SourceVMName $SourceVMName `
        -CloneName    $tempName `
        -DatastoreName $DatastoreName `
        -ESXiHost     $ESXiHost `
        -FolderName   $FolderName `
        -SnapshotName $SnapshotName

    if (-not $linked) {
        Write-Host "[ERROR] Intermediate linked clone failed. Aborting full clone." -ForegroundColor Red
        return $null
    }

    # Create a snapshot on the linked clone to allow full clone
    $tempSnap = New-Snapshot -VM $linked -Name "BaseForFullClone" -ErrorAction SilentlyContinue

    try {
        $datastore = Get-Datastore -Name $DatastoreName
        $vmhost    = Get-VMHost    -Name $ESXiHost
        $folder    = Get-Folder    -Name $FolderName -ErrorAction SilentlyContinue

        Write-Host "[INFO] Cloning full VM '$CloneName' from temporary linked clone..." -ForegroundColor Cyan
        $cloneSpec = @{
            Name      = $CloneName
            VM        = $linked
            Datastore = $datastore
            VMHost    = $vmhost
        }
        if ($folder) { $cloneSpec["Location"] = $folder }

        $fullVM = New-VM @cloneSpec
        Write-Host "[SUCCESS] Full clone '$CloneName' created." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Full clone creation failed: $_" -ForegroundColor Red
        $fullVM = $null
    }
    finally {
        Write-Host "[INFO] Removing temporary linked clone '$tempName'..." -ForegroundColor Cyan
        Remove-VM -VM $linked -DeletePermanently -Confirm:$false -ErrorAction SilentlyContinue
    }

    return $fullVM
}


# ============================================================
#  MILESTONE 6.1 — NETWORKING UTILITIES
# ============================================================

<#
.SYNOPSIS
    Creates a new Virtual Switch and an associated Port Group on a given ESXi host.
.PARAMETER VMHostName
    Name of the ESXi host. Prompts if not provided.
.PARAMETER SwitchName
    Name of the new vSwitch. Prompts if not provided.
.PARAMETER PortGroupName
    Name of the new Port Group. Prompts if not provided.
.PARAMETER NumPorts
    Number of ports for the vSwitch. Defaults to 8.
#>
function New-Network {
    param(
        [string]$VMHostName,
        [string]$SwitchName,
        [string]$PortGroupName,
        [int]   $NumPorts = 8
    )

    if (-not $VMHostName)    { $VMHostName    = Read-Host "ESXi host name" }
    if (-not $SwitchName)    { $SwitchName    = Read-Host "Virtual switch name" }
    if (-not $PortGroupName) { $PortGroupName = Read-Host "Port group name" }

    $vmhost = Get-VMHost -Name $VMHostName -ErrorAction SilentlyContinue
    if (-not $vmhost) {
        Write-Host "[ERROR] ESXi host '$VMHostName' not found." -ForegroundColor Red
        return $null
    }

    # Create vSwitch
    $existingSwitch = Get-VirtualSwitch -VMHost $vmhost -Name $SwitchName -ErrorAction SilentlyContinue
    if ($existingSwitch) {
        Write-Host "[WARN] vSwitch '$SwitchName' already exists on '$VMHostName'. Skipping creation." -ForegroundColor Yellow
        $vswitch = $existingSwitch
    }
    else {
        try {
            $vswitch = New-VirtualSwitch -VMHost $vmhost -Name $SwitchName -NumPorts $NumPorts
            Write-Host "[SUCCESS] Created vSwitch '$SwitchName' on '$VMHostName'." -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to create vSwitch: $_" -ForegroundColor Red
            return $null
        }
    }

    # Create Port Group
    $existingPG = Get-VirtualPortGroup -VMHost $vmhost -Name $PortGroupName -ErrorAction SilentlyContinue
    if ($existingPG) {
        Write-Host "[WARN] Port group '$PortGroupName' already exists. Skipping creation." -ForegroundColor Yellow
    }
    else {
        try {
            $pg = New-VirtualPortGroup -VirtualSwitch $vswitch -Name $PortGroupName
            Write-Host "[SUCCESS] Created port group '$PortGroupName' on switch '$SwitchName'." -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to create port group: $_" -ForegroundColor Red
            return $null
        }
    }

    return $vswitch
}

<#
.SYNOPSIS
    Returns the IP address and MAC address of the first (or specified) network adapter of a VM.
.PARAMETER VMName
    Name of the VM. Prompts if not provided.
.PARAMETER AdapterIndex
    Index of the adapter to query. Defaults to 0 (first adapter).
.OUTPUTS
    PSCustomObject with VMName, AdapterName, MacAddress, IPAddress.
#>
function Get-IP {
    param(
        [string]$VMName,
        [int]   $AdapterIndex = 0
    )

    if (-not $VMName) { $VMName = Read-Host "VM name" }

    $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "[ERROR] VM '$VMName' not found." -ForegroundColor Red
        return $null
    }

    $adapters = Get-NetworkAdapter -VM $vm
    if (-not $adapters -or $adapters.Count -eq 0) {
        Write-Host "[WARN] No network adapters found on '$VMName'." -ForegroundColor Yellow
        return $null
    }

    if ($AdapterIndex -ge $adapters.Count) {
        Write-Host "[WARN] Adapter index $AdapterIndex out of range. VM has $($adapters.Count) adapter(s). Using index 0." -ForegroundColor Yellow
        $AdapterIndex = 0
    }

    $adapter = $adapters[$AdapterIndex]
    $mac     = $adapter.MacAddress

     # Filter guest IPs to IPv4 only (exclude IPv6 addresses)
     $allIPs = $vm.Guest.IPAddress
     $ipv4   = $allIPs | Where-Object {
         $_ -match '^(\d{1,3}\.){3}\d{1,3}$'
     }
        $ipv4Address = if ($ipv4) { $ipv4[0] } else { "N/A (no IPv4 or Tools offline)" }

    # Pull IP from guest info
    $ipList = $vm.Guest.IPAddress
    $ip     = if ($ipList -and $ipList.Count -gt $AdapterIndex) { $ipList[$AdapterIndex] } `
              elseif ($ipList -and $ipList.Count -gt 0)         { $ipList[0] }             `
              else                                               { "N/A (VM may be off or VMware Tools not running)" }

    $result = [PSCustomObject]@{
        VMName      = $VMName
        AdapterName = $adapter.Name
        MacAddress  = $mac
        IPv4Address   = $ip
    }

    Write-Host ""
    Write-Host "  VM          : $($result.VMName)"      -ForegroundColor Cyan
    Write-Host "  Adapter     : $($result.AdapterName)" -ForegroundColor Cyan
    Write-Host "  MAC Address : $($result.MacAddress)"  -ForegroundColor Cyan
    Write-Host "  IP Address  : $($result.IPAddress)"   -ForegroundColor Cyan
    Write-Host ""

    return $result
}


# ============================================================
#  MILESTONE 6.2 — VM POWER CONTROL & NETWORK ASSIGNMENT
# ============================================================

<#
.SYNOPSIS
    Starts one or more VMs by name.
.PARAMETER VMNames
    Array of VM names to start. Prompts for a single name if not provided.
.PARAMETER WaitForTools
    If specified, waits until VMware Tools reports ready.
#>
function Start-480VM {
    param(
        [string[]]$VMNames,
        [switch]  $WaitForTools
    )

    if (-not $VMNames -or $VMNames.Count -eq 0) {
        $input = Read-Host "VM name(s) to start (comma-separated)"
        $VMNames = $input -split "," | ForEach-Object { $_.Trim() }
    }

    foreach ($name in $VMNames) {
        $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
        if (-not $vm) {
            Write-Host "[ERROR] VM '$name' not found. Skipping." -ForegroundColor Red
            continue
        }

        if ($vm.PowerState -eq "PoweredOn") {
            Write-Host "[WARN] VM '$name' is already powered on." -ForegroundColor Yellow
            continue
        }

        try {
            Start-VM -VM $vm -Confirm:$false | Out-Null
            Write-Host "[SUCCESS] Started '$name'." -ForegroundColor Green

            if ($WaitForTools) {
                Write-Host "[INFO] Waiting for VMware Tools on '$name'..." -ForegroundColor Cyan
                Wait-Tools -VM $vm -TimeoutSeconds 120 | Out-Null
                Write-Host "[INFO] VMware Tools ready on '$name'." -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "[ERROR] Failed to start '$name': $_" -ForegroundColor Red
        }
    }
}

<#
.SYNOPSIS
    Stops (powers off) one or more VMs by name.
.PARAMETER VMNames
    Array of VM names to stop. Prompts for a single name if not provided.
.PARAMETER Force
    If specified, performs a hard power-off instead of graceful shutdown via Guest OS.
#>
function Stop-480VM {
    param(
        [string[]]$VMNames,
        [switch]  $Force
    )

    if (-not $VMNames -or $VMNames.Count -eq 0) {
        $input = Read-Host "VM name(s) to stop (comma-separated)"
        $VMNames = $input -split "," | ForEach-Object { $_.Trim() }
    }

    foreach ($name in $VMNames) {
        $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
        if (-not $vm) {
            Write-Host "[ERROR] VM '$name' not found. Skipping." -ForegroundColor Red
            continue
        }

        if ($vm.PowerState -eq "PoweredOff") {
            Write-Host "[WARN] VM '$name' is already powered off." -ForegroundColor Yellow
            continue
        }

        try {
            if ($Force) {
                Stop-VM -VM $vm -Confirm:$false | Out-Null
                Write-Host "[SUCCESS] Hard powered off '$name'." -ForegroundColor Green
            }
            else {
                Shutdown-VMGuest -VM $vm -Confirm:$false | Out-Null
                Write-Host "[SUCCESS] Graceful shutdown initiated on '$name'." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "[ERROR] Failed to stop '$name': $_" -ForegroundColor Red
        }
    }
}

<#
.SYNOPSIS
    Sets the network (port group) on a specific network adapter of a VM.
.PARAMETER VMName
    Name of the target VM. Prompts if not provided.
.PARAMETER NetworkName
    Name of the port group / virtual network to assign. Prompts if not provided.
.PARAMETER AdapterIndex
    Index of the adapter to reconfigure (0-based). Defaults to 0.
    Pass -1 to iterate and set all adapters interactively.
.EXAMPLE
    # Set eth1 (adapter index 1) on the blue firewall to "blue-network"
    Set-Network -VMName "blueX-fw" -NetworkName "blue-network" -AdapterIndex 1
#>
function Set-Network {
    param(
        [string]$VMName,
        [string]$NetworkName,
        [int]   $AdapterIndex = 0
    )

    if (-not $VMName)      { $VMName      = Read-Host "VM name" }
    if (-not $NetworkName) { $NetworkName = Read-Host "Network / Port group name" }

    $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "[ERROR] VM '$VMName' not found." -ForegroundColor Red
        return $null
    }

    $network = Get-VirtualNetwork -Name $NetworkName -ErrorAction SilentlyContinue
    if (-not $network) {
        Write-Host "[ERROR] Network '$NetworkName' not found." -ForegroundColor Red
        return $null
    }

    $adapters = Get-NetworkAdapter -VM $vm
    if (-not $adapters -or $adapters.Count -eq 0) {
        Write-Host "[ERROR] No network adapters on '$VMName'." -ForegroundColor Red
        return $null
    }

    # If AdapterIndex is -1, loop through all adapters interactively
    if ($AdapterIndex -eq -1) {
        for ($i = 0; $i -lt $adapters.Count; $i++) {
            $adapter = $adapters[$i]
            $choice  = Read-Host "Set adapter $i ('$($adapter.Name)', currently '$($adapter.NetworkName)') to '$NetworkName'? [y/N]"
            if ($choice -match "^[Yy]") {
                try {
                    Set-NetworkAdapter -NetworkAdapter $adapter -NetworkName $NetworkName -Confirm:$false | Out-Null
                    Write-Host "[SUCCESS] Adapter $i on '$VMName' set to '$NetworkName'." -ForegroundColor Green
                }
                catch {
                    Write-Host "[ERROR] Failed to set adapter $i : $_" -ForegroundColor Red
                }
            }
        }
        return
    }

    # Single adapter by index
    if ($AdapterIndex -ge $adapters.Count) {
        Write-Host "[ERROR] Adapter index $AdapterIndex is out of range. VM has $($adapters.Count) adapter(s)." -ForegroundColor Red
        return $null
    }

    $adapter = $adapters[$AdapterIndex]
    try {
        Set-NetworkAdapter -NetworkAdapter $adapter -NetworkName $NetworkName -Confirm:$false | Out-Null
        Write-Host "[SUCCESS] Adapter '$($adapter.Name)' (index $AdapterIndex) on '$VMName' set to '$NetworkName'." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to set network adapter: $_" -ForegroundColor Red
    }
}


# ============================================================
#  MODULE EXPORT
# ============================================================

Export-ModuleMember -Function @(
    # Config / Connection
    'Get-480Config'
    'Connect-480Server'

    # Milestone 5 — Cloning
    'New-LinkedClone'
    'New-FullClone'

    # Milestone 6.1 — Networking
    'New-Network'
    'Get-IP'

    # Milestone 6.2 — Power & Network Control
    'Start-480VM'
    'Stop-480VM'
    'Set-Network'
)
