Set-Location $PSScriptRoot

$password = (Get-Content .env | Where-Object { $_ -match '^SA_PASSWORD=' }) -replace '^SA_PASSWORD=', ''
if (-not $password) { throw 'Falta SA_PASSWORD en Docker\.env' }
$enlace = (Get-Content .env | Where-Object { $_ -match '^ENLACE_PASSWORD=' }) -replace '^ENLACE_PASSWORD=', ''
if (-not $enlace) { throw 'Falta ENLACE_PASSWORD en Docker\.env' }
if (-not (Test-Path backup\WideWorldImporters-Full.bak)) { throw 'Falta backup\WideWorldImporters-Full.bak' }

$nodos = [ordered]@{ corporativo = 'WWI_Corporativo'; sanjose = 'WWI_SanJose'; limon = 'WWI_Limon' }

function Invoke-Sql($nodo, [string[]]$sqlArgs) {
    $ruta = docker exec $nodo bash -c 'ls /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd 2>/dev/null | head -1'
    docker exec $nodo $ruta -S localhost -U sa -P $password -C -b @sqlArgs
    if ($LASTEXITCODE -ne 0) { throw "Fallo sqlcmd en $nodo" }
}

Write-Host '== Levantando contenedores' -ForegroundColor Cyan
docker compose up -d --wait
if ($LASTEXITCODE -ne 0) { throw 'docker compose up fallo' }

docker exec -u root corporativo bash -c 'mkdir -p /var/opt/mssql/repldata && chown mssql /var/opt/mssql/repldata'

foreach ($nodo in $nodos.Keys) {
    $db = $nodos[$nodo]
    Write-Host "== $nodo : restaurando $db" -ForegroundColor Cyan
    $bak = '/var/opt/mssql/backup/WideWorldImporters-Full.bak'
    $sql = "IF DB_ID('$db') IS NULL RESTORE DATABASE [$db] FROM DISK='$bak' WITH " +
           "MOVE 'WWI_Primary' TO '/var/opt/mssql/data/$db.mdf', " +
           "MOVE 'WWI_UserData' TO '/var/opt/mssql/data/${db}_UserData.ndf', " +
           "MOVE 'WWI_Log' TO '/var/opt/mssql/data/$db.ldf', " +
           "MOVE 'WWI_InMemory_Data_1' TO '/var/opt/mssql/data/${db}_InMemory_Data_1' " +
           "ELSE PRINT 'Ya existe $db, se omite.'"
    Invoke-Sql $nodo @('-Q', $sql) | Select-String 'successfully|Ya existe'
}

foreach ($nodo in $nodos.Keys) {
    Write-Host "== $nodo : login wwi_enlace" -ForegroundColor Cyan
    docker cp ..\Script\distribuido\00_login_enlace.sql "${nodo}:/tmp/00_login_enlace.sql"
    Invoke-Sql $nodo @('-v', "BASE=$($nodos[$nodo])", "ENLACE_PASSWORD=$enlace", '-i', '/tmp/00_login_enlace.sql')
}

foreach ($nodo in $nodos.Keys) {
    Write-Host "== $nodo : linked servers" -ForegroundColor Cyan
    docker cp ..\Script\distribuido\01_linked_servers.sql "${nodo}:/tmp/01_linked_servers.sql"
    Invoke-Sql $nodo @('-v', "NODO=$nodo", "ENLACE_PASSWORD=$enlace", '-i', '/tmp/01_linked_servers.sql')
}

Write-Host '== corporativo : distribuidor de la replicacion' -ForegroundColor Cyan
docker cp ..\Script\distribuido\02_distribuidor.sql corporativo:/tmp/02_distribuidor.sql
Invoke-Sql corporativo @('-v', "SA_PASSWORD=$password", '-i', '/tmp/02_distribuidor.sql') | Select-String 'Distribuidor|publicador|distribuidor|Master key'

Write-Host '== Verificacion' -ForegroundColor Green
& "$PSScriptRoot\verificar.ps1"
