
function Connect-ToESXi {
    $server = Read-Host "Enter the ESXi host (IP or hostname)"
    Connect-VIServer -Server $server
}


function New-Clone {
    $sourceVM  = Read-Host "Enter the name of the VM to clone"
    $cloneName = Read-Host "Enter a name for the new clone"
    $esxHost   = Read-Host "Enter the ESXi host to run the clone on"
    $datastore = Read-Host "Enter the datastore name"

    Write-Host ""
    Write-Host "Clone type:"
    Write-Host "  [1] Linked clone  (fast, shares the parent disk)"
    Write-Host "  [2] Full clone    (independent copy, good for live systems)"
    $choice = Read-Host "Enter 1 or 2"

    # Look up the source VM
    $vm = Get-VM -Name $sourceVM -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "ERROR: Could not find a VM named '$sourceVM'" -ForegroundColor Red
        return
    }

    # Look up the Base Snapshot
    $snapshot = Get-Snapshot -VM $vm -Name "Base" -ErrorAction SilentlyContinue
    if (-not $snapshot) {
        Write-Host "ERROR: No snapshot named 'Base' found on '$sourceVM'" -ForegroundColor Red
        return
    }

    # Look up the ESXi host
    $vmHost = Get-VMHost -Name $esxHost -ErrorAction SilentlyContinue
    if (-not $vmHost) {
        Write-Host "ERROR: Could not find ESXi host '$esxHost'" -ForegroundColor Red
        return
    }

    # Look up the datastore
    $ds = Get-Datastore -Name $datastore -ErrorAction SilentlyContinue
    if (-not $ds) {
        Write-Host "ERROR: Could not find datastore '$datastore'" -ForegroundColor Red
        return
    }

    if ($choice -eq "1") {
        Write-Host "Creating linked clone '$cloneName'..." -ForegroundColor Cyan
        New-VM -Name $cloneName -VM $vm -Snapshot $snapshot `
               -VMHost $vmHost -Datastore $ds -LinkedClone
        Write-Host "Done! Linked clone '$cloneName' created." -ForegroundColor Green

    } elseif ($choice -eq "2") {

        $tempName = "temp-clone-deleteme"

        Write-Host "Step 1 of 3: Creating temporary linked clone..." -ForegroundColor Cyan
        $tempVM = New-VM -Name $tempName -VM $vm -Snapshot $snapshot `
                         -VMHost $vmHost -Datastore $ds -LinkedClone

        Write-Host "Step 2 of 3: Converting to full clone '$cloneName'..." -ForegroundColor Cyan
        New-VM -Name $cloneName -VM $tempVM -VMHost $vmHost -Datastore $ds

        Write-Host "Step 3 of 3: Removing temporary clone..." -ForegroundColor Cyan
        Remove-VM -VM $tempVM -DeletePermanently -Confirm:$false

        Write-Host "Done! Full clone '$cloneName' created." -ForegroundColor Green

    } else {
        Write-Host "ERROR: Please enter 1 or 2." -ForegroundColor Red
    }
}

# ── Start a VM ───────────────────────────────────────────────────────────────

function Start-NamedVM {
    $vmName = Read-Host "Enter the VM name to start"

    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "ERROR: Could not find a VM named '$vmName'" -ForegroundColor Red
        return
    }

    if ($vm.PowerState -eq "PoweredOn") {
        Write-Host "'$vmName' is already running." -ForegroundColor Yellow
        return
    }

    Write-Host "Starting '$vmName'..." -ForegroundColor Cyan
    Start-VM -VM $vm
    Write-Host "'$vmName' is now powered on." -ForegroundColor Green
}

# ── Stop a VM ────────────────────────────────────────────────────────────────

function Stop-NamedVM {
    $vmName = Read-Host "Enter the VM name to stop"

    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "ERROR: Could not find a VM named '$vmName'" -ForegroundColor Red
        return
    }

    if ($vm.PowerState -eq "PoweredOff") {
        Write-Host "'$vmName' is already powered off." -ForegroundColor Yellow
        return
    }

    Write-Host "Stopping '$vmName'..." -ForegroundColor Cyan
    Stop-VM -VM $vm -Confirm:$false
    Write-Host "'$vmName' is now powered off." -ForegroundColor Green
}

# ── Set a VM's network adapter ───────────────────────────────────────────────

function Set-VMNetwork {
    $vmName  = Read-Host "Enter the VM name"
    $network = Read-Host "Enter the network / portgroup name to assign"

    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "ERROR: Could not find a VM named '$vmName'" -ForegroundColor Red
        return
    }

    $adapter = Get-NetworkAdapter -VM $vm | Select-Object -First 1
    if (-not $adapter) {
        Write-Host "ERROR: '$vmName' has no network adapters." -ForegroundColor Red
        return
    }

    Write-Host "Setting '$vmName' network to '$network'..." -ForegroundColor Cyan
    Set-NetworkAdapter -NetworkAdapter $adapter -NetworkName $network -Confirm:$false
    Write-Host "Done! Adapter is now on '$network'." -ForegroundColor Green
}

# ── Main menu loop ────────────────────────────────────────────────────────────

do {
    Clear-Host
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "   480 VMware Lab Menu"         -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "  [1] Connect to ESXi"
    Write-Host "  [2] Create a VM clone"
    Write-Host "  [3] Start a VM"
    Write-Host "  [4] Stop a VM"
    Write-Host "  [5] Set VM network adapter"
    Write-Host "  [0] Exit"
    Write-Host "------------------------------" -ForegroundColor DarkGray

    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        "1" { Connect-ToESXi  }
        "2" { New-Clone       }
        "3" { Start-NamedVM   }
        "4" { Stop-NamedVM    }
        "5" { Set-VMNetwork   }
        "0" { Write-Host "Goodbye!" -ForegroundColor Cyan }
        default { Write-Host "Please enter a number from the menu." -ForegroundColor Yellow }
    }

    if ($choice -ne "0") {
        Write-Host ""
        Read-Host "Press Enter to return to the menu"
    }

} while ($choice -ne "0")
