#!/usr/bin/env bash
# Versión para Linux/macOS de levantar.ps1: hace los mismos pasos en el mismo orden.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/../Script"
cd "$DIR"

leer_env() {
    local valor
    valor="$(grep -E "^$1=" "$DIR/.env" | head -1 | cut -d= -f2- | tr -d '\r')" || true
    [ -n "$valor" ] || { echo "Falta $1 en Docker/.env" >&2; exit 1; }
    printf '%s' "$valor"
}

[ -f "$DIR/.env" ] || { echo "Falta Docker/.env (copiar de .env.example)" >&2; exit 1; }
PASSWORD="$(leer_env SA_PASSWORD)"
ENLACE="$(leer_env ENLACE_PASSWORD)"
LLAVE_ORIGEN="$(leer_env LLAVE_ORIGEN)"
LLAVE_IDENTIDAD="$(leer_env LLAVE_IDENTIDAD)"
USUARIOS_PASSWORD="$(leer_env USUARIOS_PASSWORD)"
REPLICACION="$(leer_env REPLICACION_PASSWORD)"
[ -f "$DIR/backup/WideWorldImporters-Full.bak" ] || { echo "Falta backup/WideWorldImporters-Full.bak" >&2; exit 1; }

NODOS=(corporativo sanjose limon)
declare -A BASE=([corporativo]=WWI_Corporativo [sanjose]=WWI_SanJose [limon]=WWI_Limon)

titulo() { printf '\033[36m== %s\033[0m\n' "$*"; }

# sql NODO argumentos...  -> corre sqlcmd dentro del contenedor; si falla muestra la salida y se detiene
sql() {
    local nodo="$1"; shift
    local ruta salida
    ruta="$(docker exec "$nodo" bash -c 'ls /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd 2>/dev/null | head -1')"
    if ! salida="$(docker exec "$nodo" "$ruta" -S localhost -U sa -P "$PASSWORD" -C -b "$@" 2>&1)"; then
        printf '\033[31m%s\033[0m\n' "$salida" >&2
        echo "Fallo sqlcmd en $nodo (${*: -1})" >&2
        exit 1
    fi
    printf '%s\n' "$salida"
}

filtrar()  { grep -E  "$1" || true; }
excluir()  { grep -Ev "$1" || true; }

titulo 'Docker'
# docker info termina con 0 aunque el motor falle; docker version sí devuelve error
if ! motor="$(docker version --format '{{.Server.Version}}' 2>/dev/null)" || [ -z "$motor" ]; then
    echo 'El motor de Docker no responde. Abre Docker Desktop y espera a que diga "Engine running" (si sigue fallando, reinícialo) y vuelve a correr levantar.sh.' >&2
    exit 1
fi
echo "Docker $motor"

RED_SUBNET='172.30.0.0/24'

titulo 'Red wwi-net'
# Los contenedores del esquema anterior (un solo proyecto con los tres nodos) se quitan; sus volúmenes se conservan
if docker ps -a --filter label=com.docker.compose.project=pry2-bases-2 -q | grep -q .; then
    docker compose -p pry2-bases-2 down
fi
subnet="$(docker network inspect wwi-net -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)"
if [ -n "$subnet" ] && [ "$subnet" != "$RED_SUBNET" ]; then
    docker network rm wwi-net >/dev/null
    subnet=''
fi
[ -n "$subnet" ] || docker network create --subnet "$RED_SUBNET" wwi-net >/dev/null
echo "wwi-net ($RED_SUBNET)"

for nodo in "${NODOS[@]}"; do
    titulo "Levantando $nodo"
    docker compose --project-directory "$DIR" --env-file "$DIR/.env" -f "$DIR/nodos/$nodo.yml" up -d --wait
done

docker exec -u root corporativo bash -c 'mkdir -p /var/opt/mssql/repldata && chown mssql /var/opt/mssql/repldata'

for nodo in "${NODOS[@]}"; do
    db="${BASE[$nodo]}"
    titulo "$nodo : restaurando $db"
    bak='/var/opt/mssql/backup/WideWorldImporters-Full.bak'
    q="IF DB_ID('$db') IS NULL RESTORE DATABASE [$db] FROM DISK='$bak' WITH \
MOVE 'WWI_Primary' TO '/var/opt/mssql/data/$db.mdf', \
MOVE 'WWI_UserData' TO '/var/opt/mssql/data/${db}_UserData.ndf', \
MOVE 'WWI_Log' TO '/var/opt/mssql/data/$db.ldf', \
MOVE 'WWI_InMemory_Data_1' TO '/var/opt/mssql/data/${db}_InMemory_Data_1' \
ELSE PRINT 'Ya existe $db, se omite.'"
    sql "$nodo" -Q "$q" | filtrar 'successfully|Ya existe'
done

for nodo in "${NODOS[@]}"; do
    titulo "$nodo : login wwi_enlace"
    docker cp "$SCRIPT/distribuido/00_login_enlace.sql" "$nodo:/tmp/00_login_enlace.sql" >/dev/null
    sql "$nodo" -v "BASE=${BASE[$nodo]}" "ENLACE_PASSWORD=$ENLACE" -i /tmp/00_login_enlace.sql
done

for nodo in "${NODOS[@]}"; do
    titulo "$nodo : linked servers"
    docker cp "$SCRIPT/distribuido/01_linked_servers.sql" "$nodo:/tmp/01_linked_servers.sql" >/dev/null
    sql "$nodo" -v "NODO=$nodo" "ENLACE_PASSWORD=$ENLACE" -i /tmp/01_linked_servers.sql
done

titulo 'corporativo : distribuidor de la replicacion'
docker cp "$SCRIPT/distribuido/02_distribuidor.sql" corporativo:/tmp/02_distribuidor.sql >/dev/null
sql corporativo -v "SA_PASSWORD=$PASSWORD" -i /tmp/02_distribuidor.sql | filtrar 'Distribuidor|publicador|distribuidor|Master key'

for script in 03_fragmentacion_vertical.sql 04_fragmentacion_horizontal.sql 05_secuencias.sql; do
    for nodo in "${NODOS[@]}"; do
        titulo "$nodo : $script"
        docker cp "$SCRIPT/distribuido/$script" "$nodo:/tmp/$script" >/dev/null
        sql "$nodo" -I -v "NODO=$nodo" "BASE=${BASE[$nodo]}" -i "/tmp/$script" | excluir 'Changed database context'
    done
done

for nodo in "${NODOS[@]}"; do
    titulo "$nodo : usuarios y llaves de cifrado"
    docker cp "$SCRIPT/distribuido/06_seguridad.sql" "$nodo:/tmp/06_seguridad.sql" >/dev/null
    sql "$nodo" -I -v "NODO=$nodo" "BASE=${BASE[$nodo]}" "SA_PASSWORD=$PASSWORD" \
        "LLAVE_ORIGEN=$LLAVE_ORIGEN" "LLAVE_IDENTIDAD=$LLAVE_IDENTIDAD" "USUARIOS_PASSWORD=$USUARIOS_PASSWORD" \
        -i /tmp/06_seguridad.sql | filtrar 'creada|creado|Usuarios en'
done

for nodo in "${NODOS[@]}"; do
    titulo "$nodo : preparar la replicacion"
    docker cp "$SCRIPT/distribuido/07_preparar_replicacion.sql" "$nodo:/tmp/07_preparar_replicacion.sql" >/dev/null
    sql "$nodo" -I -v "NODO=$nodo" "BASE=${BASE[$nodo]}" "REPLICACION_PASSWORD=$REPLICACION" \
        -i /tmp/07_preparar_replicacion.sql | excluir 'Changed database context'
done

CARPETAS=(sql CRUD/PRODUCTOS CRUD/CLIENTES CRUD/PROVEEDORES CRUD/VENTAS estadisticas)
for nodo in "${NODOS[@]}"; do
    titulo "$nodo : procedimientos del Proyecto 1"
    docker exec -u root "$nodo" rm -rf /tmp/Script
    docker cp "$SCRIPT" "$nodo:/tmp/Script" >/dev/null
    total=0
    for carpeta in "${CARPETAS[@]}"; do
        while IFS= read -r archivo; do
            nombre="$(basename "$archivo")"
            [ "$nombre" = 'ejemplo_ejecucion.sql' ] && continue
            sql "$nodo" -I -d "${BASE[$nodo]}" -i "/tmp/Script/$carpeta/$nombre" >/dev/null
            total=$((total + 1))
        done < <(find "$SCRIPT/$carpeta" -maxdepth 1 -name '*.sql' | sort)
    done
    echo "$total scripts instalados"
done

for nodo in sanjose limon corporativo; do
    titulo "$nodo : replicacion"
    docker cp "$SCRIPT/distribuido/08_replicacion.sql" "$nodo:/tmp/08_replicacion.sql" >/dev/null
    sql "$nodo" -I -v "NODO=$nodo" "BASE=${BASE[$nodo]}" "REPLICACION_PASSWORD=$REPLICACION" \
        -i /tmp/08_replicacion.sql | excluir 'Changed database context|DBCC|WARNING: The database|^\s*$'
done

titulo 'Esperando la primera sincronizacion'
usuarios="$(sql corporativo -h -1 -d WWI_Corporativo -Q 'SET NOCOUNT ON; SELECT COUNT(*) FROM Seguridad.Usuarios' | head -1 | tr -d '[:space:]')"
consulta="SET NOCOUNT ON; SELECT CAST((SELECT COUNT(*) FROM sys.triggers WHERE parent_id = OBJECT_ID('Warehouse.StockItems') AND name LIKE 'MSmerge%') AS varchar) + ' ' + CAST((SELECT COUNT(*) FROM Seguridad.Usuarios) AS varchar)"
for nodo in sanjose limon; do
    ok=0
    for _ in $(seq 36); do
        read -r triggers usu < <(sql "$nodo" -h -1 -d "${BASE[$nodo]}" -Q "$consulta" | head -1)
        if [ "${triggers:-0}" -gt 0 ] && [ "$usu" = "$usuarios" ]; then ok=1; break; fi
        sleep 5
    done
    if [ $ok = 1 ]; then echo "$nodo sincronizado (catalogo y $usuarios usuarios)"
    else printf '\033[33m%s todavia no termina la primera sincronizacion; revisar con verificar.sh\033[0m\n' "$nodo"; fi
done

printf '\033[32m== Verificacion\033[0m\n'
"$DIR/verificar.sh"
