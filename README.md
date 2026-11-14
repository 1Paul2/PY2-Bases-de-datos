# Wide World Importers distribuido

**Proyecto 2 – Bases de Datos II: diseño e implementación de una base de datos distribuida**

La cadena Wide World Importers tiene dos sucursales, **San José** y **Limón**, y una oficina **corporativa** en Plaza Roble, Escazú. Cada sucursal tiene su propia base de datos, con su propio sistema operativo y motor, y maneja su inventario y su facturación. El corporativo guarda los datos sensibles de clientes y proveedores y supervisa a las dos sucursales mediante estadísticas por sucursal o consolidadas. La aplicación web y la API son las del Proyecto 1, adaptadas para trabajar con los tres nodos.

| Integrante | Carné |
|------------|-------|
| Poll Garro Vargas | 2024129001 |
| Angelo Piedra Castro | 2024101262 |

---

## Contenido

1. [Resultados](#1-resultados)
2. [Arquitectura distribuida](#2-arquitectura-distribuida)
3. [Diseño de la base de datos distribuida](#3-diseño-de-la-base-de-datos-distribuida)
   - [3.1 Fragmentación](#31-fragmentación)
   - [3.2 Asignación](#32-asignación)
   - [3.3 Replicación](#33-replicación)
   - [3.4 Vistas materializadas del corporativo](#34-vistas-materializadas-del-corporativo)
   - [3.5 Concurrencia](#35-concurrencia)
   - [3.6 Seguridad y encriptación](#36-seguridad-y-encriptación)
   - [3.7 Plan de fallas](#37-plan-de-fallas)
4. [Roles](#4-roles)
5. [Aplicación web](#5-aplicación-web)
6. [API](#6-api)
7. [Instalación y ejecución](#7-instalación-y-ejecución)
8. [Estructura del repositorio](#8-estructura-del-repositorio)
9. [Decisiones sobre los datos](#9-decisiones-sobre-los-datos)
10. [Referencia de la API](#10-referencia-de-la-api)

---

## 1. Resultados

**Estado: terminado.** Todos los requisitos del enunciado están implementados y se probaron en los contenedores. Cada sección de este documento incluye las pruebas que se hicieron y sus resultados.

| Requisito del enunciado | Estado | Dónde |
|-------------------------|:------:|-------|
| Tres nodos; las sucursales con tecnología independiente (sistema operativo y motor) | Completo | [2](#2-arquitectura-distribuida) |
| Rol Administrador: consulta clientes, proveedores, productos y las facturas de su sucursal; crea, modifica y elimina productos | Completo | [4](#4-roles) |
| Rol Corporativo: consulta las estadísticas de cada sucursal | Completo | [4](#4-roles), [5](#5-aplicación-web) |
| Tabla de usuarios con iduser, username, password, fullname, active, rol, email y hiredate, sin página de gestión de usuarios | Completo | [3.6](#36-seguridad-y-encriptación) |
| Contraseña cifrada con la funcionalidad nativa de SQL Server | Completo | [3.6](#36-seguridad-y-encriptación) |
| Relacionar los usuarios de la aplicación con los usuarios de la base de datos | Completo | [3.6](#36-seguridad-y-encriptación) |
| Cada cambio en productos (y sus tablas relacionadas) se replica a todas las bases | Completo | [3.3](#33-replicación) |
| Mismo catálogo de productos, clientes y proveedores; inventario y facturación propios en cada sucursal | Completo | [3.1](#31-fragmentación) |
| Datos sensibles de clientes y proveedores en el corporativo | Completo | [3.1](#31-fragmentación) |
| Diseño y justificación de la fragmentación y de la asignación | Completo | [3.1](#31-fragmentación), [3.2](#32-asignación) |
| Filtro de las estadísticas por sucursal o consolidado | Completo | [3.3](#33-replicación), [5](#5-aplicación-web) |
| Vistas materializadas en el corporativo | Completo | [3.4](#34-vistas-materializadas-del-corporativo) |
| Concurrencia, sobre todo en catálogos modificados desde varias sucursales | Completo | [3.5](#35-concurrencia) |
| Cómo responder si un nodo no responde | Completo | [3.7](#37-plan-de-fallas) |
| Se mantienen las funcionalidades del Proyecto 1, con la misma infraestructura (SQL Server, Node.js y React) | Completo | [5](#5-aplicación-web), [6](#6-api) |
| Scripts de las bases de datos (corporativo y sucursales) | Completo | [7](#7-instalación-y-ejecución), [8](#8-estructura-del-repositorio) |
| Replicación con la funcionalidad de SQL Server | Completo | [3.3](#33-replicación) |

### Limitaciones conocidas y por qué

- **El corporativo es el centro de la replicación.** Mientras está caído, San José y Limón no intercambian cambios de productos: los guardan y se envían cuando vuelve. Se eligió así porque el corporativo ya es el maestro de clientes, proveedores y usuarios, y un solo distribuidor es más simple de operar y de explicar. Si estuviera caído más de 14 días (retención de la replicación merge), habría que reinicializar las suscripciones.
- **Con el corporativo caído, cada detalle de cliente o proveedor tarda de 8 a 12 s** antes de mostrar los datos de la sucursal, porque el proveedor del linked server reintenta la conexión antes de rendirse. Bajar el tiempo límite haría que en una red lenta se perdieran datos de contacto que sí estaban disponibles.
- **Con el corporativo caído, al crear una venta no se propone el contacto del cliente** (ese dato es sensible y vive allá). El administrador lo elige en el formulario.
- **El reparto de vendedores entre sucursales solo se aplica a los datos originales.** Una venta nueva se guarda en la sucursal donde está conectado el administrador, sea cual sea el vendedor.
- **`Script/sql/ejemplo_ejecucion.sql` es del Proyecto 1** y está pensado para una sola base: corre las estadísticas, que ahora solo existen en el corporativo, y crea ventas, que ahora solo se crean en las sucursales. No se adaptó a los nodos; las pruebas del Proyecto 2 se hicieron con la API, la web y consultas directas a cada nodo.

---

## 2. Arquitectura distribuida

```
                         ┌───────────────────────────┐
                         │  WebSite (React + Vite)   │
                         │  login, menú por rol,     │
                         │  aviso de nodos caídos    │
                         └─────────────┬─────────────┘
                                       │ HTTP/JSON + token JWT
                         ┌─────────────▼─────────────┐
                         │  Api (Node.js + Express)  │
                         │  un pool por nodo y por   │
                         │  usuario de base de datos │
                         └──┬──────────┬──────────┬──┘
           app_corporativo  │          │          │  app_admin_li
                            │          │ app_admin_sj
                 ┌──────────▼───┐ ┌────▼─────────┐ ┌▼─────────────┐
                 │ corporativo  │ │   sanjose    │ │    limon     │
                 │ Ubuntu 22.04 │ │    RHEL 9    │ │ Ubuntu 20.04 │
                 │ SQL Srv 2022 │ │ SQL Srv 2022 │ │ SQL Srv 2019 │
                 │ :1441        │ │ :1442        │ │ :1443        │
                 └──────────────┘ └──────────────┘ └──────────────┘
                   distribuidor     ◄── linked servers en malla (LS_*) ──►
                   de la replicación     replicación merge y transaccional
```

| Nodo | Base | Sistema operativo | Motor | Puerto | Memoria | Qué guarda |
|------|------|-------------------|-------|-------:|--------:|------------|
| `corporativo` | `WWI_Corporativo` | Ubuntu 22.04 | SQL Server 2022 | 1441 | 3 GB | Datos sensibles de clientes, proveedores y personas; maestro de clientes, proveedores y usuarios; copia de las ventas de las sucursales para las estadísticas. Es el distribuidor de la replicación |
| `sanjose` | `WWI_SanJose` | Red Hat Enterprise Linux 9 | SQL Server 2022 | 1442 | 2 GB | Catálogo compartido sin datos sensibles; su propio inventario, ventas y compras |
| `limon` | `WWI_Limon` | Ubuntu 20.04 | SQL Server 2019 | 1443 | 2 GB | Igual que San José, con sus propios datos |

- Cada nodo es un contenedor Docker en su propio proyecto (`Docker/nodos/*.yml`), con IP fija en la red `wwi-net` (172.30.0.0/24) y SQL Server Agent activo para la replicación.
- **Linked servers en malla:** cada nodo ve a los otros dos (`LS_CORPORATIVO`, `LS_SANJOSE`, `LS_LIMON`) con el login `wwi_enlace`, que no es administrador. Así las sucursales se consultan entre sí sin pasar por el corporativo.
- **Los procedimientos acceden a las tablas solo por sinónimos.** El mismo procedimiento funciona en los tres nodos: en el corporativo un sinónimo apunta a una tabla local y en una sucursal, a la tabla del corporativo por linked server.
- **La API no filtra, agrupa ni calcula:** cada ruta llama a un procedimiento almacenado con parámetros tipados. La web solo muestra los resultados y envía los filtros.

| Capa | Tecnología |
|------|------------|
| Base de datos | SQL Server 2022 y 2019 en contenedores Docker, replicación merge y transaccional, linked servers |
| API | Node.js, Express 5, mssql, jsonwebtoken, dotenv, cors |
| Aplicación web | React 19, Vite, Leaflet (mapas de OpenStreetMap) |

---

## 3. Diseño de la base de datos distribuida

Las tres bases parten de restaurar `WideWorldImporters-Full.bak`. Después, cada nodo borra lo que no le corresponde. Así se conservan las llaves, los tipos y las relaciones originales, y los procedimientos del Proyecto 1 siguen funcionando con cambios mínimos.

### 3.1 Fragmentación

#### Horizontal: ventas, compras e inventario por sucursal

El enunciado pide que cada sucursal maneje su propio inventario y facturación, así que cada fila pertenece a una sola sucursal (`04_fragmentacion_horizontal.sql`).

**Criterio: el vendedor.** Cada vendedor se asigna a una sucursal, y cada factura y cada pedido van a la sucursal de quien los vendió. Se comprobó que cada pedido tiene el mismo vendedor que su factura, así que una factura nunca queda separada de su pedido. Se descartaron el cliente (un mismo cliente compra a vendedores de las dos sucursales) y la fecha (una sucursal se quedaría con los años viejos y la otra con los nuevos).

**El reparto se calcula, no está escrito a mano**, así que sirve para cualquier cantidad de vendedores:

1. Se toman todos los vendedores que aparecen en las facturas o en los pedidos, con su cantidad de facturas.
2. Se ordenan de mayor a menor cantidad de facturas (los empates, por `PersonID`).
3. Cada vendedor va a la sucursal que lleva menos facturas hasta ese momento, para que las dos queden con un volumen parecido aunque los vendedores vendan cantidades muy distintas.
4. El resultado queda en `dbo.VendedorSucursal` (`PersonID`, `Sucursal`, `Facturas`). Los tres nodos restauran el mismo respaldo, así que calculan el mismo reparto sin coordinarse.
5. Antes de borrar se valida que ninguna factura ni pedido quede sin sucursal (`50110`) y que ninguna factura quede en una sucursal distinta de la de su pedido (`50111`). Si pasa, el script se detiene y no borra nada.

| Sucursal | Vendedores (`PersonID`) | Facturas |
|----------|-------------------------|---------:|
| San José | 7 Amy Trefl, 14 Lily Code, 15 Taj Shand, 16 Archer Lamble, 20 Jack Potter | 35 256 |
| Limón | 2 Kayla Woodcock, 3 Hudson Onslow, 6 Sophia Hinton, 8 Anthony Grosse, 13 Hudson Hollinworth | 35 254 |

El cálculo también se probó con datos simulados: 11 vendedores, 3, 6 con volúmenes muy desiguales (de 20 000 a 100 facturas), uno solo y uno que solo tiene pedidos. En todos los casos cada vendedor quedó asignado a una sucursal.

| Tabla | Regla |
|-------|-------|
| `Sales.Orders`, `Sales.OrderLines` | Por el vendedor del pedido |
| `Sales.Invoices`, `Sales.InvoiceLines` | Por el vendedor de la factura |
| `Sales.CustomerTransactions` | Los pagos con factura siguen a su factura; los 26 637 pagos sin factura se reparten por `CustomerTransactionID` par (San José) o impar (Limón) |
| `Warehouse.StockItemTransactions` | Las salidas (228 265) siguen a su factura; las entradas (8 358) siguen a su orden de compra; los 44 ajustes se reparten por `StockItemTransactionID` par o impar |
| `Purchasing.PurchaseOrders`, `PurchaseOrderLines`, `SupplierTransactions` | Por `PurchaseOrderID` par (San José) o impar (Limón): las 2 074 órdenes tienen el mismo contacto, así que no hay un criterio de negocio mejor. Los 366 pagos sin orden se reparten por `SupplierTransactionID` |
| `Warehouse.StockItemHoldings` | Cada sucursal tiene una fila por producto, con la mitad de la existencia original (San José se queda con el sobrante si es impar) |

**Por qué las compras van por sucursal y no centralizadas:** cada compra es una entrada de inventario en una sucursal concreta, y tres estadísticas (reportes 1, 5 y 8) se calculan con compras y deben poder filtrarse por sucursal.

**IDs nuevos sin choques:** las secuencias de San José arrancan en 1 000 000 y las de Limón en 2 000 000 (`05_secuencias.sql`). Un ID nunca se repite entre nodos, y además indica dónde se creó.

**Comprobado** (con consultas cruzadas por linked server):

| Propiedad | Resultado |
|-----------|-----------|
| Completitud | San José + Limón = lo original: 35 256 + 35 254 = 70 510 facturas; 114 176 + 114 089 = 228 265 líneas; 36 834 + 36 761 = 73 595 pedidos; 48 587 + 48 560 = 97 147 pagos; 118 409 + 118 258 = 236 667 movimientos; 1 037 + 1 037 = 2 074 órdenes de compra |
| Disyunción | Ninguna factura, línea, pedido, pago, movimiento ni orden de compra está en las dos sucursales; cada sucursal solo tiene facturas de sus 5 vendedores |
| Reconstrucción | La unión de las dos sucursales devuelve la tabla original; ninguna línea queda sin su factura ni ninguna factura sin su pedido |

#### Vertical: datos sensibles de clientes, proveedores y personas

El enunciado pide que los datos de privacidad y contacto estén en el corporativo y el resto en las sucursales. Cada tabla se parte en dos fragmentos que comparten la llave primaria, así que se pueden volver a unir con un `JOIN` (`03_fragmentacion_vertical.sql`).

| Tabla | Fragmento público (en los tres nodos) | Fragmento sensible (solo en el corporativo) |
|-------|---------------------------------------|---------------------------------------------|
| `Sales.Customers` | `CustomerID`, `CustomerName`, `BillToCustomerID`, `CustomerCategoryID`, `BuyingGroupID`, `DeliveryMethodID`, `DeliveryCityID`, `PostalCityID`, `CreditLimit`, `AccountOpenedDate`, `StandardDiscountPercentage`, `IsStatementSent`, `IsOnCreditHold`, `PaymentDays`, `DeliveryRun`, `RunPosition` | `PrimaryContactPersonID`, `AlternateContactPersonID`, `PhoneNumber`, `FaxNumber`, `WebsiteURL`, direcciones de entrega y postal, códigos postales, `DeliveryLocation` |
| `Purchasing.Suppliers` | `SupplierID`, `SupplierName`, `SupplierCategoryID`, `DeliveryMethodID`, `DeliveryCityID`, `PostalCityID`, `SupplierReference`, `PaymentDays` | Contactos, **datos bancarios**, teléfono, fax, sitio web, direcciones, códigos postales, ubicación, `InternalComments` |
| `Application.People` | `PersonID`, `FullName`, `PreferredName`, `SearchName`, `IsEmployee`, `IsSalesperson` | `PhoneNumber`, `FaxNumber`, `EmailAddress`, `LogonName`, `HashedPassword`, permisos de inicio de sesión, `Photo`, `UserPreferences`, `CustomFields` |

- **La ciudad se queda en las sucursales** porque no es un dato de contacto y la necesitan las ventas y el reporte 10. La dirección exacta, el código postal y la ubicación en el mapa sí son sensibles.
- En el corporativo, el fragmento sensible vive en `Sales.CustomersSensible`, `Purchasing.SuppliersSensible` y `Application.PeopleSensible`. Las vistas `vClientesCompletos`, `vProveedoresCompletos` y `vPersonasCompletas` reconstruyen la tabla original.
- En las sucursales, las columnas sensibles también se quitaron del historial (`*_Archive`), para que no quede ninguna copia.
- Los procedimientos leen el fragmento sensible con los sinónimos `Syn_*Sensible`: en el corporativo apuntan a sus tablas y en las sucursales al corporativo. La ubicación viaja como `Latitud` y `Longitud`, porque el tipo `geography` no se puede leer por linked server.
- Crear, editar y borrar clientes y proveedores escribe en los dos fragmentos dentro de la misma transacción, y solo funciona en el corporativo. Antes de borrar, el procedimiento revisa por linked server que no tenga ventas ni compras en ninguna sucursal; si una sucursal no responde, no borra.

#### Replicada completa: catálogos

| Grupo | Tablas | Quién las modifica |
|-------|--------|--------------------|
| Productos | `Warehouse.StockItems`, `StockGroups`, `StockItemStockGroups`, `Colors`, `PackageTypes` | El administrador de cualquier sucursal |
| Clientes, proveedores y personas (fragmento público) | `Sales.Customers`, `Purchasing.Suppliers`, `Application.People` | Solo el corporativo |
| Usuarios del sistema | `Seguridad.Usuarios` | Solo el corporativo |
| Listas de referencia | Ciudades, provincias, países, métodos de entrega y de pago, categorías, grupos de compra | Nadie: quedan iguales desde la restauración |

### 3.2 Asignación

| Tabla o fragmento | Corporativo | San José | Limón | Por qué |
|-------------------|:-----------:|:--------:|:-----:|---------|
| Ventas, pedidos, compras y movimientos | Sí (copia para estadísticas) | Sí, los suyos | Sí, los suyos | Rendimiento: cada sucursal factura sin depender de la red |
| Inventario (`StockItemHoldings`) | Sí (copia para estadísticas) | Sí, el suyo | Sí, el suyo | Cada sucursal maneja sus propias existencias |
| Datos sensibles de clientes, proveedores y personas | Sí | No | No | Privacidad: los datos de contacto y bancarios quedan en un solo lugar controlado |
| Datos públicos de clientes, proveedores y personas | Sí (maestro) | Sí (copia) | Sí (copia) | Las ventas necesitan el cliente y el vendedor en el mismo nodo |
| Catálogo de productos | Sí | Sí | Sí | Todas venden los mismos productos |
| Usuarios del sistema | Sí (maestro) | Sí (copia) | Sí (copia) | Se administran en un solo lugar; la copia permite iniciar sesión en la sucursal aunque el corporativo no responda |
| Tablas y vistas `Resumen` | Sí | No | No | El corporativo calcula las estadísticas por sucursal o consolidadas sin cargar a las sucursales ni depender de que respondan |

### 3.3 Replicación

El corporativo es el **distribuidor**; las suscripciones son *push* y todos los agentes corren en el corporativo con el login `wwi_replicacion`, que no es administrador del servidor (`07_preparar_replicacion.sql`, `08_replicacion.sql`, `09_replicaciones_ventas.sql`).

| Publicación | Tipo | Publica | Tablas | Frecuencia | Por qué |
|-------------|------|---------|--------|------------|---------|
| `PubCatalogo` | **Merge** | Corporativo | Las 5 tablas de productos | Cada minuto | Se modifica desde cualquier sucursal: merge sincroniza en ambos sentidos y resuelve los conflictos |
| `PubDatos` | Transaccional | Corporativo | Fragmento público de clientes, proveedores y personas | Continua | Solo cambian en el corporativo; llegan en segundos |
| `PubUsuarios` | Transaccional | Corporativo | `Seguridad.Usuarios` (contraseña cifrada) | Continua | Permite iniciar sesión en cualquier nodo |
| `PubVentasSJ`, `PubVentasLI` | Transaccional | Cada sucursal | Facturas, líneas, compras, líneas de compra, movimientos y existencias, solo con las columnas que usan las estadísticas | Continua | El corporativo necesita las ventas de las sucursales para las estadísticas |

- **Productos y clientes se suscriben sin snapshot,** porque en las sucursales esas tablas no se pueden borrar (las facturas y existencias las referencian) y ya son idénticas, ya que salen del mismo respaldo. Antes de suscribir, el script desactiva el historial de las tablas temporales (la replicación no las acepta), agrega la columna `rowguid` de merge con los mismos valores en los tres nodos y ejecuta la primera sincronización.
- **Las ventas llegan al corporativo** en el esquema `Resumen` (`Facturas_SJ`, `LineasFactura_LI`…), con snapshot. Las vistas `Resumen.vFacturas`, `vLineasFactura`, `vCompras`, `vLineasCompra`, `vMovimientos` y `vExistencias` unen las dos sucursales con una columna `Sucursal` (`SJ` o `LI`), y los sinónimos del corporativo apuntan a ellas. Así las 10 estadísticas reciben `@Sucursal`: `SJ`, `LI` o `NULL` para el consolidado.
- **Borrar un producto replicado:** `SP_DeleteStockItem` revisa antes, por linked server, que el producto no tenga ventas, compras, movimientos ni existencias en la otra sucursal. Si las tiene o la sucursal no responde, no lo borra; así el borrado replicado nunca falla en otro nodo.
- WWI trae un índice *columnstore* en `StockItemTransactions` que la replicación no acepta (error 35353). En las sucursales se reemplaza por la llave primaria agrupada.

**Comprobado:**

| Prueba | Resultado |
|--------|-----------|
| Producto creado y editado en San José | Llega al corporativo en el mismo ciclo y a Limón en el siguiente (≤ 2 min) |
| San José y Limón editan el mismo producto (Limón 5 s después) | Los tres nodos quedan con el cambio de Limón y el conflicto queda registrado |
| Cliente editado en el corporativo | Llega a las dos sucursales en menos de 15 s |
| Borrar en San José un producto con ventas, o en Limón uno que San José tiene en bodega | Rechazado con mensaje claro |
| Tablas `Resumen` | Tienen exactamente las mismas filas que cada sucursal (35 256 facturas de San José y 35 254 de Limón); una venta nueva llega en menos de 15 s y al borrarla también se borra allá |

### 3.4 Vistas materializadas del corporativo

`12_vistas_indexadas.sql`. SQL Server no permite indexar una vista con `UNION ALL`, así que se materializa cada sucursal por separado y el consolidado une los índices ya calculados:

| Vista | Qué guarda | Índice |
|-------|------------|--------|
| `Resumen.ivVentasMes_SJ` / `_LI` | Por año y mes: líneas (`COUNT_BIG(*)`), unidades, monto (`SUM(ExtendedPrice)`) y ganancia (`SUM(LineProfit)`) | `UNIQUE CLUSTERED INDEX (Anio, Mes)` |
| `Resumen.ivComprasMes_SJ` / `_LI` | Por año y mes: líneas, bultos y monto esperado | Igual |
| `Resumen.vVentasMes`, `vComprasMes` | Consolidado con columna `Sucursal`: une las vistas indexadas leyendo sus índices con `WITH (NOEXPAND)` | No tiene índice propio: lee los índices de las vistas indexadas |

- Son `WITH SCHEMABINDING`, usan solo `INNER JOIN`, `COUNT_BIG(*)` y `SUM` sobre expresiones que no pueden ser `NULL`, como exige SQL Server. Cuentan líneas y no facturas porque `COUNT(DISTINCT)` no se permite en una vista indexada.
- SQL Server mantiene los índices solo: cada cambio que la replicación aplica en `Resumen.*` actualiza la fila del mes correspondiente.
- Una tabla con una vista `SCHEMABINDING` encima no se puede borrar. Por eso esos artículos se publican con `pre_creation_cmd = 'delete'`: si la suscripción se reinicializa, el agente vacía las tablas y las vuelve a llenar en lugar de borrarlas.

**Comprobado:**

| Prueba | Resultado |
|--------|-----------|
| Materializadas | Las 4 vistas tienen índice clúster con 41 filas propias (un mes por fila, de enero de 2013 a mayo de 2016) |
| Mismo resultado que calcular desde cero | 0 filas distintas en las cuatro; el consolidado suma las 228 265 líneas |
| Usan los índices | El total por año desde `vVentasMes` lee 4 páginas de los índices; calcularlo desde las tablas lee 1 991 páginas y usa 1 521 ms de CPU |
| Se mantienen con la replicación | Una venta nueva en San José aparece en `ivVentasMes_SJ` en 8 s; al borrarla, la fila del mes desaparece en 8 s |
| Reinicialización | Reinicializar toda la suscripción de San José vacía y vuelve a llenar las tablas en 27 s; las vistas siguen existiendo y coinciden con el cálculo desde cero |

### 3.5 Concurrencia

| Caso | Problema sin control | Cómo se resuelve |
|------|----------------------|------------------|
| **Dos sucursales modifican el mismo producto** antes de sincronizar | Cada nodo queda con una versión distinta | Merge con el resolvedor *DATETIME (Later Wins)* sobre `LastEditedWhen`: **gana el cambio más reciente** y el que pierde queda registrado en `MSmerge_conflicts_info`. Ninguna sucursal tiene más autoridad que otra sobre el catálogo |
| **Dos ventas del mismo producto** al mismo tiempo (`SP_InsertSale`) | Las dos leen la misma existencia, las dos pasan la revisión y la existencia queda negativa | **Bloqueo pesimista:** dentro de la transacción, la venta lee la existencia de sus productos `WITH (UPDLOCK, ROWLOCK)`. Otra venta de esos productos espera hasta el `COMMIT`, lee la existencia ya descontada y, si no alcanza, recibe el error `50015`. Ventas de productos distintos no se esperan entre sí |
| **Dos usuarios editan el mismo producto**, o una venta ocurre mientras alguien lo edita (`SP_UpdateStockItem`) | El último en guardar sobrescribe el cambio del otro, o devuelve la existencia a un valor viejo y "borra" la venta | **Control optimista:** el detalle devuelve una `Version` (fecha de edición del producto, que también cambia cuando llega una edición replicada desde otro nodo, y fecha de edición de su existencia, que cambia con cada venta). Al guardar, el procedimiento la compara con `UPDLOCK` dentro de la transacción y, si cambió, lanza `50026` («Otro usuario modificó este producto…»); la API responde `409` |

`Version` viaja como texto porque JavaScript solo guarda milisegundos y `datetime2` tiene precisión de 100 nanosegundos.

**Comprobado:**

| Prueba | Resultado |
|--------|-----------|
| Una sesión revisa un producto con 5 unidades y tarda 8 s en descontar; mientras tanto otra vende 5 | Procedimiento anterior: las dos venden y la existencia queda en **−5**. Con `UPDLOCK`: la segunda espera, es rechazada con `50015` y la existencia queda en **0** |
| Dos guardados con la misma versión | El primero responde `204`, el segundo `409` |
| Abrir un producto, registrar una venta de 3 unidades y guardar el formulario | `409`: el formulario traía 87 805 unidades y la existencia real era 87 802; la venta no se pierde |
| En la web, otro usuario guarda el producto mientras el formulario está abierto | Se muestra el mensaje de conflicto; al volver a abrirlo y guardar, se actualiza |

### 3.6 Seguridad y encriptación

#### Tabla de usuarios con contraseña cifrada

`06_seguridad.sql` crea en los tres nodos `Seguridad.Usuarios` con `IdUser`, `Username`, `Password` (cifrada, `varbinary`), `FullName`, `Active`, `Rol`, `Email`, `HireDate` y `Sucursal`. La base no acepta un administrador sin sucursal ni un corporativo con sucursal.

| Objeto | Qué es |
|--------|--------|
| `LlaveUsuarios` | Llave simétrica **AES 256** protegida por el certificado `CertUsuarios`, que a su vez está protegido por la master key de la base. La llave se genera con el mismo `KEY_SOURCE` e `IDENTITY_VALUE` en los tres nodos, así que es la misma y cualquier nodo descifra la contraseña replicada |
| `Seguridad.SP_CrearUsuario` | Cifra la contraseña con `EncryptByKey` y guarda el usuario. Solo funciona en el corporativo, que es el maestro |
| `Seguridad.SP_IniciarSesion` | Descifra con `DecryptByKey` y compara dentro de SQL Server. Devuelve solo `IdUser`, `Username`, `FullName`, `Rol` y `Sucursal`, nunca la contraseña |

- La contraseña se cifra con el nombre de usuario como *autenticador*: si se copia la contraseña cifrada de un usuario a otro, ya no se puede descifrar.
- Un usuario que no existe y una contraseña incorrecta dan el mismo mensaje (`50044`), para no revelar qué usuarios existen.
- Usuarios de ejemplo: `admin.sj` (Administrador, SJ), `admin.li` (Administrador, LI) y `corporativo` (Corporativo), con la contraseña `USUARIOS_PASSWORD` de `Docker/.env`.

#### Usuarios de la aplicación y usuarios de la base de datos

La API nunca se conecta con `sa`. Cada usuario de la aplicación trabaja con el usuario de base de datos de su rol, que solo existe en su nodo y solo tiene `EXECUTE` sobre los procedimientos de su rol (`11_usuarios_bd.sql`):

| Usuario de la aplicación | Nodo | Usuario de BD | Rol de BD | Puede ejecutar |
|--------------------------|------|---------------|-----------|----------------|
| (inicio de sesión) | Los tres | `app_login` | `rol_login` | Solo `Seguridad.SP_IniciarSesion` |
| Administrador SJ | San José | `app_admin_sj` | `rol_administrador` | Productos (todo), ventas (consultar y crear), consulta de clientes y proveedores, catálogos |
| Administrador LI | Limón | `app_admin_li` | `rol_administrador` | Igual |
| Corporativo | Corporativo | `app_corporativo` | `rol_corporativo` | Clientes y proveedores (todo), consulta de productos, las 10 estadísticas, catálogos |

- Ningún rol lee ni modifica tablas directamente: un `SELECT` o un procedimiento de otro rol da el error 229.
- `app_admin_sj` no puede ni conectarse a Limón o al corporativo (error 18456).
- Los procedimientos con SQL dinámico rompen el encadenamiento de propiedad, así que tienen el `SELECT` mínimo sobre lo que consulta ese SQL: el administrador sobre las tablas que revisa `SP_ProductoEnUso` y el corporativo sobre los cuatro sinónimos que lee la matriz de ventas. No se usó `EXECUTE AS OWNER` porque con un contexto suplantado los linked servers fallan, salvo con `TRUSTWORTHY`, que es menos seguro.
- Los linked servers se crean sin cadena de proveedor: con ella, SQL Server los rechaza para todo login que no sea administrador (error 7416).

**Doble barrera:** la API revisa el rol del token antes de llegar a la base (sección 6), y la base vuelve a revisar con los permisos del usuario de BD. Aunque la web o la API tuvieran un error, la base no deja hacer lo que el rol no permite.

### 3.7 Plan de fallas

Cómo responde el sistema cuando un nodo no responde:

- **Tiempos límite:** los linked servers esperan 5 s para conectar y 30 s por consulta; la API espera 5 s para conectar. Un nodo caído responde con error en vez de dejar la pantalla colgada.
- **La API sigue funcionando:** solo quien necesita el nodo caído recibe `503` («El nodo … no responde»). Cuando el nodo vuelve, la siguiente petición se reconecta sin reiniciar la API.
- **Inicio de sesión:** se intenta en el corporativo y, si no responde, en San José y luego en Limón, que tienen la tabla de usuarios replicada.
- **Degradación en lugar de error:** los procedimientos que leen datos de contacto del corporativo (`SP_CLIENTES`, `SP_GetSupplierDetails`, `SP_SearchCustomers`) llaman primero a su versión `_ConContacto` dentro de un `TRY`. Si el linked server falla, el `CATCH` llama a la versión `_SinContacto`, que devuelve las mismas columnas con los datos de la sucursal, «No disponible: el corporativo no responde» y `ContactoDisponible = 0`. La consulta remota va en otro procedimiento porque el error puede ocurrir al compilarla, y un `TRY/CATCH` del mismo nivel no atrapa errores de compilación.
- **Aviso en la web:** `GET /api/estado-nodos` prueba los tres nodos. La web lo consulta cada 20 s y apenas recibe un `503`, y muestra solo los nodos caídos que afectan al usuario, con lo que deja de funcionar para él.
- **Recuperación:** la replicación guarda los cambios hechos durante la caída y los entrega cuando el nodo vuelve.

| Nodo caído | Sigue funcionando | No funciona | Al volver |
|------------|-------------------|-------------|-----------|
| **Corporativo** | Las dos sucursales: iniciar sesión, ventas (consultar y crear), productos (todo), lista y detalle de clientes y proveedores con los datos de la sucursal | Datos de contacto y bancarios; estadísticas; administración de clientes y proveedores; intercambio de productos entre sucursales | Los cambios de productos llegan al corporativo y a la otra sucursal, y las ventas a las tablas `Resumen` |
| **San José o Limón** | La otra sucursal, sin cambios. El corporativo: estadísticas, con los datos de esa sucursal hasta la última sincronización | Todo lo del administrador de esa sucursal (`503` y aviso) | Recibe los cambios de productos y envía sus ventas pendientes |

**Comprobado** (con `docker stop` y `docker start`):

| Prueba | Resultado |
|--------|-----------|
| Corporativo apagado, `admin.sj` | Inicia sesión por San José; los detalles de cliente y proveedor muestran los datos de la sucursal (8 a 12 s); el buscador de clientes funciona sin contacto propuesto; se crea una venta y se edita un producto; la web muestra el aviso |
| Corporativo de vuelta | El producto editado llega al corporativo en segundos y a Limón en 72 s; la venta llega a `Resumen.Facturas_SJ`; los detalles vuelven completos y el aviso desaparece solo |
| Limón apagado | `admin.li` inicia sesión por el corporativo y recibe `503` con el aviso de su sucursal; `admin.sj` sigue igual; el corporativo consulta las estadísticas de Limón con los datos que ya tenía |
| Limón de vuelta | `admin.li` vuelve a trabajar sin reiniciar la API |

---

## 4. Roles

| Rol | Nodo | Clientes y proveedores | Productos | Ventas | Estadísticas |
|-----|------|------------------------|-----------|--------|--------------|
| **Administrador** | Su sucursal | Consultar | Consultar, crear, modificar y eliminar | Consultar y crear (las de su sucursal) | Sin acceso |
| **Corporativo** | Corporativo | Consultar, crear, modificar y eliminar | Consultar | Sin acceso | Consultar, por sucursal o consolidadas |

El enunciado define lo mínimo de cada rol: el administrador consulta clientes, proveedores, productos y facturas de su negocio y administra los productos; el corporativo consulta las estadísticas. Como también pide que **se mantengan las funcionalidades del Proyecto 1**, se conservaron las que ya existían, asignadas al rol que tiene sentido:

- **Administrar clientes y proveedores queda en el corporativo**, porque ahí están sus datos sensibles y es el maestro que los replica a las sucursales. Si lo hiciera el administrador, tendría que escribir por linked server en los datos sensibles de otro nodo.
- **Crear ventas queda en el administrador**, porque cada sucursal maneja su propia facturación. Modificar y eliminar ventas no se permite a nadie: una factura emitida no debe alterarse.

---

## 5. Aplicación web

**Lo nuevo del Proyecto 2:**

- **Inicio de sesión:** usuario y contraseña; la sesión se guarda en la pestaña y se cierra con el botón de la barra superior, que muestra el nombre, el rol y la sucursal del usuario conectado.
- **Menú según el rol:** el administrador ve clientes, proveedores, productos y ventas; el corporativo ve clientes, proveedores, productos y estadísticas. Los botones de crear, editar y eliminar solo aparecen donde el rol puede usarlos.
- **Selector de sucursal en las estadísticas:** Consolidado, San José o Limón.
- **Conflicto de edición:** si otro usuario modificó el producto mientras el formulario estaba abierto, se muestra el mensaje y no se guarda.
- **Aviso de nodos caídos** en la parte inferior de la pantalla, y aviso dentro del detalle cuando los datos de contacto no están disponibles.

**Lo que se mantiene del Proyecto 1:** cada módulo tiene tabla de resultados, filtros acumulativos, botón «Restaurar filtros», orden alfabético, paginación en el servidor y ventana de detalle.

| Módulo | Filtros | Detalle | Gestión |
|--------|---------|---------|---------|
| Clientes | Nombre, categoría, método de entrega | Datos generales, contactos, dirección, teléfono, sitio web y mapa | Crear, editar y eliminar (corporativo) |
| Proveedores | Nombre, categoría, método de entrega | Datos generales, contactos, dirección, mapa y datos bancarios | Crear, editar y eliminar (corporativo) |
| Productos | Nombre, grupo, rango de existencia | Proveedor (enlace), empaques, precios, existencia y ubicación | Crear, editar y eliminar (administrador) |
| Ventas | Cliente, rango de fechas y de montos | Encabezado de la factura y sus líneas con impuestos | Crear ventas con varias líneas; la existencia se valida y se descuenta (administrador) |
| Estadísticas | Los de cada reporte, más la sucursal | Los 10 reportes del Proyecto 1 | Solo consulta |

Los formularios usan listas y buscadores en lugar de pedir IDs, y todas las validaciones de negocio están en los procedimientos almacenados.

---

## 6. API

Node.js con Express (`Api/`).

- **Un pool por nodo y por usuario de base de datos** (`db.js`), creado la primera vez que se usa. Si un nodo está caído, la API arranca igual.
- **Inicio de sesión con JWT** (`auth.js`): `POST /api/auth/login` valida con `Seguridad.SP_IniciarSesion` y devuelve un token de 8 horas con el rol, la sucursal y el nodo del usuario. Cada petición lleva `Authorization: Bearer <token>` y se ejecuta en el nodo del usuario con el usuario de BD de su rol.
- **Rutas por rol** (`roles.js`): antes de llegar a la base se revisa que el rol pueda usar ese método en ese módulo; si no, `403` («Su rol no tiene acceso a esta operación»).
- **Códigos HTTP:** `400` datos inválidos o errores de negocio del procedimiento (`THROW 50000+`); `401` sin sesión o sesión vencida; `403` sin permiso; `409` conflicto de edición; `503` nodo caído; `500` errores internos.
- Todas las consultas son procedimientos almacenados con parámetros tipados; no hay SQL armado con texto ni cálculos en la API.

La referencia completa de rutas está en la [sección 10](#10-referencia-de-la-api).

---

## 7. Instalación y ejecución

### Requisitos

- Docker Desktop, con al menos 7 GB de memoria para los contenedores (los tres nodos usan unos 4.5 GB en la práctica).
- Node.js 20 o superior.
- El respaldo `WideWorldImporters-Full.bak` ([descarga](https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0)).

### 1. Nodos

1. Copiar `WideWorldImporters-Full.bak` a `Docker/backup/`.
2. Crear `Docker/.env` a partir de `Docker/.env.example`:

   | Variable | Para qué |
   |----------|----------|
   | `SA_PASSWORD` | Clave de `sa` en los tres nodos |
   | `ENLACE_PASSWORD` | Login `wwi_enlace` de los linked servers |
   | `LLAVE_ORIGEN`, `LLAVE_IDENTIDAD` | Frases que generan la llave de las contraseñas. No se deben cambiar después de levantar los nodos |
   | `USUARIOS_PASSWORD` | Contraseña de los usuarios de ejemplo (`admin.sj`, `admin.li`, `corporativo`) |
   | `REPLICACION_PASSWORD` | Login `wwi_replicacion` de los agentes |
   | `APP_PASSWORD` | Usuarios de base de datos de la API |

   Las claves deben tener mayúsculas, minúsculas y números, y al menos 8 caracteres.
3. Con Docker Desktop abierto, desde la carpeta `Docker`:

   ```powershell
   .\levantar.ps1
   ```

   En Linux o macOS: `./levantar.sh`. Desde cero tarda entre 10 y 15 minutos.

| Paso | Script | Qué hace |
|-----:|--------|----------|
| 1 | `Docker/nodos/*.yml` | Levanta los tres contenedores en la red `wwi-net` |
| 2 | `levantar.ps1` (`RESTORE DATABASE`) | Restaura la base en cada nodo |
| 3 | `00_login_enlace.sql` | Login `wwi_enlace` en cada nodo |
| 4 | `01_linked_servers.sql` | Linked servers en malla, con tiempos límite |
| 5 | `02_distribuidor.sql` | El corporativo como distribuidor de la replicación |
| 6 | `03_fragmentacion_vertical.sql` | Separa los datos sensibles |
| 7 | `04_fragmentacion_horizontal.sql` | Reparte ventas, compras e inventario entre las sucursales |
| 8 | `05_secuencias.sql` | Rangos de IDs por sucursal |
| 9 | `06_seguridad.sql` | Tabla de usuarios cifrada, llave, login y usuarios de ejemplo |
| 10 | `07_preparar_replicacion.sql` | Login `wwi_replicacion` y preparación de las tablas |
| 11 | `Script/sql`, `Script/CRUD` | Sinónimos y procedimientos en los tres nodos |
| 12 | `08_replicacion.sql` | Publicaciones del corporativo y primera sincronización |
| 13 | `09_replicaciones_ventas.sql` | Publicaciones de ventas de cada sucursal hacia el corporativo |
| 14 | `10_vistas_resumen.sql` | Vistas `Resumen` y sinónimos del corporativo |
| 15 | `12_vistas_indexadas.sql` | Vistas materializadas |
| 16 | `Script/estadisticas` | Las 10 estadísticas, en el corporativo |
| 17 | `11_usuarios_bd.sql` | Usuarios de base de datos por rol |
| 18 | `verificar.ps1` | Estado de cada nodo |

Se puede volver a correr sin perder datos: los pasos de fragmentación quedan registrados en `dbo.ControlFragmentacion` y los de replicación revisan lo que ya existe.

Si aparece «Aviso: un agente de replicacion ya estaba en marcha por su horario», no es un error: el script intentó arrancar un agente de replicación que SQL Server Agent ya había puesto en marcha, y continúa. Cualquier otro error sí detiene el script.

### 2. API

Crear `Api/.env` a partir de `Api/.env.example`:

```env
PORT=3001
DB_HOST=localhost
DB_PORT_CORPORATIVO=1441
DB_PORT_SANJOSE=1442
DB_PORT_LIMON=1443
APP_PASSWORD="<la misma APP_PASSWORD de Docker/.env>"
JWT_SECRET=<frase larga y aleatoria>
```

La clave va entre comillas si tiene `#`, porque `dotenv` toma lo que sigue como comentario. Desde la carpeta `Api`:

```bash
npm install
node index.js
```

### 3. Aplicación web

Desde la carpeta `WebSite`:

```bash
npm install
npm run dev
```

Abrir `http://localhost:5173` e iniciar sesión con `admin.sj`, `admin.li` o `corporativo`.

### Comandos útiles

| Para | Comando |
|------|---------|
| Ver el estado de los nodos (sistema, motor, Agent, datos, replicación, vistas indexadas, usuarios y linked servers) | `.\verificar.ps1` desde `Docker` |
| Simular la caída de un nodo | `docker stop limon` (o `sanjose`, `corporativo`) |
| Volver a encenderlo | `docker start limon`; en uno o dos minutos recibe los cambios pendientes |
| Apagar los tres nodos sin perder datos | `docker stop corporativo sanjose limon` |
| Empezar desde cero (borra las bases) | `docker rm -f corporativo sanjose limon`, luego `docker volume rm pry2-bases-2_corporativo-data pry2-bases-2_sanjose-data pry2-bases-2_limon-data` y luego `.\levantar.ps1` |

Las consultas a las vistas indexadas necesitan `QUOTED_IDENTIFIER ON` (`sqlcmd -I`, activo por defecto en SSMS).

---

## 8. Estructura del repositorio

```
├── Script/                          # Todo el código SQL
│   ├── distribuido/                 # Proyecto 2, en el orden en que se ejecutan
│   │   ├── 00_login_enlace.sql      # Login de los linked servers
│   │   ├── 01_linked_servers.sql    # Linked servers en malla
│   │   ├── 02_distribuidor.sql      # Distribuidor de la replicación
│   │   ├── 03_fragmentacion_vertical.sql
│   │   ├── 04_fragmentacion_horizontal.sql
│   │   ├── 05_secuencias.sql
│   │   ├── 06_seguridad.sql         # Usuarios y encriptación
│   │   ├── 07_preparar_replicacion.sql
│   │   ├── 08_replicacion.sql       # Productos, clientes y usuarios
│   │   ├── 09_replicaciones_ventas.sql
│   │   ├── 10_vistas_resumen.sql
│   │   ├── 11_usuarios_bd.sql       # Usuarios de base de datos por rol
│   │   ├── 12_vistas_indexadas.sql  # Vistas materializadas
│   │   └── 99_verificar_nodo.sql    # Lo usa verificar.ps1
│   ├── sql/                         # Sinónimos y consultas de cada módulo
│   ├── CRUD/                        # Insertar, actualizar y eliminar de cada módulo
│   └── estadisticas/                # Los 10 reportes
├── Docker/
│   ├── nodos/                       # corporativo.yml, sanjose.yml, limon.yml
│   ├── levantar.ps1 / levantar.sh   # Levanta e instala todo
│   └── verificar.ps1 / verificar.sh # Estado de los nodos
├── Api/
│   ├── index.js                     # Servidor y registro de rutas
│   ├── db.js                        # Pools por nodo y usuario de BD
│   ├── auth.js                      # Inicio de sesión con JWT y nodo del usuario
│   ├── roles.js                     # Qué rol puede usar cada ruta
│   └── routes/                      # Una ruta por módulo, más estado.js
└── WebSite/
    └── src/
        ├── App.jsx                  # Sesión, menú por rol y navegación
        ├── Api.js                   # Llamadas a la API con el token
        ├── permisos.js              # Módulos y acciones de cada rol
        ├── pages/                   # Login, Inicio, Clientes, Proveedores, Productos, Ventas, Estadísticas
        └── components/              # Tabla, Filtros, Detalle, Factura, Mapa, AvisoNodos…
```

---

## 9. Decisiones sobre los datos

Decisiones del Proyecto 1 que siguen vigentes:

- **Subcategoría en los reportes 7 y 8:** WideWorldImporters no tiene subcategorías, pero un producto puede pertenecer a varios grupos. La *categoría* y la *subcategoría* son dos grupos de producto y el reporte toma los productos que pertenecen a ambos.
- **Impuesto en las ventas:** el `ExtendedPrice` de cada línea ya incluye el impuesto, igual que en la base original.
- **Matriz de ventas (reporte 6):** los datos terminan en mayo de 2016, por eso ese año aparece incompleto. Un producto en varios grupos suma su venta en cada uno.
- **Rotación de inventario (reporte 9):** la base no trae saldo de apertura. Se parte de la existencia actual y se retrocede con los movimientos, usando el saldo inicial mínimo que evita inventarios negativos. *Rotación = unidades vendidas ÷ inventario promedio*.
- **Eliminar registros con historial:** un cliente, proveedor o producto con ventas, compras o movimientos no se puede eliminar; el procedimiento revierte la transacción y devuelve un mensaje claro.

---

## 10. Referencia de la API

URL base: `http://localhost:3001/api`. Todas las rutas, salvo `/salud` y `/auth/login`, requieren `Authorization: Bearer <token>`.

### Sesión (`/auth`)

| Método | Ruta | Procedimiento | Cuerpo / respuesta |
|--------|------|---------------|--------------------|
| POST | `/auth/login` | `Seguridad.SP_IniciarSesion` | Recibe `{ usuario, contrasena }`; devuelve `{ token, usuario: { IdUser, Username, FullName, Rol, Sucursal, nodo }, nodoLogin }`. `401` si el usuario o la contraseña son incorrectos |
| GET | `/auth/yo` | Ninguno: lee el token | Datos del usuario del token |

### Estado de los nodos (`/estado-nodos`)

| Método | Ruta | Respuesta |
|--------|------|-----------|
| GET | `/estado-nodos` | `{ nodos: [{ nodo, responde, ms }], revisado }` para el corporativo, San José y Limón |

### Clientes (`/clientes`)

| Método | Ruta | Procedimiento | Rol | Parámetros |
|--------|------|---------------|-----|------------|
| GET | `/clientes` | `SP_LISTA_CLIENTES` | Ambos | `?apodo=` `&categoria=` `&metodo=` |
| GET | `/clientes/:nombre` | `SP_CLIENTES` | Ambos | Nombre del cliente |
| POST | `/clientes` | `SP_InsertCustomer` | Corporativo | Cuerpo JSON |
| PUT | `/clientes/:id` | `SP_UpdateCustomer` | Corporativo | Cuerpo JSON |
| DELETE | `/clientes/:id` | `SP_DeleteCustomer` | Corporativo | ID del cliente en la ruta |

### Proveedores (`/proveedores`)

| Método | Ruta | Procedimiento | Rol | Parámetros |
|--------|------|---------------|-----|------------|
| GET | `/proveedores` | `SP_GetSuppliers` | Ambos | `?name=` `&categoria=` `&metodo=` |
| GET | `/proveedores/categorias` | `SP_GetSupplierCategories` | Ambos | Sin parámetros |
| GET | `/proveedores/:id` | `SP_GetSupplierDetails` | Ambos | ID del proveedor en la ruta |
| POST | `/proveedores` | `SP_InsertSupplier` | Corporativo | Cuerpo JSON |
| PUT | `/proveedores/:id` | `SP_UpdateSupplier` | Corporativo | Cuerpo JSON |
| DELETE | `/proveedores/:id` | `SP_DeleteSupplier` | Corporativo | ID del proveedor en la ruta |

### Productos (`/productos`)

| Método | Ruta | Procedimiento | Rol | Parámetros |
|--------|------|---------------|-----|------------|
| GET | `/productos` | `SP_GetStockItems` | Ambos | `?name=` `&grupo=` `&min=` `&max=` |
| GET | `/productos/grupos` | `SP_GetStockGroups` | Ambos | Sin parámetros |
| GET | `/productos/:id` | `SP_GetStockItemDetails` | Ambos | Devuelve también `Version` |
| POST | `/productos` | `SP_InsertStockItem` | Administrador | Cuerpo JSON |
| PUT | `/productos/:id` | `SP_UpdateStockItem` | Administrador | Cuerpo JSON con `Version`; `409` si otro usuario modificó el producto |
| DELETE | `/productos/:id` | `SP_DeleteStockItem` | Administrador | ID del producto en la ruta |

### Ventas (`/ventas`)

| Método | Ruta | Procedimiento | Rol | Parámetros |
|--------|------|---------------|-----|------------|
| GET | `/ventas` | `SP_GetSales` + `SP_GetSalesCount` | Administrador | `?cliente=` `&desde=` `&hasta=` `&min=` `&max=` `&pagina=` `&porPagina=` |
| GET | `/ventas/:id` | `SP_GetSaleHeader` + `SP_GetSaleDetails` | Administrador | Número de factura en la ruta |
| POST | `/ventas` | `SP_InsertSale` | Administrador | Cuerpo JSON con `Lineas` |

`PUT` y `DELETE /ventas/:id` existen en la API, pero ningún rol puede usarlos (`403`): una factura emitida no se modifica.

### Estadísticas (`/estadisticas`)

Solo para el rol corporativo. Las 10 rutas aceptan `&sucursal=SJ` o `&sucursal=LI`; sin ese parámetro devuelven el consolidado.

| # | Ruta | Procedimiento | Parámetros |
|---|------|---------------|------------|
| 1 | `/estadisticas/proveedor` | `sp_estadistica_proveedor` | `?proveedor=` `&categoria=` |
| 2 | `/estadisticas/cliente` | `sp_estadistica_cliente` | `?cliente=` `&categoria=` |
| 3 | `/estadisticas/top-productos` | `sp_top5_productos_ganancia` | `?anio=` `&anioFin=` |
| 4 | `/estadisticas/top-clientes` | `sp_top5_clientes_facturas` | `?anioInicio=` `&anioFin=` |
| 5 | `/estadisticas/top-proveedores` | `sp_top5_proveedores_ordenes` | `?anioInicio=` `&anioFin=` |
| 6 | `/estadisticas/matriz` | `sp_matriz_ventas_categoria_anio` | Sin parámetros |
| 7 | `/estadisticas/seguimiento-clientes` | `sp_seguimiento_compras_cliente` | `?cliente=` `&anio=` `&mes=` `&categoriaId=` `&subcategoriaId=` |
| 8 | `/estadisticas/seguimiento-proveedores` | `sp_seguimiento_compras_proveedor` | `?proveedor=` `&anio=` `&mes=` `&categoriaId=` `&subcategoriaId=` |
| 9 | `/estadisticas/rotacion` | `sp_rotacion_inventario` | `?anio=` `&categoria=` `&proveedor=` `&categoriaId=` `&subcategoriaId=` |
| 10 | `/estadisticas/envio-favorito` | `sp_metodo_envio_favorito` | `?anio=` `&mes=` `&catCliente=` `&catProducto=` `&producto=` `&soloFavorito=` |

### Catálogos (`/catalogos`)

Listas y buscadores para formularios y filtros (`Script/sql/sp_catalogos.sql`), para los dos roles.

| Método | Ruta | Procedimiento | Parámetros |
|--------|------|---------------|------------|
| GET | `/catalogos/categorias-clientes` | `SP_GetCustomerCategories` | Sin parámetros |
| GET | `/catalogos/categorias-proveedores` | `SP_GetSupplierCategories` | Sin parámetros |
| GET | `/catalogos/grupos-compra` | `SP_GetBuyingGroups` | Sin parámetros |
| GET | `/catalogos/metodos-entrega` | `SP_GetDeliveryMethods` | Sin parámetros |
| GET | `/catalogos/grupos-productos` | `SP_GetStockGroups` | Sin parámetros |
| GET | `/catalogos/colores` | `SP_GetColors` | Sin parámetros |
| GET | `/catalogos/tipos-paquete` | `SP_GetPackageTypes` | Sin parámetros |
| GET | `/catalogos/proveedores` | `SP_GetSuppliersCatalog` | Sin parámetros |
| GET | `/catalogos/anios` | `SP_GetYears` | `?tipo=ventas\|compras\|inventario` |
| GET | `/catalogos/ciudades` | `SP_SearchCities` | `?criterio=` |
| GET | `/catalogos/personas` | `SP_SearchPeople` | `?criterio=` `&soloVendedores=1` |
| GET | `/catalogos/clientes` | `SP_SearchCustomers` | `?criterio=` |
| GET | `/catalogos/productos` | `SP_SearchStockItems` | `?criterio=` |
