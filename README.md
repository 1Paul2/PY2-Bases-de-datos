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

1. [Arquitectura](#arquitectura)
2. [Tecnologías utilizadas](#tecnologías-utilizadas)
3. [Estructura del repositorio](#estructura-del-repositorio)
4. [Instalación y ejecución](#instalación-y-ejecución)
5. [Objetivos alcanzados](#objetivos-alcanzados)
6. [Objetivos no alcanzados y decisiones](#objetivos-no-alcanzados-y-decisiones)
7. [Referencia de la API](#referencia-de-la-api)

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
