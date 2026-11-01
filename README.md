# Sistema de Gestión Wide World Importers

**Proyecto 1 – Bases de Datos 2**

Aplicación web para gestionar y consultar la base de datos de ejemplo **WideWorldImporters** de Microsoft. Toda la búsqueda, filtrado, agrupación y cálculo de datos se hace en **SQL Server** mediante procedimientos almacenados. La API y la aplicación web solo envían parámetros y muestran los resultados.

---
## Estado Proyecto

Terminado 100%

---

## Integrantes

| Nombre | Carné |
|--------|-------|
| Poll Garro Vargas | 2024129001 |
| Angelo Piedra Castro | 2024101262 |

---

## Video de demostración

[Ver video en YouTube](https://www.youtube.com/watch?v=H7Icamc5sJA)

---

## Contenido

1. [Diseño distribuido (Proyecto 2)](#diseño-distribuido-proyecto-2)
2. [Arquitectura](#arquitectura)
3. [Tecnologías utilizadas](#tecnologías-utilizadas)
4. [Estructura del repositorio](#estructura-del-repositorio)
5. [Instalación y ejecución](#instalación-y-ejecución)
6. [Objetivos alcanzados](#objetivos-alcanzados)
7. [Objetivos no alcanzados y decisiones](#objetivos-no-alcanzados-y-decisiones)
8. [Referencia de la API](#referencia-de-la-api)

---

## Diseño distribuido (Proyecto 2)

### 1. Resumen

| Nodo | Base | Qué guarda |
|------|------|------------|
| **Corporativo** (Plaza Roble, Escazú) | `WWI_Corporativo` | Datos sensibles de clientes, proveedores y personas; maestro de clientes, proveedores y usuarios; resúmenes para las estadísticas |
| **San José** | `WWI_SanJose` | Catálogo compartido (sin datos sensibles); su propio inventario, ventas y compras |
| **Limón** | `WWI_Limon` | Igual que San José, con sus propios datos |

Las tres bases parten de restaurar `WideWorldImporters-Full.bak` y después se borra en cada nodo lo que no le corresponde. Así se conservan las llaves, los tipos y las relaciones originales, y los procedimientos del Proyecto 1 siguen funcionando con cambios mínimos.

### 2. Fragmentación

#### 2.1 Horizontal: inventario, ventas y compras por sucursal

El enunciado pide que cada sucursal maneje su propio inventario y facturación. Cada fila pertenece a una sola sucursal.

**Criterio para los datos existentes: el vendedor.** La base tiene 10 vendedores con unas 7 000 facturas cada uno. Cada vendedor se asigna a una sucursal, y cada factura y cada pedido van a la sucursal de quien los vendió. Revisamos que todos los pedidos tienen el mismo vendedor que su factura, así que nunca queda una factura en una sucursal y su pedido en otra.

| Sucursal | Vendedores (`PersonID`) | Facturas |
|----------|-------------------------|---------:|
| San José | 2 Kayla Woodcock, 3 Hudson Onslow, 6 Sophia Hinton, 7 Amy Trefl, 8 Anthony Grosse | 35 134 |
| Limón | 13 Hudson Hollinworth, 14 Lily Code, 15 Taj Shand, 16 Archer Lamble, 20 Jack Potter | 35 376 |

| Tabla | Regla de fragmentación |
|-------|------------------------|
| `Sales.Orders`, `Sales.OrderLines` | Por el vendedor del pedido |
| `Sales.Invoices`, `Sales.InvoiceLines` | Por el vendedor de la factura |
| `Sales.CustomerTransactions` | Sigue a su factura |
| `Warehouse.StockItemTransactions` | Las salidas (*Stock Issue*, 228 265) siguen a su factura; las entradas (*Stock Receipt*, 8 358) siguen a su orden de compra; los 44 ajustes de inventario se reparten por `StockItemTransactionID` par o impar |
| `Purchasing.PurchaseOrders`, `PurchaseOrderLines`, `SupplierTransactions` | Por `PurchaseOrderID` par (San José) o impar (Limón). Las 2 074 órdenes tienen el mismo contacto, así que no hay un criterio de negocio mejor |

**Por qué las compras van por sucursal y no centralizadas:** el enunciado dice que cada sucursal maneja su propio inventario, y cada compra es una entrada de inventario (*Stock Receipt*) en una sucursal concreta. Además, las estadísticas deben poder filtrarse por sucursal, y tres de ellas se calculan con compras (reportes 1, 5 y 8). Si las compras estuvieran en el corporativo, esos reportes no tendrían sucursal.
| `Warehouse.StockItemHoldings` | Cada sucursal tiene una fila por producto. La existencia actual se reparte a la mitad (San José se queda con el sobrante si es impar) |

Desde ahí, todo lo nuevo se guarda en la sucursal donde está conectado el administrador.

#### 2.2 Vertical: datos sensibles de clientes, proveedores y personas

El enunciado pide que los datos de privacidad y contacto estén en el corporativo y el resto en las sucursales. Cada tabla se parte en dos fragmentos que comparten la llave primaria, así que se pueden volver a unir con un `JOIN` por la llave.

**`Sales.Customers`**

| Fragmento | Columnas |
|-----------|----------|
| Sucursales (público) | `CustomerID`, `CustomerName`, `BillToCustomerID`, `CustomerCategoryID`, `BuyingGroupID`, `DeliveryMethodID`, `DeliveryCityID`, `PostalCityID`, `CreditLimit`, `AccountOpenedDate`, `StandardDiscountPercentage`, `IsStatementSent`, `IsOnCreditHold`, `PaymentDays`, `DeliveryRun`, `RunPosition`, `LastEditedBy` |
| Corporativo (sensible) | `CustomerID`, `PrimaryContactPersonID`, `AlternateContactPersonID`, `PhoneNumber`, `FaxNumber`, `WebsiteURL`, `DeliveryAddressLine1`, `DeliveryAddressLine2`, `DeliveryPostalCode`, `DeliveryLocation`, `PostalAddressLine1`, `PostalAddressLine2`, `PostalPostalCode` |

**`Purchasing.Suppliers`**

| Fragmento | Columnas |
|-----------|----------|
| Sucursales (público) | `SupplierID`, `SupplierName`, `SupplierCategoryID`, `DeliveryMethodID`, `DeliveryCityID`, `PostalCityID`, `SupplierReference`, `PaymentDays`, `LastEditedBy` |
| Corporativo (sensible) | `SupplierID`, `PrimaryContactPersonID`, `AlternateContactPersonID`, `BankAccountName`, `BankAccountBranch`, `BankAccountCode`, `BankAccountNumber`, `BankInternationalCode`, `PhoneNumber`, `FaxNumber`, `WebsiteURL`, `DeliveryAddressLine1`, `DeliveryAddressLine2`, `DeliveryPostalCode`, `DeliveryLocation`, `PostalAddressLine1`, `PostalAddressLine2`, `PostalPostalCode`, `InternalComments` |

**`Application.People`** (contactos de clientes y proveedores, y empleados)

| Fragmento | Columnas |
|-----------|----------|
| Sucursales (público) | `PersonID`, `FullName`, `PreferredName`, `SearchName`, `IsEmployee`, `IsSalesperson`, `LastEditedBy` |
| Corporativo (sensible) | `PersonID`, `PhoneNumber`, `FaxNumber`, `EmailAddress`, `LogonName`, `HashedPassword`, `IsPermittedToLogon`, `Photo`, `UserPreferences`, `CustomFields` |

**Por qué la ciudad se queda en las sucursales:** la ciudad (`DeliveryCityID`) es un dato general, no de contacto, y la necesitan las ventas y el reporte 10 (método de envío según el lugar). La dirección exacta, el código postal y la ubicación en el mapa sí son sensibles y van al corporativo.

#### 2.3 Replicada completa: catálogos

Las tres sucursales tienen el mismo catálogo, así que estas tablas están completas en los tres nodos:

| Grupo | Tablas | Quién las modifica |
|-------|--------|--------------------|
| Productos | `Warehouse.StockItems`, `StockGroups`, `StockItemStockGroups`, `Colors`, `PackageTypes` | Cualquier nodo (el administrador crea, modifica y borra productos) |
| Clientes y proveedores (fragmento público) | `Sales.Customers`, `Purchasing.Suppliers`, `Application.People` (públicos) | Solo el corporativo (rol Corporativo) |
| Listas de referencia | `Application.Cities`, `StateProvinces`, `Countries`, `DeliveryMethods`, `PaymentMethods`, `TransactionTypes`, `Sales.CustomerCategories`, `BuyingGroups`, `Purchasing.SupplierCategories` | Nadie (casi no cambian) |

### 3. Asignación

| Tabla o fragmento | Corporativo | San José | Limón | Por qué |
|-------------------|:-----------:|:--------:|:-----:|---------|
| Ventas, pedidos, compras y movimientos de su sucursal | — | ✔ (los suyos) | ✔ (los suyos) | Rendimiento: cada sucursal factura sin depender de la red |
| Inventario (`StockItemHoldings`) | — | ✔ (el suyo) | ✔ (el suyo) | Cada sucursal tiene sus propias existencias |
| Datos sensibles de clientes, proveedores y personas | ✔ | — | — | Privacidad: los datos de contacto y bancarios quedan en un solo lugar controlado |
| Datos públicos de clientes, proveedores y personas | ✔ (maestro) | ✔ (copia) | ✔ (copia) | Las ventas necesitan el cliente y el vendedor en el mismo nodo |
| Catálogo de productos | ✔ | ✔ | ✔ | Todas venden los mismos productos; se replica cada cambio |
| Listas de referencia | ✔ | ✔ | ✔ | Las usan los formularios y los filtros |
| Usuarios del sistema | ✔ (maestro) | ✔ (copia) | ✔ (copia) | Un solo lugar para administrarlos; la copia permite iniciar sesión en la sucursal aunque el corporativo no responda |
| Resúmenes para estadísticas | ✔ | — | — | El corporativo consulta las estadísticas por sucursal o consolidadas sin cargar a las sucursales |

### 4. Replicación

| Qué | Tipo | Publicador | Suscriptores | Por qué |
|-----|------|------------|--------------|---------|
| Catálogo de productos | **Merge** | Corporativo | San José, Limón | Se modifica desde cualquier nodo; merge sincroniza en ambos sentidos y detecta los conflictos (ver concurrencia) |
| Clientes, proveedores y personas (públicos) y usuarios | **Transaccional** | Corporativo | San José, Limón | Solo cambian en el corporativo; la transaccional los envía casi en tiempo real |
| Listas de referencia | **Snapshot** (o quedan de la restauración) | Corporativo | San José, Limón | Casi no cambian |

El corporativo es también el **distribuidor**. Si una sucursal no responde, sus cambios esperan en cola y se sincronizan cuando vuelve.

**Concurrencia:** si dos sucursales modifican el mismo producto antes de sincronizar, **gana el cambio más reciente**. Se usa el resolvedor de merge *DATETIME (Later Wins)* sobre una columna `LastEditedWhen` que los procedimientos de productos actualizan en cada cambio. El cambio que pierde queda registrado en el visor de conflictos de la replicación. Se eligió así porque ninguna sucursal tiene más autoridad que otra sobre el catálogo, y "gana el último" es la regla más fácil de explicar y de mostrar en la revisión.

Dentro de un mismo nodo, los procedimientos de productos usan transacciones y comparan una columna `rowversion` antes de guardar. Si otro usuario cambió el producto mientras tanto, el procedimiento rechaza el cambio y pide volver a cargarlo, en vez de pisarlo.

**Estadísticas consolidadas:** las vistas indexadas no pueden leer de otro servidor, así que el corporativo guarda **tablas de resumen** con una columna `Sucursal`. Un job del SQL Server Agent las llena desde las sucursales por linked server. Los procedimientos de estadísticas reciben el parámetro `Sucursal` (San José, Limón o consolidado).

### 5. Nombres

| Elemento | Nombre |
|----------|--------|
| Bases | `WWI_Corporativo`, `WWI_SanJose`, `WWI_Limon` |
| Servidores (contenedores) | `corporativo`, `sanjose`, `limon` |
| Linked servers en el corporativo | `LS_SANJOSE`, `LS_LIMON` |
| Columna de sucursal en los resúmenes | `Sucursal` con los valores `SJ` y `LI` |
| Tabla de usuarios (corporativo) | `Seguridad.Usuarios` |
| Usuarios de base de datos para la API | `app_admin_sj`, `app_admin_li`, `app_corporativo` |

### 6. Riesgos a revisar en los bloques siguientes

- `StockItems`, `Customers`, `Suppliers` y `People` son **tablas temporales** (tienen historial con `ValidFrom` y `ValidTo`). La replicación no las acepta así, así que hay que desactivar el historial antes de publicarlas.
- Las columnas sensibles se borran de las tablas en las sucursales. Los procedimientos del Proyecto 1 que las leen (detalle de cliente y de proveedor, mapa) tendrán que traerlas del corporativo por linked server.
- La tabla de usuarios se replica con la contraseña ya encriptada, así que la llave simétrica debe crearse igual en los tres nodos (mismo `KEY_SOURCE` e `IDENTITY_VALUE`).

### 7. Roles

El enunciado define dos roles. Cada usuario tiene un rol y, si es administrador, una sucursal.

| Rol | Nodo al que se conecta | Clientes y proveedores | Productos | Ventas | Estadísticas |
|-----|------------------------|------------------------|-----------|--------|--------------|
| **Administrador** | Su sucursal | Consultar | Consultar, crear, modificar y eliminar | Consultar y crear (las de su sucursal) | — |
| **Corporativo** | Corporativo | Consultar, crear, modificar y eliminar | Consultar | — | Consultar (por sucursal o consolidado) |

- La gestión de clientes y proveedores del Proyecto 1 se mantiene, pero en el corporativo: ahí están sus datos sensibles y es el maestro que los replica a las sucursales.
- Crear ventas se mantiene para el administrador, porque cada sucursal maneja su propia facturación.
- Cada rol usa un usuario de base de datos distinto (`app_admin_sj`, `app_admin_li`, `app_corporativo`) que solo tiene permiso de `EXECUTE` sobre los procedimientos de su rol. Así, aunque la web tuviera un error, la base no deja hacer lo que el rol no permite.

### 8. Decisiones tomadas

1. Vendedores repartidos 5 y 5 como en la sección 2.1.
2. Compras por sucursal (justificado en la sección 2.1).
3. En un conflicto de productos gana el cambio más reciente (sección 4).
4. Dos roles, Administrador y Corporativo, con los permisos de la sección 7.

---

## Arquitectura

```
┌──────────────────┐   HTTP/JSON   ┌──────────────────┐   EXEC SP   ┌───────────────────────────┐
│  WebSite (React) │ ────────────► │   Api (Express)  │ ──────────► │  SQL Server               │
│  Muestra datos y │ ◄──────────── │  Recibe filtros, │ ◄────────── │  Stored procedures        │
│  envía filtros   │               │  ejecuta SPs     │  recordset  │  → Sinónimos → Tablas     │
└──────────────────┘               └──────────────────┘             └───────────────────────────┘
```

- **SQL Server:** los procedimientos almacenados acceden a las tablas únicamente a través de **sinónimos**. Las operaciones de inserción, actualización y borrado usan **transacciones**.
- **API:** cada ruta llama a un único procedimiento almacenado y devuelve el resultado tal cual. No filtra, agrupa ni calcula.
- **WebSite:** presenta los datos en tablas, ventanas de detalle y formularios. No manipula ni agrupa datos: la búsqueda, el filtrado, el orden, la **paginación** (`OFFSET/FETCH`) y el **conteo de resultados** (`COUNT(*) OVER()`) los hacen los procedimientos almacenados; la web solo envía los filtros y el número de página. Las listas de los formularios y filtros (categorías, años, meses, grupos...) también salen de la base.

---

## Tecnologías utilizadas

| Capa | Tecnología |
|------|-----------|
| Base de datos | SQL Server – WideWorldImporters (`WideWorldImporters-Full.bak`) |
| API | Node.js, Express 5, mssql, dotenv, cors |
| Aplicación web | React 19, Vite |
| Mapas | Leaflet + React-Leaflet (OpenStreetMap) |
| Estilos | CSS propio |

---

## Estructura del repositorio

```
├── Script/                          # Todo el código SQL
│   ├── sql/
│   │   ├── sinonimos.sql            # Los 22 sinónimos
│   │   ├── sp_clientes.sql          # Consultas del módulo de clientes
│   │   ├── sp_proveedores.sql       # Consultas del módulo de proveedores
│   │   ├── sp_productos.sql         # Consultas del módulo de productos
│   │   ├── sp_ventas.sql            # Consultas del módulo de ventas
│   │   ├── sp_catalogos.sql         # Listas y buscadores para formularios y filtros
│   │   └── ejemplo_ejecucion.sql    # Script de ejemplo que ejecuta los SPs
│   ├── CRUD/                        # Insert, Update y Delete de cada módulo
│   │   ├── CLIENTES/
│   │   ├── PROVEEDORES/
│   │   ├── PRODUCTOS/
│   │   └── VENTAS/
│   └── estadisticas/                # Los 10 reportes (01_ … 10_)
├── Api/                             # Servicio API
│   ├── index.js                     # Servidor Express y registro de rutas
│   ├── db.js                        # Conexión a SQL Server
│   ├── init.js                      # Carga los scripts SQL al iniciar
│   └── routes/                      # Una ruta por módulo
│       ├── clientes.js
│       ├── proveedores.js
│       ├── productos.js
│       ├── ventas.js
│       ├── estadisticas.js
│       └── .env.example             # Plantilla de variables de entorno
└── WebSite/                         # Aplicación web
    └── src/
        ├── App.jsx                  # Menú y navegación entre módulos
        ├── Api.js                   # Funciones para llamar a la API
        ├── pages/                   # Inicio, Clientes, Proveedores, Productos, Ventas, Estadísticas
        ├── components/              # Tabla, Filtros, Paginación, Detalle, Factura, Mapa
        └── styles/                  # Hojas de estilo
```

---

## Instalación y ejecución

### Nodos del Proyecto 2 (Docker)

Cada nodo es un contenedor con una tecnología distinta:

| Nodo | Puerto | Sistema operativo | Motor |
|------|-------:|-------------------|-------|
| `corporativo` | 1441 | Ubuntu 22.04 | SQL Server 2022 |
| `sanjose` | 1442 | Red Hat Enterprise Linux 9 | SQL Server 2022 |
| `limon` | 1443 | Ubuntu 20.04 | SQL Server 2019 |

1. Copiar `WideWorldImporters-Full.bak` a `Docker/backup/`.
2. Crear `Docker/.env` a partir de `Docker/.env.example` con la clave de `sa`.
3. Con Docker Desktop abierto, desde la carpeta `Docker`:

```powershell
.\levantar.ps1
```

El script levanta los tres contenedores, restaura la base en cada uno (`WWI_Corporativo`, `WWI_SanJose`, `WWI_Limon`), crea los linked servers (`Script/distribuido/01_linked_servers.sql`) y configura el corporativo como distribuidor de la replicación (`Script/distribuido/02_distribuidor.sql`). Se puede correr de nuevo sin perder datos. Docker necesita unos 6 GB de memoria libres para los tres nodos.

### Requisitos

- SQL Server 2019 o superior
- Node.js 20 o superior
- Respaldo `WideWorldImporters-Full.bak` ([descarga](https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0))

### 1. Base de datos

Restaurar `WideWorldImporters-Full.bak` en SQL Server con el nombre `WideWorldImporters`.

### 2. API

Crear el archivo `Api/.env` (la plantilla está en `Api/routes/.env.example`):

```env
DB_USER=sa
DB_PASSWORD=<su clave>
DB_SERVER=localhost
DB_NAME=WideWorldImporters
PORT=3001
```

> La aplicación web espera la API en `http://localhost:3001/api` (ver `WebSite/src/Api.js`).

Desde la carpeta `Api`:

```bash
npm install
node index.js
```

Al iniciar, `init.js` ejecuta automáticamente todos los scripts de `Script/` (sinónimos, consultas, catálogos, CRUD y estadísticas), excepto `ejemplo_ejecucion.sql`, que es para correrlo a mano. **No hace falta correr los scripts a mano.**

### 3. Aplicación web

Desde la carpeta `WebSite`:

```bash
npm install
npm run dev
```

Abrir la dirección que muestra Vite (por defecto `http://localhost:5173`).

### 4. Script de ejemplo (opcional)

```bash
sqlcmd -S localhost -U sa -P '<clave>' -d WideWorldImporters -C -I -i Script/sql/ejemplo_ejecucion.sql
```

La opción `-I` (`QUOTED_IDENTIFIER ON`) es necesaria para los procedimientos de ventas. El script tiene tres partes:

1. Los 10 reportes de estadísticas con filtros de ejemplo.
2. Las búsquedas y detalles de cada módulo.
3. Un ciclo crear → actualizar → eliminar de productos y ventas dentro de una transacción, más una prueba de `ROLLBACK`. La base queda igual que antes.

---

## Objetivos alcanzados

### SQL Server

#### Sinónimos

Se crearon 22 sinónimos en `Script/sql/sinonimos.sql`. Todos los procedimientos usan los sinónimos y nunca el nombre real de la tabla.

`Syn_BuyingGroups`, `Syn_Cities`, `Syn_Colors`, `Syn_Countries`, `Syn_CustomerCategories`, `Syn_Customers`, `Syn_DeliveryMethods`, `Syn_InvoiceLines`, `Syn_Invoices`, `Syn_PackageTypes`, `Syn_People`, `Syn_PurchaseOrderLines`, `Syn_PurchaseOrders`, `Syn_StateProvinces`, `Syn_StockGroups`, `Syn_StockItemHoldings`, `Syn_StockItems`, `Syn_StockItemStockGroups`, `Syn_StockItemTransactions`, `Syn_SupplierCategories`, `Syn_Suppliers`, `Syn_TransactionTypes`.

#### Transacciones

Los procedimientos de inserción, actualización y borrado usan `BEGIN TRANSACTION`, `COMMIT` y `ROLLBACK` dentro de un bloque `TRY/CATCH`. Si algún paso falla, se revierte todo y se devuelve un mensaje de error con `THROW`.

#### Procedimientos de gestión

| Módulo | Listado con filtros | Detalle | Catálogos | Insertar | Actualizar | Eliminar |
|--------|--------------------|---------|-----------|----------|-----------|----------|
| Clientes | `SP_LISTA_CLIENTES` | `SP_CLIENTES` | — | `SP_InsertCustomer` | `SP_UpdateCustomer` | `SP_DeleteCustomer` |
| Proveedores | `SP_GetSuppliers` | `SP_GetSupplierDetails` | `SP_GetSupplierCategories` | `SP_InsertSupplier` | `SP_UpdateSupplier` | `SP_DeleteSupplier` |
| Productos | `SP_GetStockItems` | `SP_GetStockItemDetails` | `SP_GetStockGroups` | `SP_InsertStockItem` | `SP_UpdateStockItem` | `SP_DeleteStockItem` |
| Ventas | `SP_GetSales` | `SP_GetSaleHeader`, `SP_GetSaleDetails` | — | `SP_InsertSale` | `SP_UpdateSale` | `SP_DeleteSale` |

#### Reportes y estadísticas

| # | Procedimiento | Qué muestra | Técnica | Filtros |
|---|---------------|-------------|---------|---------|
| 1 | `sp_estadistica_proveedor` | Monto máximo, mínimo y promedio de compras a proveedores, por proveedor y categoría (`PurchaseOrders`) | `ROLLUP` | Proveedor y categoría (texto libre) |
| 2 | `sp_estadistica_cliente` | Monto máximo, mínimo y promedio de ventas a clientes, por cliente y categoría (`Invoices`) | `ROLLUP` | Cliente y categoría (texto libre) |
| 3 | `sp_top5_productos_ganancia` | Top 5 de productos con más ganancia por año | `DENSE_RANK`, `PARTITION BY` | Año |
| 4 | `sp_top5_clientes_facturas` | Top 5 de clientes con más facturas por año y su monto total | `DENSE_RANK`, `PARTITION BY` | Rango de años |
| 5 | `sp_top5_proveedores_ordenes` | Top 5 de proveedores con más órdenes de compra por año y su monto total | `DENSE_RANK`, `PARTITION BY` | Rango de años |
| 6 | `sp_matriz_ventas_categoria_anio` | Matriz de ventas: categorías de producto (filas) por año (columnas) | `PIVOT` | — |
| 7 | `sp_seguimiento_compras_cliente` | Resumen mensual por cliente: monto total, primera y última factura del mes, cantidad total, mínima y máxima | Agregados por mes | Año, mes y categoría |
| 8 | `sp_seguimiento_compras_proveedor` | Lo mismo que el 7, por proveedor y sus órdenes de compra | Agregados por mes | Año, mes y categoría |
| 9 | `sp_rotacion_inventario` | Rotación de inventario y promedio de días de rotación por producto y año | Inventario promedio | Año, categoría y proveedor |
| 10 | `sp_metodo_envio_favorito` | Método de envío favorito según el lugar al que se envió la venta, ordenado por cantidad de ventas | `DENSE_RANK`, `PARTITION BY` | Año, mes, categoría de cliente, categoría de producto y producto |

Los años de los filtros se validan contra los años existentes en la base de datos.

### API (Node.js + Express)

- Una ruta por módulo: `/api/clientes`, `/api/proveedores`, `/api/productos`, `/api/ventas` y `/api/estadisticas`.
- Todas las consultas se hacen con procedimientos almacenados y parámetros tipados (`mssql`). No hay SQL armado con texto ni cálculos en la API.
- Valida los campos obligatorios antes de llamar al procedimiento.
- Devuelve códigos HTTP apropiados: `400` para datos inválidos o errores de negocio lanzados por el SP (`THROW 50000+`) y `500` para errores internos.
- Al iniciar, `init.js` crea en la base todos los sinónimos y procedimientos de la carpeta `Script/`.

### Aplicación web (React + Vite)

Todos los módulos cumplen con: tabla de resultados, **filtros acumulativos**, botón **Restaurar filtros** que vuelve a consultar todo, **orden alfabético ascendente** por defecto, **paginación** y **ventana de detalle** aparte (con el botón «Ver detalles» o al hacer clic en la fila).

#### Clientes

- **Tabla:** nombre del cliente, categoría y método de entrega.
- **Filtro:** nombre (texto libre, búsqueda por coincidencia parcial).
- **Detalle:** nombre, categoría, grupo de compra, contactos primario y alternativo, cliente por facturar, método de entrega, ciudad de entrega, código postal, teléfono y fax, días de gracia, sitio web (enlace), dirección de entrega y postal, y **mapa** con la ubicación.
- **Filtros:** nombre, categoría y método de entrega.
- **Gestión:** crear, editar y eliminar. El formulario usa listas (categoría, grupo de compra, método de entrega) y buscadores (contactos, cliente por facturar, ciudades) en lugar de pedir IDs. Si el contacto no existe, se escribe su nombre y el procedimiento `SP_ObtenerOCrearPersona` lo crea en `Application.People` dentro de la misma transacción (también en proveedores).

#### Proveedores

- **Tabla:** nombre del proveedor, categoría y método de entrega.
- **Filtros:** nombre (texto libre), categoría y método de entrega (selección).
- **Detalle:** código del proveedor, nombre, categoría, contactos primario y alternativo, método de entrega, ciudad y código postal de entrega, teléfono y fax, sitio web, dirección de entrega y postal, **mapa** con la ubicación, banco, número de cuenta y días de gracia.
- **Gestión:** crear, editar y eliminar.

#### Productos (inventario)

- **Tabla:** nombre del producto, grupo y cantidad en inventario (Holdings).
- **Filtros:** nombre (texto libre), grupo (selección) y rango de cantidad disponible.
- **Detalle:** nombre, proveedor (enlace a su detalle), color, unidad de empaque, empaque exterior, cantidad por empaque, marca, talla, impuesto, precio unitario, precio de venta recomendado, peso, palabras clave, cantidad disponible y ubicación.
- **Gestión:** crear, editar y eliminar. Todo lo del formulario se guarda en la base: el producto (`StockItems`), su inventario inicial y ubicación (`StockItemHoldings`), sus grupos/categorías (`StockItemStockGroups`) y los comentarios de mercadeo. Proveedor, color y empaques se eligen de listas.

#### Ventas

- **Tabla:** número de factura, fecha, cliente, método de entrega y monto.
- **Filtros:** cliente (texto libre), rango de fechas y rango de montos.
- **Detalle (factura):**
  - *Encabezado:* número de factura, cliente (enlace a su detalle), método de entrega, número de orden, persona de contacto, vendedor, fecha e instrucciones de entrega.
  - *Líneas:* producto (enlace a su detalle), cantidad, precio unitario, impuesto aplicado, monto del impuesto y total por línea.
- **Gestión:** crear ventas nuevas con una o varias líneas («+ Agregar producto» / «Eliminar»). Cliente, contacto, vendedor y productos se buscan por nombre; al elegir el producto se proponen su precio e impuesto. El impuesto y los totales los calcula el procedimiento almacenado.
- **Inventario:** al crear una venta se valida que haya existencias suficientes, se descuenta `QuantityOnHand` y se registra el movimiento en `StockItemTransactions` (tipo *Stock Issue*). Al editar o eliminar una venta se devuelve el inventario.
- **Paginación en el servidor:** la tabla recorre las más de 70 000 facturas página por página (`SP_GetSales` + `SP_GetSalesCount`).
- Las validaciones de negocio (nombres repetidos, al menos un grupo por producto, inventario suficiente, quién hizo el cambio `LastEditedBy`) también están en los procedimientos almacenados.

#### Estadísticas

- Selector con los 10 reportes; cada uno muestra solo sus filtros.
- Los años, meses y categorías se eligen de listas cargadas de la base (solo aparecen años con datos).
- Los reportes 7 y 8 se filtran por cliente/proveedor, año, mes, categoría y subcategoría.
- Resultados en tabla con paginación. En los reportes con `ROLLUP`, las filas de subtotal y total general se muestran como «Total».

#### Presentación y usabilidad

- Paleta de colores consistente, diseño adaptable a pantallas pequeñas.
- Validación de formularios y mensajes claros de éxito y error.
- Los campos sin dato se muestran como «Vacío».

---

## Objetivos no alcanzados y decisiones

- **Subcategoría en los reportes 7 y 8:** WideWorldImporters no tiene una tabla de subcategorías, pero un producto puede pertenecer a varios grupos (`StockItemStockGroups`). Por eso la *categoría* y la *subcategoría* son dos grupos de producto: el reporte toma las líneas cuyos productos pertenecen a ambos grupos elegidos.
- **Editar y eliminar ventas desde la web:** una factura emitida no debería alterarse, así que la interfaz solo permite consultar y crear ventas. Los procedimientos `SP_UpdateSale` y `SP_DeleteSale` sí existen con su transacción, están expuestos en la API (`PUT` y `DELETE /api/ventas/:id`) y se prueban en `ejemplo_ejecucion.sql`.
- **Impuesto en las ventas:** el `ExtendedPrice` de cada línea ya incluye el impuesto (cantidad × precio + impuesto), igual que en la base original. El encabezado de la factura obtiene el subtotal, los impuestos y el total a partir de las líneas.
- **Matriz de ventas (reporte 6):** los datos de la base terminan en mayo de 2016, por eso ese año aparece incompleto. Un producto puede estar en varios grupos, así que su venta se suma en cada una de sus categorías.
- **Rotación de inventario (reporte 9):** la base no trae saldo de apertura y los movimientos de compra y venta no cuadran con la existencia actual. Se parte de la existencia actual y se retrocede con los movimientos; si el resultado fuera negativo, se usa el saldo inicial mínimo que evita inventarios negativos. La fórmula es *rotación = unidades vendidas ÷ inventario promedio*, con *inventario promedio = (inicial + final) ÷ 2*. Por la calidad de los datos la rotación sale baja en muchos productos; es una limitación de la base, no del cálculo.
- **Eliminar registros con historial:** un cliente, proveedor o producto con ventas, compras o movimientos no se puede eliminar. El procedimiento revierte la transacción y devuelve un mensaje claro que la web muestra al usuario.

---

## Referencia de la API

URL base: `http://localhost:3001/api`

### Clientes — `/clientes`

| Método | Ruta | Procedimiento | Parámetros |
|--------|------|---------------|------------|
| GET | `/clientes` | `SP_LISTA_CLIENTES` | `?apodo=` `&categoria=` `&metodo=` |
| GET | `/clientes/:nombre` | `SP_CLIENTES` | Nombre del cliente |
| POST | `/clientes` | `SP_InsertCustomer` | Cuerpo JSON |
| PUT | `/clientes/:id` | `SP_UpdateCustomer` | Cuerpo JSON |
| DELETE | `/clientes/:id` | `SP_DeleteCustomer` | — |

### Proveedores — `/proveedores`

| Método | Ruta | Procedimiento | Parámetros |
|--------|------|---------------|------------|
| GET | `/proveedores` | `SP_GetSuppliers` | `?name=` `&categoria=` `&metodo=` |
| GET | `/proveedores/categorias` | `SP_GetSupplierCategories` | — |
| GET | `/proveedores/:id` | `SP_GetSupplierDetails` | — |
| POST | `/proveedores` | `SP_InsertSupplier` | Cuerpo JSON |
| PUT | `/proveedores/:id` | `SP_UpdateSupplier` | Cuerpo JSON |
| DELETE | `/proveedores/:id` | `SP_DeleteSupplier` | — |

### Productos — `/productos`

| Método | Ruta | Procedimiento | Parámetros |
|--------|------|---------------|------------|
| GET | `/productos` | `SP_GetStockItems` | `?name=` `&grupo=` `&min=` `&max=` |
| GET | `/productos/grupos` | `SP_GetStockGroups` | — |
| GET | `/productos/:id` | `SP_GetStockItemDetails` | — |
| POST | `/productos` | `SP_InsertStockItem` | Cuerpo JSON |
| PUT | `/productos/:id` | `SP_UpdateStockItem` | Cuerpo JSON |
| DELETE | `/productos/:id` | `SP_DeleteStockItem` | — |

### Ventas — `/ventas`

| Método | Ruta | Procedimiento | Parámetros |
|--------|------|---------------|------------|
| GET | `/ventas` | `SP_GetSales` + `SP_GetSalesCount` | `?cliente=` `&desde=` `&hasta=` `&min=` `&max=` `&pagina=` `&porPagina=` |
| GET | `/ventas/:id` | `SP_GetSaleHeader` + `SP_GetSaleDetails` | — |
| POST | `/ventas` | `SP_InsertSale` | Cuerpo JSON con `Lineas` |
| PUT | `/ventas/:id` | `SP_UpdateSale` | Cuerpo JSON con `Lineas` |
| DELETE | `/ventas/:id` | `SP_DeleteSale` | — |

### Estadísticas — `/estadisticas`

| # | Ruta | Procedimiento | Parámetros |
|---|------|---------------|------------|
| 1 | `/estadisticas/proveedor` | `sp_estadistica_proveedor` | `?proveedor=` `&categoria=` |
| 2 | `/estadisticas/cliente` | `sp_estadistica_cliente` | `?cliente=` `&categoria=` |
| 3 | `/estadisticas/top-productos` | `sp_top5_productos_ganancia` | `?anio=` `&anioFin=` |
| 4 | `/estadisticas/top-clientes` | `sp_top5_clientes_facturas` | `?anioInicio=` `&anioFin=` |
| 5 | `/estadisticas/top-proveedores` | `sp_top5_proveedores_ordenes` | `?anioInicio=` `&anioFin=` |
| 6 | `/estadisticas/matriz` | `sp_matriz_ventas_categoria_anio` | — |
| 7 | `/estadisticas/seguimiento-clientes` | `sp_seguimiento_compras_cliente` | `?cliente=` `&anio=` `&mes=` `&categoriaId=` `&subcategoriaId=` |
| 8 | `/estadisticas/seguimiento-proveedores` | `sp_seguimiento_compras_proveedor` | `?proveedor=` `&anio=` `&mes=` `&categoriaId=` `&subcategoriaId=` |
| 9 | `/estadisticas/rotacion` | `sp_rotacion_inventario` | `?anio=` `&categoria=` `&proveedor=` |
| 10 | `/estadisticas/envio-favorito` | `sp_metodo_envio_favorito` | `?anio=` `&mes=` `&catCliente=` `&catProducto=` `&producto=` `&soloFavorito=` |

### Catálogos — `/catalogos`

Listas y buscadores para los formularios y filtros (archivo `Script/sql/sp_catalogos.sql`).

| Método | Ruta | Procedimiento | Parámetros |
|--------|------|---------------|------------|
| GET | `/catalogos/categorias-clientes` | `SP_GetCustomerCategories` | — |
| GET | `/catalogos/categorias-proveedores` | `SP_GetSupplierCategories` | — |
| GET | `/catalogos/grupos-compra` | `SP_GetBuyingGroups` | — |
| GET | `/catalogos/metodos-entrega` | `SP_GetDeliveryMethods` | — |
| GET | `/catalogos/grupos-productos` | `SP_GetStockGroups` | — |
| GET | `/catalogos/colores` | `SP_GetColors` | — |
| GET | `/catalogos/tipos-paquete` | `SP_GetPackageTypes` | — |
| GET | `/catalogos/proveedores` | `SP_GetSuppliersCatalog` | — |
| GET | `/catalogos/anios` | `SP_GetYears` | `?tipo=ventas\|compras\|inventario` |
| GET | `/catalogos/ciudades` | `SP_SearchCities` | `?criterio=` |
| GET | `/catalogos/personas` | `SP_SearchPeople` | `?criterio=` `&soloVendedores=1` |
| GET | `/catalogos/clientes` | `SP_SearchCustomers` | `?criterio=` |
| GET | `/catalogos/productos` | `SP_SearchStockItems` | `?criterio=` |
