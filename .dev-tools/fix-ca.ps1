# ---------------------------------------------------------------------------
# fix-ca.ps1
#
# Rebuilds a PEM trust bundle from the Windows certificate store (including
# corporate TLS-inspection roots such as Zscaler) and points Ruby / RubyGems /
# Bundler at it.
#
# Why: Ruby ships its own Mozilla trust bundle
#   C:\Ruby34-x64\lib\ruby\3.4.0\etc\ssl\cert.pem
# On managed machines this bundle is incomplete, so every `gem install` /
# `bundle install` against https://rubygems.org fails with
#   "SSL_connect ... certificate verify failed (unable to get local issuer
#    certificate)"
#
# Usage (PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\.dev-tools\fix-ca.ps1
#
# After running it once, restart VS Code so new terminals inherit the env var.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSCommandPath
$bundle = Join-Path $root 'ca-bundle.pem'

Write-Host "Building CA bundle from Windows certificate store ..." -ForegroundColor Cyan

$stores = @('Cert:\LocalMachine\Root', 'Cert:\CurrentUser\Root', 'Cert:\LocalMachine\CA', 'Cert:\CurrentUser\CA')
$seen = New-Object 'System.Collections.Generic.HashSet[string]'
$sb = New-Object System.Text.StringBuilder

foreach ($store in $stores) {
    foreach ($cert in (Get-ChildItem $store -ErrorAction SilentlyContinue)) {
        if (-not $seen.Add($cert.Thumbprint)) { continue }
        $b64 = [Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks')
        [void]$sb.AppendLine("# $($cert.Thumbprint) $($cert.Subject)")
        [void]$sb.AppendLine('-----BEGIN CERTIFICATE-----')
        [void]$sb.AppendLine($b64)
        [void]$sb.AppendLine('-----END CERTIFICATE-----')
    }
}

[IO.File]::WriteAllText($bundle, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
$count = $seen.Count
Write-Host "  -> wrote $count certificates to $bundle" -ForegroundColor Green

# Persist for the current user so all future shells (gem, bundle, rails) work.
[Environment]::SetEnvironmentVariable('SSL_CERT_FILE', $bundle, 'User')
[Environment]::SetEnvironmentVariable('SSL_CERT_DIR', '', 'User')
$env:SSL_CERT_FILE = $bundle

Write-Host "  -> SSL_CERT_FILE set to $bundle (User scope)" -ForegroundColor Green
Write-Host ''
Write-Host 'Verify with:' -ForegroundColor Cyan
Write-Host '  ruby -ropenssl -e "puts OpenSSL::X509::DEFAULT_CERT_FILE"'
Write-Host '  gem list --remote rails --exact'
Write-Host ''
Write-Host 'NOTE: Restart VS Code / your terminal so the new environment variable is picked up.' -ForegroundColor Yellow
