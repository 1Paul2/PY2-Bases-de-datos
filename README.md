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
| `Sales.CustomerTransactions` | Los pagos con factura siguen a su factura; los 26 637 pagos sin factura se reparten por `CustomerTransactionID` par (San José) o impar (Limón) |
| `Warehouse.StockItemTransactions` | Las salidas (*Stock Issue*, 228 265) siguen a su factura; las entradas (*Stock Receipt*, 8 358) siguen a su orden de compra; los 44 ajustes de inventario se reparten por `StockItemTransactionID` par o impar |
| `Purchasing.PurchaseOrders`, `PurchaseOrderLines`, `SupplierTransactions` | Por `PurchaseOrderID` par (San José) o impar (Limón). Las 2 074 órdenes tienen el mismo contacto, así que no hay un criterio de negocio mejor. Los 366 pagos a proveedores sin orden se reparten por `SupplierTransactionID` par o impar |
| `Warehouse.StockItemHoldings` | Cada sucursal tiene una fila por producto. La existencia actual se reparte a la mitad (San José se queda con el sobrante si es impar) |

El corporativo no guarda ninguna de estas tablas: las estadísticas consolidadas se calculan desde las sucursales (sección 4).

**Por qué las compras van por sucursal y no centralizadas:** el enunciado dice que cada sucursal maneja su propio inventario, y cada compra es una entrada de inventario (*Stock Receipt*) en una sucursal concreta. Además, las estadísticas deben poder filtrarse por sucursal, y tres de ellas se calculan con compras (reportes 1, 5 y 8). Si las compras estuvieran en el corporativo, esos reportes no tendrían sucursal.

**La fragmentación es correcta:** se comprobó con los datos reales.

| Propiedad | Cómo se comprobó |
|-----------|------------------|
| Completitud | San José + Limón suman exactamente lo original en las 10 tablas: 35 134 + 35 376 = 70 510 facturas, 113 631 + 114 634 = 228 265 líneas, 1 037 + 1 037 = 2 074 órdenes de compra, y lo mismo en pedidos, pagos, movimientos y existencias |
| Disyunción | Ninguna factura ni orden de compra está en las dos sucursales (consulta cruzada por linked server) |
| Reconstrucción | La unión de las facturas de ambas sucursales devuelve la tabla original; no quedan líneas, pedidos ni movimientos sin su factura |

**IDs nuevos sin choques:** las secuencias de cada sucursal se reinician en un rango propio, así un ID nunca se repite entre nodos y además indica dónde se creó.

| Nodo | Rango de los IDs nuevos (facturas, pedidos, compras, movimientos, productos...) |
|------|------------------------------------------------------------------------------|
| Corporativo | Sigue desde el último ID original (todos son menores que 1 000 000) |
| San José | Desde 1 000 000 |
| Limón | Desde 2 000 000 |

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
| Corporativo (sensible) | `PersonID`, `PhoneNumber`, `FaxNumber`, `EmailAddress`, `LogonName`, `HashedPassword`, `IsPermittedToLogon`, `IsExternalLogonProvider`, `IsSystemUser`, `Photo`, `UserPreferences`, `CustomFields`, `OtherLanguages` (calculada a partir de `CustomFields`) |

**Por qué la ciudad se queda en las sucursales:** la ciudad (`DeliveryCityID`) es un dato general, no de contacto, y la necesitan las ventas y el reporte 10 (método de envío según el lugar). La dirección exacta, el código postal y la ubicación en el mapa sí son sensibles y van al corporativo.

**Cómo quedó implementada** (`Script/distribuido/03_fragmentacion_vertical.sql`):

| Nodo | Tablas |
|------|--------|
| Corporativo | Fragmento público en `Sales.Customers`, `Purchasing.Suppliers` y `Application.People`; fragmento sensible en `Sales.CustomersSensible`, `Purchasing.SuppliersSensible` y `Application.PeopleSensible` (misma llave primaria, con FK a la tabla pública). Las vistas `Sales.vClientesCompletos`, `Purchasing.vProveedoresCompletos` y `Application.vPersonasCompletas` reconstruyen la tabla original con un `JOIN` por la llave |
| Sucursales | Solo el fragmento público. Las columnas sensibles también se quitaron del historial (`*_Archive`), para que no quede ninguna copia en la sucursal |

- Las tres tablas siguen siendo temporales: el historial se desactiva para quitar las columnas y se vuelve a activar.
- Los procedimientos leen el fragmento sensible con los sinónimos `Syn_CustomersSensible`, `Syn_SuppliersSensible` y `Syn_PeopleSensible`. En el corporativo apuntan a sus objetos locales y en las sucursales al corporativo por `LS_CORPORATIVO`, así el mismo procedimiento funciona en los tres nodos. Los de clientes y proveedores apuntan a las vistas `vCustomersSensible` y `vSuppliersSensible`, que entregan la ubicación como `Latitud` y `Longitud`, porque el tipo `geography` no se puede leer por linked server.
- Crear, editar y borrar clientes y proveedores escribe en los dos fragmentos dentro de la misma transacción. Solo funciona en el corporativo. Antes de borrar, el procedimiento revisa por linked server que el cliente o proveedor no tenga facturas, pedidos ni compras en ninguna sucursal; si una sucursal no responde, no borra.
- Se eliminaron objetos de ejemplo de WWI que usaban columnas sensibles y que la aplicación no usa: las vistas `Website.Customers` y `Website.Suppliers`, 6 procedimientos de `Website`, y la política de seguridad por filas `FilterCustomersBySalesTerritoryRole` con su función.

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

Implementada en `Script/distribuido/07_preparar_replicacion.sql` y `08_replicacion.sql`. El corporativo es el publicador y el **distribuidor**; las suscripciones son *push*, así que todos los agentes corren en el corporativo.

| Publicación | Tipo | Tablas | Cómo se suscribe | Frecuencia | Por qué |
|-------------|------|--------|------------------|------------|---------|
| `PubCatalogo` | **Merge** | `Warehouse.StockItems`, `StockGroups`, `StockItemStockGroups`, `Colors`, `PackageTypes` | Sin snapshot (`@sync_type = 'none'`) | Cada minuto | Se modifica desde cualquier nodo; merge sincroniza en ambos sentidos y resuelve los conflictos |
| `PubDatos` | **Transaccional** | `Sales.Customers`, `Purchasing.Suppliers`, `Application.People` (fragmento público) | Sin snapshot (`replication support only`) | Continua | Solo cambian en el corporativo; la transaccional los envía en segundos |
| `PubUsuarios` | **Transaccional** | `Seguridad.Usuarios` | Con snapshot | Continua | En las sucursales la tabla empieza vacía y nada la referencia |
| `PubVentasSJ`, `PubVentasLI` | **Transaccional** (publica cada sucursal) | Facturas, líneas de factura, órdenes y líneas de compra, movimientos y existencias, solo con las columnas que usan las estadísticas | Con snapshot, hacia `Resumen.<Tabla>_SJ` / `_LI` del corporativo | Continua | El corporativo necesita las ventas de las sucursales para las estadísticas por sucursal y consolidadas (sección 4.1) |

Las listas de referencia (ciudades, métodos de entrega, categorías...) no se publican: quedan iguales en los tres nodos desde la restauración y la aplicación no las modifica.

**Por qué sin snapshot:** el snapshot borra y vuelve a crear las tablas en el suscriptor, y en las sucursales `StockItems`, `Customers` y `People` no se pueden borrar porque las facturas, pedidos y existencias las referencian. Como las tres bases salen del mismo `.bak`, esos datos ya son idénticos (se comprobó con checksums). Antes de suscribir, el script:

1. Desactiva el historial (tablas temporales) de las 7 tablas publicadas, porque la replicación no las acepta (error 13570). `ValidFrom` y `ValidTo` quedan como columnas normales con valor por defecto; las tablas `*_Archive` se conservan como historial anterior.
2. Agrega a las 5 tablas del catálogo la columna `rowguid` que usa merge: el corporativo la genera y cada sucursal copia los mismos valores por `LS_CORPORATIVO`.
3. Copia a las sucursales las filas que solo existen en el corporativo (la persona `PagWeb`).
4. Ejecuta la primera sincronización merge, que crea en cada sucursal los triggers que registran sus cambios. `levantar.ps1` espera a que termine.

**Login de los agentes:** `wwi_replicacion`, dueño de las bases WWI y de `distribution`, con permiso de solo lectura `VIEW SERVER STATE` (lo pide el agente de snapshot). No es administrador del servidor.

**Concurrencia:** si dos sucursales modifican el mismo producto antes de sincronizar, **gana el cambio más reciente**. Se usa el resolvedor de merge *DATETIME (Later Wins)* sobre la columna `LastEditedWhen`, que `SP_UpdateStockItem` actualiza en cada cambio. El cambio que pierde queda registrado en `MSmerge_conflicts_info` del corporativo. Se eligió así porque ninguna sucursal tiene más autoridad que otra sobre el catálogo, y "gana el último" es la regla más fácil de explicar y de mostrar en la revisión.

**Borrar un producto replicado:** `SP_DeleteStockItem` revisa antes, por linked server, que el producto no tenga ventas, pedidos, compras, movimientos ni existencias en la otra sucursal; si la tiene o la sucursal no responde, no lo borra. Sin esta revisión, el borrado llegaría a la otra sucursal, fallaría por sus FK y los nodos quedarían distintos. Las existencias son locales: en las sucursales su FK hacia `StockItems` es `ON DELETE CASCADE`, para que una fila en 0 no bloquee el borrado replicado.

**Comprobado en los contenedores:**

| Prueba | Resultado |
|--------|-----------|
| Producto creado y editado en San José | Llega al corporativo en el mismo ciclo y a Limón en el siguiente (≤ 2 min) |
| San José y Limón editan el mismo producto (Limón 5 s después) | Los tres nodos quedan con el cambio de Limón; el conflicto queda registrado |
| Cliente editado en el corporativo | Llega a las dos sucursales en menos de 15 s |
| `admin.sj` inicia sesión en San José | Funciona con la copia replicada y la contraseña cifrada |
| Borrar en San José un producto con ventas, o en Limón uno que San José tiene en bodega | Rechazado con mensaje claro |
| Limón apagado mientras San José y el corporativo hacen cambios | Al encenderlo recibe todos los cambios |
| Corporativo apagado | San José sigue vendiendo, editando productos, listando clientes e iniciando sesión; al volver, los cambios llegan al corporativo y a Limón. El detalle de cliente falla (sus datos de contacto están en el corporativo) |

**Limitación:** el corporativo es el centro de la replicación. Mientras está caído, San José y Limón no intercambian cambios del catálogo (los guardan y se envían cuando vuelve). Si estuviera caído más de 14 días (retención de la publicación merge), habría que reinicializar las suscripciones.

Dentro de un mismo nodo, los procedimientos de productos usan transacciones; el control optimista con `rowversion` (rechazar un cambio si otro usuario modificó el producto mientras tanto) queda para el bloque de concurrencia y fallas.

#### 4.1 Ventas de las sucursales en el corporativo (`09_replicaciones_ventas.sql`, `10_vistas_resumen.sql`)

El corporativo no guarda transacciones propias, pero sus estadísticas deben poder verse por sucursal o consolidadas. Para no consultar a las sucursales en cada estadística (lento, y falla si una sucursal no responde), cada sucursal **replica** al corporativo sus datos de ventas, compras, movimientos y existencias:

| Sucursal | Publicación | Tablas en el corporativo |
|----------|-------------|--------------------------|
| San José | `PubVentasSJ` | `Resumen.Facturas_SJ`, `LineasFactura_SJ`, `Compras_SJ`, `LineasCompra_SJ`, `Movimientos_SJ`, `Existencias_SJ` |
| Limón | `PubVentasLI` | Las mismas con sufijo `_LI` |

- Las sucursales usan al corporativo como **distribuidor remoto**; los agentes corren en el corporativo con el login `wwi_replicacion`.
- Solo viajan las columnas que usan las estadísticas (partición vertical); por ejemplo, `Facturas_SJ` tiene `InvoiceID`, `CustomerID`, `SalespersonPersonID`, `DeliveryMethodID` e `InvoiceDate`.
- La suscripción usa **snapshot**: crea las tablas `Resumen.*` y copia los datos existentes en el orden correcto, así ninguna venta hecha durante la copia se pierde. En el corporativo nada referencia esas tablas, así que se pueden crear y borrar sin problema.
- WWI trae un índice *columnstore* agrupado en `StockItemTransactions`, y la replicación no acepta esas tablas (error 35353). En las sucursales se reemplaza por la llave primaria agrupada.
- Las vistas `Resumen.vFacturas`, `vLineasFactura`, `vCompras`, `vLineasCompra`, `vMovimientos` y `vExistencias` unen las tablas de las dos sucursales con una columna `Sucursal` (`SJ` o `LI`): una estadística filtra con `WHERE Sucursal = @Sucursal` o toma todo para el consolidado.

**Comprobado:** el corporativo tiene exactamente las mismas filas que cada sucursal en las 12 tablas (por ejemplo, 35 134 facturas de San José y 35 376 de Limón; la vista consolida 70 510). Una venta nueva en San José llega al corporativo en menos de 15 s, con su línea y el cambio de existencias; al borrarla, también se borra allá.

**Pendiente:** que los procedimientos de estadísticas lean de estas vistas y reciban el parámetro `@Sucursal` (San José, Limón o consolidado). Las vistas indexadas no admiten `UNION ALL`, así que la parte "materializada" son las tablas `Resumen.*`: copias físicas en el corporativo que la replicación mantiene al día.

### 5. Nombres

| Elemento | Nombre |
|----------|--------|
| Bases | `WWI_Corporativo`, `WWI_SanJose`, `WWI_Limon` |
| Servidores (contenedores) | `corporativo`, `sanjose`, `limon` |
| Linked servers (cada nodo ve a los otros dos) | `LS_CORPORATIVO`, `LS_SANJOSE`, `LS_LIMON` |
| Publicaciones | `PubCatalogo` (merge), `PubDatos` y `PubUsuarios` (transaccionales, del corporativo); `PubVentasSJ` y `PubVentasLI` (transaccionales, de cada sucursal) |
| Esquema de las ventas de las sucursales en el corporativo | `Resumen` (tablas `<Tabla>_SJ` / `_LI`, vistas `v<Tabla>`) |
| Logins técnicos | `wwi_enlace` (linked servers), `wwi_replicacion` (agentes de replicación) |
| Columna de sucursal en los resúmenes | `Sucursal` con los valores `SJ` y `LI` |
| Tabla de usuarios (corporativo) | `Seguridad.Usuarios` |
| Llave y certificado de las contraseñas | `LlaveUsuarios` (AES 256), `CertUsuarios` |
| Usuarios de base de datos para la API | `app_admin_sj`, `app_admin_li`, `app_corporativo` |

### 6. Riesgos a revisar en los bloques siguientes

- `StockItems`, `Customers`, `Suppliers` y `People` eran **tablas temporales** y la replicación no las acepta. Resuelto en `07_preparar_replicacion.sql`: se desactiva el historial de las tablas publicadas (sección 4).
- Si el corporativo no responde, el detalle de cliente y de proveedor en las sucursales falla, porque sus datos de contacto viven allá. Se resuelve en el bloque de fallas.
- La tabla de usuarios se replica con la contraseña ya encriptada, así que la llave simétrica debe crearse igual en los tres nodos (mismo `KEY_SOURCE` e `IDENTITY_VALUE`). Resuelto en `06_seguridad.sql` (sección 7.1).

### 7. Roles

El enunciado define dos roles. Cada usuario tiene un rol y, si es administrador, una sucursal.

| Rol | Nodo al que se conecta | Clientes y proveedores | Productos | Ventas | Estadísticas |
|-----|------------------------|------------------------|-----------|--------|--------------|
| **Administrador** | Su sucursal | Consultar | Consultar, crear, modificar y eliminar | Consultar y crear (las de su sucursal) | — |
| **Corporativo** | Corporativo | Consultar, crear, modificar y eliminar | Consultar | — | Consultar (por sucursal o consolidado) |

- La gestión de clientes y proveedores del Proyecto 1 se mantiene, pero en el corporativo: ahí están sus datos sensibles y es el maestro que los replica a las sucursales.
- Crear ventas se mantiene para el administrador, porque cada sucursal maneja su propia facturación.
- Cada rol usa un usuario de base de datos distinto (`app_admin_sj`, `app_admin_li`, `app_corporativo`) que solo tiene permiso de `EXECUTE` sobre los procedimientos de su rol. Así, aunque la web tuviera un error, la base no deja hacer lo que el rol no permite.

#### 7.1 Usuarios y contraseñas cifradas

`Script/distribuido/06_seguridad.sql` crea en los tres nodos:

| Objeto | Qué es |
|--------|--------|
| `Seguridad.Usuarios` | `IdUser`, `Username`, `Password` (cifrada, `varbinary`), `FullName`, `Active`, `Rol`, `Email`, `HireDate` y `Sucursal`. La base no acepta un administrador sin sucursal ni un corporativo con sucursal |
| `LlaveUsuarios` | Llave simétrica AES 256 protegida por el certificado `CertUsuarios`, que a su vez protege la master key de la base. El certificado y la master key son distintos en cada nodo, pero la llave se genera con el mismo `KEY_SOURCE` e `IDENTITY_VALUE` (variables `LLAVE_ORIGEN` y `LLAVE_IDENTIDAD` de `Docker/.env`), así que es la misma en los tres y cualquier nodo descifra una contraseña cifrada en el corporativo |
| `Seguridad.SP_CrearUsuario` | Cifra la contraseña con `EncryptByKey` y guarda el usuario. Solo funciona en el corporativo, que es el maestro |
| `Seguridad.SP_IniciarSesion` | Descifra con `DecryptByKey` y compara dentro de SQL Server. Devuelve solo `IdUser`, `Username`, `FullName`, `Rol` y `Sucursal`, nunca la contraseña |

Detalles de seguridad:

- La contraseña se cifra con el nombre de usuario como *autenticador*: si alguien copia la contraseña cifrada de un usuario a otro, ya no se puede descifrar.
- Un usuario que no existe y una contraseña incorrecta dan el mismo mensaje (`50044`), para no revelar qué usuarios existen. La comparación distingue mayúsculas de minúsculas.
- Los dos procedimientos corren `WITH EXECUTE AS OWNER`: el usuario de la API solo necesita permiso de `EXECUTE` sobre ellos, sin poder leer la tabla ni usar la llave directamente.

Usuarios de ejemplo (se crean solo en el corporativo; las sucursales los reciben por replicación). Su contraseña es la de `USUARIOS_PASSWORD` en `Docker/.env`:

| Usuario | Rol | Sucursal |
|---------|-----|----------|
| `admin.sj` | Administrador | SJ |
| `admin.li` | Administrador | LI |
| `corporativo` | Corporativo | — |

Errores de estos procedimientos:

| Código | Mensaje |
|-------:|---------|
| 50040 | La contraseña debe tener al menos 8 caracteres |
| 50041 | El rol debe ser Administrador o Corporativo |
| 50042 | Un administrador debe tener sucursal (SJ o LI) y un usuario corporativo no lleva sucursal |
| 50043 | Ya existe un usuario con ese nombre |
| 50044 | Usuario o contraseña incorrectos |
| 50045 | El usuario está inactivo |
| 50090 | Los usuarios solo se crean en el corporativo |

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
│   ├── estadisticas/                # Los 10 reportes (01_ … 10_)
│   └── distribuido/                 # Proyecto 2: login de enlace, linked servers, distribuidor,
│                                    # fragmentación vertical y horizontal, secuencias, usuarios
│                                    # con contraseña cifrada y verificación
├── Docker/                          # Proyecto 2: docker-compose.yml, levantar.ps1 y verificar.ps1
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
2. Crear `Docker/.env` a partir de `Docker/.env.example` con:
   - la clave de `sa` (`SA_PASSWORD`) y la del login de enlace (`ENLACE_PASSWORD`). Ambas deben tener mayúsculas, minúsculas y números, y al menos 8 caracteres;
   - las dos frases que generan la llave de las contraseñas (`LLAVE_ORIGEN` y `LLAVE_IDENTIDAD`). No se deben cambiar después de levantar los nodos: las contraseñas ya cifradas solo se descifran con la llave original;
   - la contraseña de los usuarios de ejemplo (`USUARIOS_PASSWORD`), de al menos 8 caracteres.
3. Con Docker Desktop abierto, desde la carpeta `Docker`:

```powershell
.\levantar.ps1
```

El script hace, en orden:

| Paso | Script | Qué hace |
|------|--------|----------|
| 1 | `docker-compose.yml` | Levanta los tres contenedores con SQL Server Agent activo y la zona horaria de Costa Rica |
| 2 | — | Restaura la base en cada nodo (`WWI_Corporativo`, `WWI_SanJose`, `WWI_Limon`) |
| 3 | `Script/distribuido/00_login_enlace.sql` | Crea el login `wwi_enlace` en cada nodo, sin permisos de administrador: solo lee, escribe y ejecuta procedimientos en su base. Desactiva la política de seguridad por filas de ejemplo de WWI, que ocultaba los clientes a todo usuario que no fuera dueño de la base |
| 4 | `Script/distribuido/01_linked_servers.sql` | Crea los linked servers: cada nodo ve a los otros dos (`LS_CORPORATIVO`, `LS_SANJOSE`, `LS_LIMON`), así las sucursales también se consultan entre sí sin depender del corporativo. Se conectan como `wwi_enlace`. Tienen tiempo de espera de 5 s para conectar y 30 s por consulta, para que un nodo caído responda con error en vez de bloquear |
| 5 | `Script/distribuido/02_distribuidor.sql` | Configura el corporativo como distribuidor de la replicación, con la master key en `distribution` que Microsoft pide antes de replicar |
| 6 | `Script/distribuido/03_fragmentacion_vertical.sql` | Separa los datos sensibles de clientes, proveedores y personas (sección 2.2) y crea los sinónimos `Syn_*Sensible` |
| 7 | `Script/distribuido/04_fragmentacion_horizontal.sql` | Reparte ventas, compras, movimientos y existencias entre San José y Limón, y los quita del corporativo (sección 2.1) |
| 8 | `Script/distribuido/05_secuencias.sql` | Reinicia las secuencias de cada sucursal en su rango de IDs |
| 9 | `Script/distribuido/06_seguridad.sql` | Crea la tabla de usuarios, la llave de las contraseñas y los procedimientos de login en los tres nodos, y los usuarios de ejemplo en el corporativo (sección 7.1) |
| 10 | `Script/distribuido/07_preparar_replicacion.sql` | Crea el login `wwi_replicacion`, desactiva el historial de las tablas a replicar, agrega `LastEditedWhen` y las columnas `rowguid` de merge (sección 4) |
| 11 | `Script/sql`, `Script/CRUD`, `Script/estadisticas` | Instala los sinónimos y procedimientos del Proyecto 1 en los tres nodos |
| 12 | `Script/distribuido/08_replicacion.sql` | En las sucursales alinea los datos con el corporativo; en el corporativo crea las publicaciones `PubCatalogo`, `PubDatos` y `PubUsuarios` y sus suscripciones, y espera la primera sincronización |
| 13 | `Script/distribuido/09_replicaciones_ventas.sql` | En el corporativo registra a las sucursales como publicadoras; en cada sucursal crea `PubVentasSJ` / `PubVentasLI` y la suscripción del corporativo, y espera a que lleguen las ventas (sección 4.1) |
| 14 | `Script/distribuido/10_vistas_resumen.sql` | Crea en el corporativo las vistas `Resumen.v*` que unen las dos sucursales |
| 15 | `verificar.ps1` | Muestra el estado de cada nodo, incluidos los usuarios, la llave, la replicación y las tablas `Resumen` |

Los pasos 6, 7 y 10 quedan registrados en la tabla `dbo.ControlFragmentacion` de cada base, y el 12 y el 13 revisan qué publicaciones y suscripciones ya existen: si se vuelven a correr, no repiten nada.

Se puede correr de nuevo sin perder datos. Los límites de memoria suman 7 GB (corporativo 3 GB, porque además es el distribuidor y ahí corren todos los agentes; cada sucursal 2 GB); en uso real los tres nodos rondan 4.5 GB.

#### Comandos útiles

| Para | Comando (desde `Docker`) |
|------|--------------------------|
| Ver el estado del sistema distribuido (sistema operativo, motor, Agent, bases y si los linked servers responden) | `.\verificar.ps1` |
| Simular la caída de una sucursal | `docker stop limon` y luego `.\verificar.ps1`: el corporativo muestra `LS_LIMON : NO RESPONDE` en unos 8 a 12 s |
| Volver a encenderla | `docker start limon`: en uno o dos minutos recibe los cambios que se hicieron mientras estaba caída |
| Apagar los tres nodos sin perder datos | `docker compose stop` |
| Empezar desde cero (borra las bases) | `docker rm -f corporativo sanjose limon`, luego `docker volume rm pry2-bases-2_corporativo-data pry2-bases-2_sanjose-data pry2-bases-2_limon-data` y luego `.\levantar.ps1` |

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
| 9 | `sp_rotacion_inventario` | Rotación de inventario y promedio de días de rotación por producto y año | Inventario promedio | Año, categoría, subcategoría y proveedor |
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
| 9 | `/estadisticas/rotacion` | `sp_rotacion_inventario` | `?anio=` `&categoria=` `&proveedor=` `&categoriaId=` `&subcategoriaId=` |
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
