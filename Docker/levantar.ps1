$password = (Get-Content "$PSScriptRoot\.env" | Where-Object { $_ -match '^SA_PASSWORD=' }) -replace '^SA_PASSWORD=', ''
if (-not $password) { throw 'Falta SA_PASSWORD en Docker\.env' }
$enlace = (Get-Content "$PSScriptRoot\.env" | Where-Object { $_ -match '^ENLACE_PASSWORD=' }) -replace '^ENLACE_PASSWORD=', ''
if (-not $enlace) { throw 'Falta ENLACE_PASSWORD en Docker\.env' }
if (-not (Test-Path "$PSScriptRoot\backup\WideWorldImporters-Full.bak")) { throw 'Falta backup\WideWorldImporters-Full.bak' }

$nodos = [ordered]@{ corporativo = 'WWI_Corporativo'; sanjose = 'WWI_SanJose'; limon = 'WWI_Limon' }

function Invoke-Sql($nodo, [string[]]$sqlArgs) {
    $ruta = docker exec $nodo bash -c 'ls /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd 2>/dev/null | head -1'
    $salida = docker exec $nodo $ruta -S localhost -U sa -P $password -C -b @sqlArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $salida | ForEach-Object { Write-Host "$_" -ForegroundColor Red }
        throw "Fallo sqlcmd en $nodo ($($sqlArgs[-1]))"
    }
    $salida
}

Write-Host '== Levantando contenedores' -ForegroundColor Cyan
docker compose --project-directory "$PSScriptRoot" up -d --wait
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
    docker cp "$PSScriptRoot\..\Script\distribuido\00_login_enlace.sql" "${nodo}:/tmp/00_login_enlace.sql"
    Invoke-Sql $nodo @('-v', "BASE=$($nodos[$nodo])", "ENLACE_PASSWORD=$enlace", '-i', '/tmp/00_login_enlace.sql')
}

foreach ($nodo in $nodos.Keys) {
    Write-Host "== $nodo : linked servers" -ForegroundColor Cyan
    docker cp "$PSScriptRoot\..\Script\distribuido\01_linked_servers.sql" "${nodo}:/tmp/01_linked_servers.sql"
    Invoke-Sql $nodo @('-v', "NODO=$nodo", "ENLACE_PASSWORD=$enlace", '-i', '/tmp/01_linked_servers.sql')
}

Write-Host '== corporativo : distribuidor de la replicacion' -ForegroundColor Cyan
docker cp "$PSScriptRoot\..\Script\distribuido\02_distribuidor.sql" corporativo:/tmp/02_distribuidor.sql
Invoke-Sql corporativo @('-v', "SA_PASSWORD=$password", '-i', '/tmp/02_distribuidor.sql') | Select-String 'Distribuidor|publicador|distribuidor|Master key'

foreach ($script in '03_fragmentacion_vertical.sql', '04_fragmentacion_horizontal.sql', '05_secuencias.sql') {
    foreach ($nodo in $nodos.Keys) {
        Write-Host "== $nodo : $script" -ForegroundColor Cyan
        docker cp "$PSScriptRoot\..\Script\distribuido\$script" "${nodo}:/tmp/$script"
        Invoke-Sql $nodo @('-I', '-v', "NODO=$nodo", "BASE=$($nodos[$nodo])", '-i', "/tmp/$script") |
            Select-String -NotMatch 'Changed database context'
    }
}

$carpetas = 'sql', 'CRUD/PRODUCTOS', 'CRUD/CLIENTES', 'CRUD/PROVEEDORES', 'CRUD/VENTAS', 'estadisticas'
foreach ($nodo in $nodos.Keys) {
    Write-Host "== $nodo : procedimientos del Proyecto 1" -ForegroundColor Cyan
    docker exec -u root $nodo rm -rf /tmp/Script
    docker cp "$PSScriptRoot\..\Script" "${nodo}:/tmp/Script"
    $total = 0
    foreach ($carpeta in $carpetas) {
        Get-ChildItem "$PSScriptRoot\..\Script\$carpeta" -Filter *.sql | Where-Object Name -ne 'ejemplo_ejecucion.sql' | Sort-Object Name | ForEach-Object {
            Invoke-Sql $nodo @('-I', '-d', $nodos[$nodo], '-i', "/tmp/Script/$carpeta/$($_.Name)") | Out-Null
            $total++
        }
    }
    Write-Host "$total scripts instalados"
}

Write-Host '== Verificacion' -ForegroundColor Green
& "$PSScriptRoot\verificar.ps1"
