# NOTES: [ ] Add ISO file

# Configuration
$csvPath = Join-Path $PSScriptRoot "..\data\vm-hyperv.csv"
$vmRoot = "V:\VM"

# Import VM configurations
if (-not (Test-Path -LiteralPath $csvPath -PathType Leaf)) {
    throw "CSV file not found: $csvPath"
}
$vms = Import-Csv -LiteralPath $csvPath -Delimiter ","

foreach ($vm in $vms) {
    $vmName = $vm.Name.Trim()

    try {
        # Convert CSV values
        $generation = [int]$vm.Generation
        $memory = [int64]$vm.RAMGB * 1GB
        $cpuCount = [int]$vm.CPU
        $diskSize = [int64]$vm.DiskGB * 1GB

        # Define storage paths
        $vmPath = Join-Path $vmRoot $vmName
        $diskPath = Join-Path $vmPath "$vmName.vhdx"

        # Validate configuration
        if ($generation -notin @(1, 2) -or
            $memory -le 0 -or
            $cpuCount -le 0 -or
            $diskSize -le 0) {
                throw "Invalid VM configuration."
            }

        # Skip existing VMs
        if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
            Write-Warning "VM '$vmName' already exists."
            continue
        }

        # Validate network switch
        if (-not (Get-VMSwitch -Name $vm.SwitchName -ErrorAction SilentlyContinue)) {
            throw "vSwitch not found: $($vm.SwitchName)"
        }

        # Create VM directory
        New-Item -Path $vmPath -ItemType Directory -Force | Out-Null

        # Create VM
        New-VM `
            -Name $vmName `
            -Generation $generation `
            -MemoryStartupBytes $memory `
            -NewVHDPath $diskPath `
            -NewVHDSizeBytes $diskSize `
            -Path $vmPath `
            -SwitchName $vm.SwitchName `
            -ErrorAction Stop | Out-Null

        # Disable Secure Boot (Check for Linux in csv)
        if ($generation -eq 2) {
            Set-VMFirmware -VMName $vmName -EnableSecureBoot Off -ErrorAction Stop
        }

        # Configure CPU and memory
        Set-VMProcessor -VMName $vmName -Count $cpuCount -ErrorAction Stop
        Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false -ErrorAction Stop

        Write-Host "VM '$vmName' created successfully."
    }
    catch {
        Write-Warning "Failed to create '$vmName': $_"
    }
}
