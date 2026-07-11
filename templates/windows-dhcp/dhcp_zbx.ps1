[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateSet(
    'DbPath','BackupPath',
    'Ipv4Enabled','Ipv6Enabled',
    'V4ScopesCount','V4ScopeDiscovery',
    'V4ScopeStats','V4ScopeGet','V4ScopeDetails',
    'V4ScopeReservationsCount','V4ScopeOptionsCount',
    'V4LeasesTotal','V4LeasesUsed','V4Utilization'
  )]
  [string]$Action,

  [string]$ScopeId
)

# Garante saída UTF-8 sem BOM — necessário para Zabbix interpretar números corretamente
# (deve ficar após param() — CmdletBinding/param precisam ser os primeiros statements)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding            = [System.Text.UTF8Encoding]::new($false)

function Out-NonEmptyString([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return "0" }
  return $s.Trim()
}

try {
  Import-Module DhcpServer -ErrorAction Stop
} catch {
  # Se não tiver o módulo, devolve algo "não vazio" (evita item virar NOTSUPPORTED por vazio)
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

      # ConvertTo-Json colapsa um array de 1 elemento num objeto solto (sem colchetes).
      # Zabbix exige um array JSON na raiz mesmo com 1 unico escopo -- forcar manualmente
      # serializando cada item individualmente e unindo com colchetes (compativel com
      # Windows PowerShell 5.1, que nao tem o parametro -AsArray do PS 6.2+).
      $json = "[" + (($rows | ForEach-Object { $_ | ConvertTo-Json -Compress }) -join ",") + "]"
      Write-Output (Out-NonEmptyString $json)
    }

    'V4ScopeStats' {
      if ([string]::IsNullOrWhiteSpace($ScopeId)) { Write-Output "{}"; exit 0 }

      $st = Get-DhcpServerv4ScopeStatistics -ScopeId $ScopeId -ErrorAction Stop
      # AddressesTotal pode vir nulo/zero em alguns Windows Server — usar InUse+Free
      $obj = [ordered]@{
        Total     = [int]$st.AddressesInUse + [int]$st.AddressesFree
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

    'V4ScopeDetails' {
      if ([string]::IsNullOrWhiteSpace($ScopeId)) { Write-Output "{}"; exit 0 }

      $s     = Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction Stop
      $stats = Get-DhcpServerv4ScopeStatistics -ScopeId $ScopeId -ErrorAction SilentlyContinue

      $gw     = Get-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 3  -ErrorAction SilentlyContinue
      $dns    = Get-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 6  -ErrorAction SilentlyContinue
      $domain = Get-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 15 -ErrorAction SilentlyContinue

      $reservations = @(Get-DhcpServerv4Reservation -ScopeId $ScopeId -ErrorAction SilentlyContinue) | ForEach-Object {
        [ordered]@{ IPAddress = [string]$_.IPAddress; ClientId = [string]$_.ClientId; Name = [string]$_.Name }
      }

      $exclusions = @(Get-DhcpServerv4ExclusionRange -ScopeId $ScopeId -ErrorAction SilentlyContinue) | ForEach-Object {
        [ordered]@{ StartRange = [string]$_.StartRange; EndRange = [string]$_.EndRange }
      }

      # AddressesTotal pode vir nulo/zero em alguns Windows Server — usar InUse+Free
      $obj = [ordered]@{
        StartRange   = [string]$s.StartRange
        EndRange     = [string]$s.EndRange
        SubnetMask   = [string]$s.SubnetMask
        State        = [string]$s.State
        Name         = [string]$s.Name
        Total        = [int]$stats.AddressesInUse + [int]$stats.AddressesFree
        InUse        = [int]$stats.AddressesInUse
        Available    = [int]$stats.AddressesFree
        Gateway      = [string]($gw.Value -join ',')
        Dns          = @($dns.Value)
        Domain       = [string]($domain.Value -join '')
        Reservations = @($reservations)
        Exclusions   = @($exclusions)
      }
      Write-Output (($obj | ConvertTo-Json -Compress -Depth 4))
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

    # ── Totais globais (soma de todos os escopos) ──────────────────────────

    'V4LeasesTotal' {
      # AddressesTotal pode vir nulo/zero em alguns Windows Server — usar InUse+Free
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
  # Nunca retornar vazio; devolve 0/{} conforme o caso
  switch ($Action) {
    'V4ScopeDiscovery' { Write-Output "[]" }
    'V4ScopeStats'     { Write-Output "{}" }
    'V4ScopeGet'       { Write-Output "{}" }
    'V4ScopeDetails'   { Write-Output "{}" }
    default            { Write-Output "0" }
  }
}