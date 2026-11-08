#!/usr/bin/env bash
# Versión para Linux/macOS de verificar.ps1: muestra el estado de los tres nodos.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD="$(grep -E '^SA_PASSWORD=' "$DIR/.env" | head -1 | cut -d= -f2- | tr -d '\r')"

for par in corporativo:1441 sanjose:1442 limon:1443; do
    nodo="${par%%:*}"; puerto="${par##*:}"
    estado="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$nodo" 2>/dev/null)"
    echo
    printf '\033[36m== %s (puerto %s) : %s\033[0m\n' "$nodo" "$puerto" "${estado:-no existe}"
    [[ "$estado" == running* ]] || continue

    echo "  Sistema   : $(docker exec "$nodo" bash -c '. /etc/os-release && echo $PRETTY_NAME')"

    docker cp "$DIR/../Script/distribuido/99_verificar_nodo.sql" "$nodo:/tmp/99_verificar_nodo.sql" >/dev/null
    ruta="$(docker exec "$nodo" bash -c 'ls /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd 2>/dev/null | head -1')"
    docker exec "$nodo" "$ruta" -S localhost -U sa -P "$PASSWORD" -C -i /tmp/99_verificar_nodo.sql 2>&1 | grep -E '^\s{2}\S'
done
echo
