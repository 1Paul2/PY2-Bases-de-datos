SET NOCOUNT ON;
USE [$(BASE)];
GO

-- Solo en el corporativo. Une las tablas que llegan de cada sucursal (Resumen.<Tabla>_SJ y _LI)
-- con una columna Sucursal: las estadísticas filtran por 'SJ', 'LI' o toman todo para el consolidado.
-- Las vistas van en SQL dinámico: CREATE VIEW se compila aunque la condición no se cumpla, y fallaría
-- en una sucursal o si el snapshot todavía no creó las tablas.
IF N'$(NODO)' <> N'corporativo'
    PRINT 'Las vistas Resumen solo van en el corporativo';
ELSE IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'Resumen')) < 12
    PRINT 'Faltan tablas Resumen: el snapshot de las sucursales todavia no termina. Vuelva a correr este script despues.';
ELSE
BEGIN
    EXEC (N'CREATE OR ALTER VIEW Resumen.vFacturas AS
        SELECT CAST(''SJ'' AS char(2)) AS Sucursal, InvoiceID, CustomerID, SalespersonPersonID, DeliveryMethodID, InvoiceDate
        FROM Resumen.Facturas_SJ
        UNION ALL
        SELECT CAST(''LI'' AS char(2)), InvoiceID, CustomerID, SalespersonPersonID, DeliveryMethodID, InvoiceDate
        FROM Resumen.Facturas_LI;');

    EXEC (N'CREATE OR ALTER VIEW Resumen.vLineasFactura AS
        SELECT CAST(''SJ'' AS char(2)) AS Sucursal, InvoiceLineID, InvoiceID, StockItemID, Quantity, ExtendedPrice, LineProfit
        FROM Resumen.LineasFactura_SJ
        UNION ALL
        SELECT CAST(''LI'' AS char(2)), InvoiceLineID, InvoiceID, StockItemID, Quantity, ExtendedPrice, LineProfit
        FROM Resumen.LineasFactura_LI;');

    EXEC (N'CREATE OR ALTER VIEW Resumen.vCompras AS
        SELECT CAST(''SJ'' AS char(2)) AS Sucursal, PurchaseOrderID, SupplierID, OrderDate
        FROM Resumen.Compras_SJ
        UNION ALL
        SELECT CAST(''LI'' AS char(2)), PurchaseOrderID, SupplierID, OrderDate
        FROM Resumen.Compras_LI;');

    EXEC (N'CREATE OR ALTER VIEW Resumen.vLineasCompra AS
        SELECT CAST(''SJ'' AS char(2)) AS Sucursal, PurchaseOrderLineID, PurchaseOrderID, StockItemID, OrderedOuters, ExpectedUnitPricePerOuter
        FROM Resumen.LineasCompra_SJ
        UNION ALL
        SELECT CAST(''LI'' AS char(2)), PurchaseOrderLineID, PurchaseOrderID, StockItemID, OrderedOuters, ExpectedUnitPricePerOuter
        FROM Resumen.LineasCompra_LI;');

    EXEC (N'CREATE OR ALTER VIEW Resumen.vMovimientos AS
        SELECT CAST(''SJ'' AS char(2)) AS Sucursal, StockItemTransactionID, StockItemID, TransactionTypeID, CustomerID,
               InvoiceID, SupplierID, PurchaseOrderID, TransactionOccurredWhen, Quantity
        FROM Resumen.Movimientos_SJ
        UNION ALL
        SELECT CAST(''LI'' AS char(2)), StockItemTransactionID, StockItemID, TransactionTypeID, CustomerID,
               InvoiceID, SupplierID, PurchaseOrderID, TransactionOccurredWhen, Quantity
        FROM Resumen.Movimientos_LI;');

    EXEC (N'CREATE OR ALTER VIEW Resumen.vExistencias AS
        SELECT CAST(''SJ'' AS char(2)) AS Sucursal, StockItemID, QuantityOnHand
        FROM Resumen.Existencias_SJ
        UNION ALL
        SELECT CAST(''LI'' AS char(2)), StockItemID, QuantityOnHand
        FROM Resumen.Existencias_LI;');

    PRINT 'Vistas Resumen.v* listas';
END
GO
