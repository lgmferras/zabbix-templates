[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateSet(
    'DbPath','BackupPath',
    'Ipv4Enabled','Ipv6Enabled',
    'V4ScopesCount','V4ScopeDiscovery',
    'V4ScopeStats','V4ScopeGet',
    'V4ScopeReservationsCount','V4ScopeOptionsCount',
    'V4LeasesTotal','V4LeasesUsed','V4Utilization'
  )]
  [string]$Action,

  [string]$ScopeId
)

# Garante saída UTF-8 sem BOM — necessário para Zabbix interpretar números corretamente
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding            = [System.Text.UTF8Encoding]::new($false)

function Out-NonEmptyString([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return "0" }
  return $s.Trim()
}

try {
  Import-Module DhcpServer -ErrorAction Stop
} catch {
  Write-Output "0"
  exit 0
}

try {
  switch ($Action) {

    'DbPath' {
      $db = Get-DhcpServerDatabase -ErrorAction Stop
      Write-Output (Out-NonEmptyString $db.FileName)
    }

    'BackupPath' {
      $db = Get-DhcpServerDatabase -ErrorAction Stop
      Write-Output (Out-NonEmptyString $db.BackupPath)
    }

    'Ipv4Enabled' {
      $b = Get-DhcpServerv4Binding -ErrorAction Stop
      $enabled = ($b | Where-Object { $_.BindingState -eq $true }).Count
      Write-Output ($(if ($enabled -gt 0) { "1" } else { "0" }))
    }

    'Ipv6Enabled' {
      $b = Get-DhcpServerv6Binding -ErrorAction Stop
      $enabled = ($b | Where-Object { $_.BindingState -eq $true }).Count
      Write-Output ($(if ($enabled -gt 0) { "1" } else { "0" }))
    }

    'V4ScopesCount' {
      $scopes = @(Get-DhcpServerv4Scope -ErrorAction Stop)
      Write-Output ($scopes.Count)
    }

    'V4ScopeDiscovery' {
      $scopes = @(Get-DhcpServerv4Scope -ErrorAction Stop)
      $rows = @()

      foreach ($s in $scopes) {
        $rows += [ordered]@{
          "{#SCOPEID}"   = [string]$s.ScopeId
          "{#SCOPENAME}" = [string]$s.Name
        }
      }

      $json = $rows | ConvertTo-Json -Compress
      Write-Output (Out-NonEmptyString $json)
    }

    'V4ScopeStats' {
      if ([string]::IsNullOrWhiteSpace($ScopeId)) { Write-Output "{}"; exit 0 }

      $st = Get-DhcpServerv4ScopeStatistics -ScopeId $ScopeId -ErrorAction Stop
      $obj = [ordered]@{
        Total     = [int]$st.AddressesTotal
        InUse     = [int]$st.AddressesInUse
        Available = [int]$st.AddressesFree
      }
      Write-Output (($obj | ConvertTo-Json -Compress))
    }

    'V4ScopeGet' {
      if ([string]::IsNullOrWhiteSpace($ScopeId)) { Write-Output "{}"; exit 0 }

      $s = Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction Stop
      $obj = [ordered]@{
        StartRange = [string]$s.StartRange
        EndRange   = [string]$s.EndRange
        SubnetMask = [string]$s.SubnetMask
        State      = [string]$s.State
      }
      Write-Output (($obj | ConvertTo-Json -Compress))
    }

    'V4ScopeReservationsCount' {
      if ([string]::IsNullOrWhiteSpace($ScopeId)) { Write-Output "0"; exit 0 }
      $r = Get-DhcpServerv4Reservation -ScopeId $ScopeId -ErrorAction SilentlyContinue
      if ($null -eq $r) { Write-Output "0" } else { Write-Output ($r.Count) }
    }

    'V4ScopeOptionsCount' {
      if ([string]::IsNullOrWhiteSpace($ScopeId)) { Write-Output "0"; exit 0 }
      $o = Get-DhcpServerv4OptionValue -ScopeId $ScopeId -All -ErrorAction SilentlyContinue
      if ($null -eq $o) { Write-Output "0" } else { Write-Output ($o.Count) }
    }

    'V4LeasesTotal' {
      $scopes = @(Get-DhcpServerv4Scope -ErrorAction Stop)
      $total = 0
      foreach ($s in $scopes) {
        $st = Get-DhcpServerv4ScopeStatistics -ScopeId $s.ScopeId -ErrorAction SilentlyContinue
        if ($st) { $total += [int]$st.AddressesInUse + [int]$st.AddressesFree }
      }
      Write-Output $total
    }

    'V4LeasesUsed' {
      $scopes = @(Get-DhcpServerv4Scope -ErrorAction Stop)
      $used = 0
      foreach ($s in $scopes) {
        $st = Get-DhcpServerv4ScopeStatistics -ScopeId $s.ScopeId -ErrorAction SilentlyContinue
        if ($st) { $used += [int]$st.AddressesInUse }
      }
      Write-Output $used
    }

    'V4Utilization' {
      $scopes = @(Get-DhcpServerv4Scope -ErrorAction Stop)
      $total = 0; $used = 0
      foreach ($s in $scopes) {
        $st = Get-DhcpServerv4ScopeStatistics -ScopeId $s.ScopeId -ErrorAction SilentlyContinue
        if ($st) {
          $total += [int]$st.AddressesInUse + [int]$st.AddressesFree
          $used  += [int]$st.AddressesInUse
        }
      }
      if ($total -gt 0) {
        $pct = [math]::Round($used / $total * 100, 2)
        Write-Output $pct.ToString([System.Globalization.CultureInfo]::InvariantCulture)
      } else { Write-Output "0" }
    }
  }
}
catch {
  switch ($Action) {
    'V4ScopeDiscovery' { Write-Output "[]" }
    'V4ScopeStats'     { Write-Output "{}" }
    'V4ScopeGet'       { Write-Output "{}" }
    default            { Write-Output "0" }
  }
}
