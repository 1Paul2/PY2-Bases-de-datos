Set-Location $PSScriptRoot

$password = (Get-Content .env | Where-Object { $_ -match '^SA_PASSWORD=' }) -replace '^SA_PASSWORD=', ''
$nodos = [ordered]@{ corporativo = 1441; sanjose = 1442; limon = 1443 }

foreach ($nodo in $nodos.Keys) {
    $estado = docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' $nodo 2>$null
    Write-Host ''
    Write-Host "== $nodo (puerto $($nodos[$nodo])) : $(if ($estado) { $estado } else { 'no existe' })" -ForegroundColor Cyan
    if ($estado -notmatch '^running') { continue }

    $so = docker exec $nodo bash -c '. /etc/os-release && echo $PRETTY_NAME'
    Write-Host "  Sistema   : $so"

    docker cp ..\Script\distribuido\99_verificar_nodo.sql "${nodo}:/tmp/99_verificar_nodo.sql" | Out-Null
    $ruta = docker exec $nodo bash -c 'ls /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd 2>/dev/null | head -1'
    docker exec $nodo $ruta -S localhost -U sa -P $password -C -i /tmp/99_verificar_nodo.sql 2>&1 |
        Where-Object { "$_" -match '^\s{2}\S' } | ForEach-Object { Write-Host "$_" }
}
Write-Host ''
