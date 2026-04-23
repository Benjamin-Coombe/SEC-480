Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DefaultVIServerMode Single -Confirm:$false | Out-Null

Write-Host ""
Write-Host "=== vSphere Full VM Clone ===" -ForegroundColor Cyan
Write-Host ""

# ── Collect inputs ────────────────────────────────────────────────────────────

$vCenter       = Read-Host "vCenter / ESXi server"
$credential    = Get-Credential -Message "Enter your vSphere credentials"
$sourceVMName  = Read-Host "Source VM name (the VM to clone)"
$cloneName     = Read-Host "Name for the new clone"
$esxiHostName  = Read-Host "Target ESXi host"
$datastoreName = Read-Host "Target datastore"

# ── Connect ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Connecting to $vCenter ..." -ForegroundColor Yellow

try   { Connect-VIServer -Server $vCenter -Credential $credential -ErrorAction Stop | Out-Null }
catch { Write-Host "ERROR: Cannot connect to '$vCenter'. $_" -ForegroundColor Red; exit 1 }

# ── Validate inputs Aided by an AI agent ─────────────────────────────────────────

$sourceVM  = Get-VM        -Name $sourceVMName  -ErrorAction SilentlyContinue
$vmHost    = Get-VMHost    -Name $esxiHostName  -ErrorAction SilentlyContinue
$datastore = Get-Datastore -Name $datastoreName -RelatedObject $vmHost -ErrorAction SilentlyContinue
$nameTaken = Get-VM        -Name $cloneName     -ErrorAction SilentlyContinue

$errors = @()
if (-not $sourceVM)  { $errors += "Source VM '$sourceVMName' not found." }
if (-not $vmHost)    { $errors += "ESXi host '$esxiHostName' not found." }
if (-not $datastore) { $errors += "Datastore '$datastoreName' not found or not accessible by that host." }
if ($nameTaken)      { $errors += "A VM named '$cloneName' already exists." }

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Cannot proceed — please fix the following:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Disconnect-VIServer -Confirm:$false | Out-Null
    exit 1
}

# ── Clone ─────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Cloning '$sourceVMName' -> '$cloneName' ..." -ForegroundColor Yellow

try {
    $clone = New-VM -Name $cloneName -VM $sourceVM -VMHost $vmHost -Datastore $datastore -ErrorAction Stop
    Write-Host "Done!  '$($clone.Name)' created successfully." -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Clone failed. $_" -ForegroundColor Red
}

Disconnect-VIServer -Confirm:$false | Out-Null