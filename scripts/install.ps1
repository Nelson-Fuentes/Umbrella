# Instala la build de dist/project/ en los agentes detectados en esta maquina.
# No sobrescribe nada sin confirmacion explicita del usuario.
param(
    [string]$TargetDir = (Get-Location).Path
)

$ScriptDir = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $ScriptDir "dist/project"

if (-not (Test-Path $Dist)) {
    Write-Error "no existe $Dist. Ejecuta .\build.sh (o la build equivalente) primero."
    exit 1
}

# Cada candidato: Key, Marcador de deteccion, rutas de origen (relativas a dist/project), destino
$Candidates = @(
    @{ Key = "claudecode";        Marker = (Join-Path $TargetDir ".claude");        Srcs = @(".claude/rules", ".claude/agents", ".claude/skills"); Dst = (Join-Path $TargetDir ".claude") }
    @{ Key = "cursor";            Marker = (Join-Path $TargetDir ".cursor");        Srcs = @(".cursor/rules", ".cursor/agents", ".cursor/skills"); Dst = (Join-Path $TargetDir ".cursor") }
    @{ Key = "antigravity";       Marker = (Join-Path $TargetDir ".agents");        Srcs = @(".agents/rules", ".agents/agents", ".agents/skills"); Dst = (Join-Path $TargetDir ".agents") }
    @{ Key = "antigravity-global";Marker = (Join-Path $HOME ".gemini");            Srcs = @(".agents/rules", ".agents/agents", ".agents/skills"); Dst = (Join-Path $HOME ".gemini/config") }
    @{ Key = "copilot";           Marker = (Join-Path $TargetDir ".github");       Srcs = @(".github/instructions");                              Dst = (Join-Path $TargetDir ".github/instructions") }
    @{ Key = "opencode";          Marker = (Join-Path $TargetDir ".opencode");     Srcs = @(".opencode/memories");                                 Dst = (Join-Path $TargetDir ".opencode") }
)

Write-Host "Buscando agentes instalados en $TargetDir y en `$HOME..."
$Detected = @()
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

Write-Host "Listo. Reinicia la sesion del agente para que recargue las skills/subagentes."
