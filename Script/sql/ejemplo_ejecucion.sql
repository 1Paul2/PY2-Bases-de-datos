USE WideWorldImporters;
GO
SET NOCOUNT ON;
GO

-- Ejemplos de cómo usar los procedimientos del proyecto.
-- Para correrlo desde la terminal:
--   sqlcmd -S localhost -U sa -P '<clave>' -d WideWorldImporters -C -I -i ejemplo_ejecucion.sql

-- PARTE 1: Los 10 reportes de estadísticas


-- 1. Lo mínimo, lo máximo y el promedio que se gasta en pedidos a cada proveedor.
EXEC sp_estadistica_proveedor @proveedor = '', @categoria = '';

-- 2. Lo mismo, pero con los clientes (aquí solo los que se llaman "Tailspin").
EXEC sp_estadistica_cliente @NomCliente = 'Tailspin', @categoria = '';

-- 3. Los 5 productos que más ganancia dejaron cada año, de 2014 a 2015.
EXEC sp_top5_productos_ganancia @anio = 2014, @anioFin = 2015;

-- 4. Los 5 clientes con más facturas cada año, de 2014 a 2016.
EXEC sp_top5_clientes_facturas @anioInicio = 2014, @anioFin = 2016;

-- 5. Los 5 proveedores con más órdenes de compra cada año, de 2014 a 2016.
EXEC sp_top5_proveedores_ordenes @anioInicio = 2014, @anioFin = 2016;

-- 6. Tabla con lo vendido por categoría (filas) y por año (columnas).
EXEC sp_matriz_ventas_categoria_anio;

-- 7. Qué compró cada cliente en marzo de 2015.
EXEC sp_seguimiento_compras_cliente @anio = 2015, @mes = 3;

-- 7b. Lo mismo, solo con productos que están en la categoría 1 y en la subcategoría 2 (grupos de producto).
EXEC sp_seguimiento_compras_cliente @anio = 2015, @mes = 3, @categoriaId = 1, @subcategoriaId = 2;

-- 8. A quién le compramos en marzo de 2015 (por proveedor).
EXEC sp_seguimiento_compras_proveedor @anio = 2015, @mes = 3;

-- 8b. Lo mismo, filtrando por categoría y subcategoría de producto.
EXEC sp_seguimiento_compras_proveedor @anio = 2015, @mes = 3, @categoriaId = 1, @subcategoriaId = 2;

-- 9. Qué tan rápido se vende el inventario de cada producto en 2015.
EXEC sp_rotacion_inventario @anio = 2015;

-- 10. El método de envío que más se usa en cada lugar en 2015.
EXEC sp_metodo_envio_favorito @anio = 2015, @soloFavorito = 1;

-- Los reportes y listados se paginan en la base: página 2, de 10 en 10
-- (la columna TotalRegistros trae el total de resultados).
EXEC sp_estadistica_cliente @NomCliente = '', @categoria = '', @Pagina = 2, @PorPagina = 10;
GO

-- ======================================================
-- Catálogos que usan los formularios y filtros de la web
-- ======================================================
EXEC SP_GetCustomerCategories;
EXEC SP_GetBuyingGroups;
EXEC SP_GetDeliveryMethods;
EXEC SP_GetColors;
EXEC SP_GetPackageTypes;
EXEC SP_GetSuppliersCatalog;
EXEC SP_GetStockGroups;
EXEC SP_GetSupplierCategories;
EXEC SP_GetMonths;
EXEC SP_GetYears @Tipo = 'ventas';
EXEC SP_GetYears @Tipo = 'compras';
EXEC SP_GetYears @Tipo = 'inventario';

-- Opciones de los filtros (solo las que tienen datos)
EXEC SP_GetCustomerCategoriesInUse;
EXEC SP_GetSupplierCategoriesInUse;
EXEC SP_GetDeliveryMethodsInUse @Tipo = 'clientes';
EXEC SP_GetDeliveryMethodsInUse @Tipo = 'proveedores';
EXEC SP_GetStockGroupsInUse;

-- Buscadores de los formularios
EXEC SP_SearchCities @Criterio = 'San';
EXEC SP_SearchPeople @Criterio = 'Kay';
EXEC SP_SearchPeople @Criterio = '', @SoloVendedores = 1;
EXEC SP_SearchCustomers @Criterio = 'Tailspin';
EXEC SP_SearchStockItems @Criterio = 'USB';
GO

-- ======================================================
-- PARTE 2: Búsquedas de los módulos (filtros y detalles)
-- ======================================================

-- Clientes cuyo nombre contiene "Tail" (primera página de 10).
EXEC SP_LISTA_CLIENTES @Apodo = 'Tail', @Pagina = 1, @PorPagina = 10;

-- Todos los datos de un cliente.
EXEC SP_CLIENTES @Nombre = 'Tailspin Toys (Head Office)';

-- Proveedores cuyo nombre contiene "Fabrikam".
EXEC SP_GetSuppliers @Name = 'Fabrikam';

-- Todos los datos del proveedor número 4.
EXEC SP_GetSupplierDetails @SupplierID = 4;

-- Productos cuyo nombre contiene "USB", con al menos 100 unidades disponibles.
EXEC SP_GetStockItems @Name = 'USB', @CantidadMinima = 100;

-- Todos los datos del producto número 1.
EXEC SP_GetStockItemDetails @StockItemID = 1;

-- Ventas del cliente "Tailspin" durante 2015, con montos entre 100 y 5000.
-- Se muestran 10 resultados por página.
EXEC SP_GetSales @CustomerName = 'Tailspin',
                 @InvoiceDateFrom = '2015-01-01', @InvoiceDateTo = '2015-12-31',
                 @MinTotalAmount = 100, @MaxTotalAmount = 5000,
                 @Pagina = 1, @PorPagina = 10;

-- La factura número 1: primero sus datos generales y luego sus productos.
EXEC SP_GetSaleHeader  @InvoiceID = 1;
EXEC SP_GetSaleDetails @InvoiceID = 1;
GO

-- ======================================================
-- PARTE 3: Crear, cambiar y borrar datos
-- Cada prueba crea algo, lo cambia y lo borra, para que la
-- base de datos quede igual que antes.
-- Todo se hace dentro de una transacción: si algo sale mal,
-- no se guarda nada.
-- ======================================================

-- ---- Productos ----
DECLARE @IdProducto INT;

-- Si una prueba anterior dejó productos de prueba, se borran primero.
WHILE EXISTS (SELECT 1 FROM Syn_StockItems WHERE StockItemName LIKE N'Producto de prueba Proyecto 1%')
BEGIN
    SELECT TOP 1 @IdProducto = StockItemID
    FROM Syn_StockItems WHERE StockItemName LIKE N'Producto de prueba Proyecto 1%';
    EXEC SP_DeleteStockItem @StockItemID = @IdProducto;
END;

-- Crear un producto nuevo.
EXEC SP_InsertStockItem
    @StockItemName = N'Producto de prueba Proyecto 1',
    @SupplierID = 2, @LeadTimeDays = 7, @ColorID = NULL,
    @UnitPackageID = 7, @OuterPackageID = 7, @QuantityPerOuter = 1,
    @Brand = NULL, @Size = NULL, @TaxRate = 15, @UnitPrice = 10,
    @IsChillerStock = 0, @RecommendedRetailPrice = NULL,
    @TypicalWeightPerUnit = NULL, @BinLocation = N'A-01',
    @QuantityOnHand = 50, @MarketingComments = N'Producto creado por el script de ejemplo',
    @StockGroups = N'1,2';   -- se guardan en StockItemStockGroups

-- Buscar el número que le tocó al producto nuevo.
SELECT @IdProducto = StockItemID FROM Syn_StockItems
WHERE StockItemName = N'Producto de prueba Proyecto 1';

-- Cambiar su nombre, su marca y su precio.
EXEC SP_UpdateStockItem
    @StockItemID = @IdProducto,
    @StockItemName = N'Producto de prueba Proyecto 1 (editado)',
    @SupplierID = 2, @LeadTimeDays = 10, @ColorID = NULL,
    @UnitPackageID = 7, @OuterPackageID = 7, @QuantityPerOuter = 1,
    @Brand = N'Marca', @Size = NULL, @TaxRate = 15, @UnitPrice = 12,
    @IsChillerStock = 0, @RecommendedRetailPrice = NULL,
    @TypicalWeightPerUnit = NULL, @BinLocation = N'A-02',
    @QuantityOnHand = 40, @StockGroups = N'2';

-- Ver cómo quedó.
EXEC SP_GetStockItemDetails @StockItemID = @IdProducto;

-- Borrarlo.
EXEC SP_DeleteStockItem @StockItemID = @IdProducto;
GO

-- ---- Contactos nuevos ----
-- Si se escribe un nombre que no existe, el SP lo crea en Application.People.
-- Se hace dentro de una transacción y se deshace al final para no dejar datos de prueba.
BEGIN TRANSACTION;
    DECLARE @NuevaPersona INT;
    EXEC SP_ObtenerOCrearPersona @Nombre = N'Contacto de prueba Proyecto 1', @PersonID = @NuevaPersona OUTPUT;
    SELECT PersonID, FullName FROM Syn_People WHERE PersonID = @NuevaPersona;
ROLLBACK TRANSACTION;
GO

-- ---- Ventas ----
-- Los productos de la venta se escriben en un solo texto:
--   número de producto | cantidad | precio | impuesto % | descripción
-- y cada producto se separa con punto y coma (;).
-- El monto del impuesto y el total los calcula el procedimiento.
DECLARE @NuevaVenta TABLE (NewInvoiceID INT);
DECLARE @IdVenta INT, @Contacto INT, @Vendedor INT;

-- Datos que necesita la venta: la persona de contacto del cliente 1 y la vendedora 2.
SELECT TOP 1 @Contacto = PrimaryContactPersonID FROM Syn_Customers WHERE CustomerID = 1;
SET @Vendedor = 2;

-- Crear una venta con dos productos.
INSERT @NuevaVenta
EXEC SP_InsertSale
    @CustomerID = 1, @DeliveryMethodID = 3,
    @CustomerPurchaseOrderNumber = N'PRUEBA-001',
    @ContactPersonID = @Contacto, @SalespersonPersonID = @Vendedor,
    @InvoiceDate = '2016-05-31',
    @DeliveryInstructions = N'Venta de prueba',
    @Lines = N'1|10|230|15|Linea de prueba;2|5|100|15|Segunda linea';

-- Guardar el número de factura que se creó y mostrar la factura.
SELECT @IdVenta = NewInvoiceID FROM @NuevaVenta;
SELECT @IdVenta AS VentaInsertada;
EXEC SP_GetSaleHeader  @InvoiceID = @IdVenta;
EXEC SP_GetSaleDetails @InvoiceID = @IdVenta;

-- Cambiar la venta: ahora lleva un solo producto, con otra cantidad.
EXEC SP_UpdateSale
    @InvoiceID = @IdVenta, @CustomerID = 1, @DeliveryMethodID = 3,
    @CustomerPurchaseOrderNumber = N'PRUEBA-001-EDIT',
    @ContactPersonID = @Contacto, @SalespersonPersonID = @Vendedor,
    @InvoiceDate = '2016-05-31', @DeliveryInstructions = N'Venta editada',
    @BillToCustomerID = 1,
    @Lines = N'1|20|230|15|Linea editada';

-- Al crear o editar la venta se descontó el inventario; al borrarla se devuelve.
-- Ver cómo quedó la factura y después borrarla.
EXEC SP_GetSaleHeader @InvoiceID = @IdVenta;
EXEC SP_DeleteSale    @InvoiceID = @IdVenta;
GO

-- ---- Prueba de que se deshace todo cuando algo sale mal ----
-- Se intenta crear una venta con un producto que no existe (el 999999).
-- Tiene que dar error y NO guardar nada, ni siquiera la factura.
BEGIN TRY
    EXEC SP_InsertSale
        @CustomerID = 1, @DeliveryMethodID = 3,
        @CustomerPurchaseOrderNumber = N'ERROR-001',
        @ContactPersonID = 1, @SalespersonPersonID = 2,
        @InvoiceDate = '2016-05-31', @DeliveryInstructions = N'Debe fallar',
        @Lines = N'999999|1|10|15|Producto inexistente';
END TRY
BEGIN CATCH
    -- Aquí se muestra el motivo del error.
    SELECT ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- Comprobar que no quedó ninguna factura: el resultado tiene que ser 0.
SELECT COUNT(*) AS FacturasConOrdenERROR001
FROM Syn_Invoices WHERE CustomerPurchaseOrderNumber = N'ERROR-001';
GO