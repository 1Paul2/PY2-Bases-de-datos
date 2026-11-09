function Read-Env($nombre) {
    $valor = (Get-Content "$PSScriptRoot\.env" | Where-Object { $_ -match "^$nombre=" }) -replace "^$nombre=", ''
    if (-not $valor) { throw "Falta $nombre en Docker\.env" }
    $valor
}

$password = Read-Env 'SA_PASSWORD'
$enlace = Read-Env 'ENLACE_PASSWORD'
$llaveOrigen = Read-Env 'LLAVE_ORIGEN'
$llaveIdentidad = Read-Env 'LLAVE_IDENTIDAD'
$usuariosPassword = Read-Env 'USUARIOS_PASSWORD'
$replicacion = Read-Env 'REPLICACION_PASSWORD'
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

Write-Host '== Docker' -ForegroundColor Cyan
# docker info termina con 0 aunque el motor falle; docker version sí devuelve error
$motor = docker version --format '{{.Server.Version}}' 2>$null
if ($LASTEXITCODE -ne 0 -or -not "$motor".Trim()) {
    throw 'El motor de Docker no responde. Abre Docker Desktop y espera a que diga "Engine running" (si sigue fallando, reinícialo) y vuelve a correr levantar.ps1.'
}
Write-Host "Docker $motor"

$redSubnet = '172.30.0.0/24'
Write-Host '== Red wwi-net' -ForegroundColor Cyan
# Los contenedores del esquema anterior (un solo proyecto con los tres nodos) se quitan; sus volúmenes se conservan
if (docker ps -a --filter label=com.docker.compose.project=pry2-bases-2 -q) { docker compose -p pry2-bases-2 down }
$subnet = docker network inspect wwi-net -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>$null
if ($subnet -and $subnet -ne $redSubnet) { docker network rm wwi-net | Out-Null; $subnet = $null }
if (-not $subnet) {
    docker network create --subnet $redSubnet wwi-net | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la red wwi-net' }
}
Write-Host "wwi-net ($redSubnet)"

foreach ($nodo in $nodos.Keys) {
    Write-Host "== Levantando $nodo" -ForegroundColor Cyan
    docker compose --project-directory "$PSScriptRoot" --env-file "$PSScriptRoot\.env" -f "$PSScriptRoot\nodos\$nodo.yml" up -d --wait
    if ($LASTEXITCODE -ne 0) { throw "docker compose up fallo en $nodo" }
}

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

foreach ($nodo in $nodos.Keys) {
    Write-Host "== $nodo : usuarios y llaves de cifrado" -ForegroundColor Cyan
    docker cp "$PSScriptRoot\..\Script\distribuido\06_seguridad.sql" "${nodo}:/tmp/06_seguridad.sql"
    Invoke-Sql $nodo @('-I', '-v', "NODO=$nodo", "BASE=$($nodos[$nodo])", "SA_PASSWORD=$password",
        "LLAVE_ORIGEN=$llaveOrigen", "LLAVE_IDENTIDAD=$llaveIdentidad", "USUARIOS_PASSWORD=$usuariosPassword",
        '-i', '/tmp/06_seguridad.sql') | Select-String 'creada|creado|Usuarios en'
}

foreach ($nodo in $nodos.Keys) {
    Write-Host "== $nodo : preparar la replicacion" -ForegroundColor Cyan
    docker cp "$PSScriptRoot\..\Script\distribuido\07_preparar_replicacion.sql" "${nodo}:/tmp/07_preparar_replicacion.sql"
    Invoke-Sql $nodo @('-I', '-v', "NODO=$nodo", "BASE=$($nodos[$nodo])", "REPLICACION_PASSWORD=$replicacion",
        '-i', '/tmp/07_preparar_replicacion.sql') | Select-String -NotMatch 'Changed database context'
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

foreach ($nodo in 'sanjose', 'limon', 'corporativo') {
    Write-Host "== $nodo : replicacion" -ForegroundColor Cyan
    docker cp "$PSScriptRoot\..\Script\distribuido\08_replicacion.sql" "${nodo}:/tmp/08_replicacion.sql"
    Invoke-Sql $nodo @('-I', '-v', "NODO=$nodo", "BASE=$($nodos[$nodo])", "REPLICACION_PASSWORD=$replicacion",
        '-i', '/tmp/08_replicacion.sql') | Select-String -NotMatch 'Changed database context|DBCC|WARNING: The database|^\s*$'
}

Write-Host '== Esperando la primera sincronizacion' -ForegroundColor Cyan
$usuarios = (Invoke-Sql corporativo @('-h', '-1', '-d', 'WWI_Corporativo', '-Q', 'SET NOCOUNT ON; SELECT COUNT(*) FROM Seguridad.Usuarios') | Select-Object -First 1).ToString().Trim()
foreach ($nodo in 'sanjose', 'limon') {
    $consulta = "SET NOCOUNT ON; SELECT CAST((SELECT COUNT(*) FROM sys.triggers WHERE parent_id = OBJECT_ID('Warehouse.StockItems') AND name LIKE 'MSmerge%') AS varchar) + ' ' + CAST((SELECT COUNT(*) FROM Seguridad.Usuarios) AS varchar)"
    for ($i = 0; $i -lt 36; $i++) {
        $estado = (Invoke-Sql $nodo @('-h', '-1', '-d', $nodos[$nodo], '-Q', $consulta) | Select-Object -First 1).ToString().Trim() -split ' '
        if ([int]$estado[0] -gt 0 -and $estado[1] -eq $usuarios) { break }
        Start-Sleep 5
    }
    if ([int]$estado[0] -gt 0 -and $estado[1] -eq $usuarios) { Write-Host "$nodo sincronizado (catalogo y $usuarios usuarios)" }
    else { Write-Host "$nodo todavia no termina la primera sincronizacion; revisar con verificar.ps1" -ForegroundColor Yellow }
}

# Ventas de las sucursales hacia el corporativo: el corporativo registra a las sucursales como publicadoras,
# cada sucursal publica, y al final el corporativo genera el snapshot
foreach ($nodo in 'corporativo', 'sanjose', 'limon', 'corporativo') {
    Write-Host "== $nodo : replicacion de ventas al corporativo" -ForegroundColor Cyan
    docker cp "$PSScriptRoot\..\Script\distribuido\09_replicaciones_ventas.sql" "${nodo}:/tmp/09_replicaciones_ventas.sql"
    Invoke-Sql $nodo @('-I', '-v', "NODO=$nodo", "BASE=$($nodos[$nodo])", "SA_PASSWORD=$password", "REPLICACION_PASSWORD=$replicacion",
        '-i', '/tmp/09_replicaciones_ventas.sql') | Select-String -NotMatch 'Changed database context|DBCC|WARNING: The database|^\s*$|ya estaba en Pub'
}

Write-Host '== Esperando las ventas en el corporativo' -ForegroundColor Cyan
$facturas = @{}
foreach ($nodo in 'sanjose', 'limon') {
    $facturas[$nodo] = (Invoke-Sql $nodo @('-h', '-1', '-d', $nodos[$nodo], '-Q', 'SET NOCOUNT ON; SELECT COUNT(*) FROM Sales.Invoices') | Select-Object -First 1).ToString().Trim()
}
$consulta = "SET NOCOUNT ON; SELECT CAST((SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID('Resumen')) AS varchar) + ' ' + " +
            "CAST(ISNULL((SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id = OBJECT_ID('Resumen.Facturas_SJ') AND p.index_id IN (0,1)), -1) AS varchar) + ' ' + " +
            "CAST(ISNULL((SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id = OBJECT_ID('Resumen.Facturas_LI') AND p.index_id IN (0,1)), -1) AS varchar)"
for ($i = 0; $i -lt 60; $i++) {
    $estado = (Invoke-Sql corporativo @('-h', '-1', '-d', 'WWI_Corporativo', '-Q', $consulta) | Select-Object -First 1).ToString().Trim() -split ' '
    if ($estado[0] -eq '12' -and $estado[1] -eq $facturas['sanjose'] -and $estado[2] -eq $facturas['limon']) { break }
    Start-Sleep 5
}
if ($estado[0] -eq '12' -and $estado[1] -eq $facturas['sanjose'] -and $estado[2] -eq $facturas['limon']) {
    Write-Host "Resumen listo: $($estado[1]) facturas de San Jose y $($estado[2]) de Limon"
} else {
    Write-Host 'El snapshot de las ventas todavia no termina; revisar con verificar.ps1 y volver a correr levantar.ps1' -ForegroundColor Yellow
}

Write-Host '== corporativo : vistas Resumen' -ForegroundColor Cyan
docker cp "$PSScriptRoot\..\Script\distribuido\10_vistas_resumen.sql" corporativo:/tmp/10_vistas_resumen.sql
Invoke-Sql corporativo @('-I', '-v', 'NODO=corporativo', 'BASE=WWI_Corporativo', '-i', '/tmp/10_vistas_resumen.sql') |
    Select-String -NotMatch 'Changed database context|^\s*$'

Write-Host '== Verificacion' -ForegroundColor Green
& "$PSScriptRoot\verificar.ps1"
