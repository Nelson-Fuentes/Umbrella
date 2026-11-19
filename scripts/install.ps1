# Instala la build de este repo en los agentes detectados en esta maquina.
# Claude Code se instala como plugin real (marketplace local + `claude plugin
# install`); el resto de agentes, copiando dist/project/ a su carpeta de
# configuracion. No sobrescribe nada sin confirmacion explicita del usuario.
param(
    [string]$TargetDir = (Get-Location).Path
)

$ScriptDir = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $ScriptDir "dist/project"
$ClaudeMarketplaceDir = Join-Path $ScriptDir "dist/claude"
$ClaudeMarketplaceName = "umbrella-local"
$ClaudePluginId = "umbrella@$ClaudeMarketplaceName"
# Scope "user": se copia a una ruta estable fuera del repo, para que el
# plugin siga funcionando aunque esta carpeta se mueva o se borre despues.
$ClaudeStableDir = Join-Path $HOME ".local/share/umbrella-sdd/claude-plugin"

if (-not (Test-Path $Dist)) {
    Write-Error "no existe $Dist. Ejecuta .\build.sh (o la build equivalente) primero."
    exit 1
}

function Install-ClaudeCodePlugin {
    param([string]$Scope)
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Error "  no se encontro el comando 'claude' en el PATH. Instala Claude Code o agrega el binario al PATH y reintenta."
        return
    }

    $marketplaceSrc = $ClaudeMarketplaceDir
    if ($Scope -eq "user") {
        Write-Host "  copiando $ClaudeMarketplaceDir -> $ClaudeStableDir (copia estable fuera del repo)"
        if (Test-Path $ClaudeStableDir) { Remove-Item -Recurse -Force $ClaudeStableDir }
        New-Item -ItemType Directory -Force -Path $ClaudeStableDir | Out-Null
        Copy-Item -Path (Join-Path $ClaudeMarketplaceDir "*") -Destination $ClaudeStableDir -Recurse -Force
        $marketplaceSrc = $ClaudeStableDir
        # Si ya estaba registrado apuntando a otra ruta (p.ej. el repo), hay que
        # quitarlo antes: 'marketplace add' no reubica un nombre existente.
        & claude plugin marketplace remove $ClaudeMarketplaceName --scope $Scope 2>$null | Out-Null
    }

    Write-Host "  claude plugin marketplace add $marketplaceSrc --scope $Scope"
    & claude plugin marketplace add $marketplaceSrc --scope $Scope
    Write-Host "  claude plugin install $ClaudePluginId --scope $Scope"
    & claude plugin install $ClaudePluginId --scope $Scope
}

# Cada candidato: Key, Marcador de deteccion, rutas de origen (relativas a dist/project), destino
# Claude Code no esta aqui: se instala como plugin (ver Install-ClaudeCodePlugin).
$Candidates = @(
    @{ Key = "cursor";            Marker = (Join-Path $TargetDir ".cursor");        Srcs = @(".cursor/rules", ".cursor/agents", ".cursor/skills"); Dst = (Join-Path $TargetDir ".cursor") }
    @{ Key = "antigravity";       Marker = (Join-Path $TargetDir ".agents");        Srcs = @(".agents/rules", ".agents/agents", ".agents/skills"); Dst = (Join-Path $TargetDir ".agents") }
    @{ Key = "antigravity-global";Marker = (Join-Path $HOME ".gemini");            Srcs = @(".agents/rules", ".agents/agents", ".agents/skills"); Dst = (Join-Path $HOME ".gemini/config") }
    @{ Key = "copilot";           Marker = (Join-Path $TargetDir ".github");       Srcs = @(".github/instructions");                              Dst = (Join-Path $TargetDir ".github/instructions") }
    @{ Key = "opencode";          Marker = (Join-Path $TargetDir ".opencode");     Srcs = @(".opencode/memories");                                 Dst = (Join-Path $TargetDir ".opencode") }
)

Write-Host "Buscando agentes instalados en $TargetDir y en `$HOME..."
$Detected = @()

if (Get-Command claude -ErrorAction SilentlyContinue) {
    $Detected += @{ Key = "claudecode";        Marker = "comando 'claude' (plugin de proyecto, scope project)" }
    $Detected += @{ Key = "claudecode-global";  Marker = "comando 'claude' (plugin de usuario, copia estable fuera del repo, scope user)" }
}

foreach ($c in $Candidates) {
    if (Test-Path $c.Marker) {
        $Detected += $c
    }
}

if ($Detected.Count -eq 0) {
    Write-Host "No se detecto ningun agente conocido en $TargetDir ni en `$HOME."
    Write-Host "Instala manualmente desde dist/project/ o crea el directorio del agente antes de reintentar."
    exit 0
}

Write-Host ""
Write-Host "Agentes detectados:"
for ($i = 0; $i -lt $Detected.Count; $i++) {
    Write-Host "$($i + 1)) $($Detected[$i].Key)  (detectado via $($Detected[$i].Marker))"
}
Write-Host "Escribe los numeros a instalar separados por espacio (o 'todos'):"
$Selection = Read-Host

$Selected = @()
if ($Selection.Trim() -eq "todos") {
    $Selected = $Detected
} else {
    foreach ($n in ($Selection -split '\s+')) {
        if ($n -match '^\d+$') {
            $idx = [int]$n - 1
            if ($idx -ge 0 -and $idx -lt $Detected.Count) {
                $Selected += $Detected[$idx]
            }
        }
    }
}

foreach ($c in $Selected) {
    if ($c.Key -eq "claudecode") {
        Install-ClaudeCodePlugin -Scope "project"
        continue
    }
    if ($c.Key -eq "claudecode-global") {
        Install-ClaudeCodePlugin -Scope "user"
        continue
    }

    foreach ($src in $c.Srcs) {
        $srcPath = Join-Path $Dist $src
        if (-not (Test-Path $srcPath)) { continue }
        $baseName = Split-Path -Leaf $src
        $destParent = $c.Dst
        $destPath = Join-Path $destParent $baseName
        if (Test-Path $destPath) {
            $ans = Read-Host "  $destPath ya existe. Sobrescribir? [s/N]"
            if ($ans -notmatch '^[sS]$') {
                Write-Host "  omitido: $destPath"
                continue
            }
        }
        New-Item -ItemType Directory -Force -Path $destParent | Out-Null
        Copy-Item -Path $srcPath -Destination $destParent -Recurse -Force
        Write-Host "  copiado: $src -> $destPath"
    }
}

Write-Host "Listo. Reinicia la sesion del agente para que recargue las skills/subagentes/plugins."
