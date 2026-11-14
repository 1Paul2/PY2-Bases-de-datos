SET NOCOUNT ON;
SET XACT_ABORT ON;
USE [$(BASE)];
GO

IF EXISTS (SELECT 1 FROM dbo.ControlFragmentacion WHERE Paso = N'horizontal')
BEGIN
    PRINT 'Fragmentacion horizontal ya aplicada';
    SET NOEXEC ON;
END
GO

IF OBJECT_ID(N'dbo.VendedorSucursal') IS NULL
    CREATE TABLE dbo.VendedorSucursal (
        PersonID int NOT NULL CONSTRAINT PK_VendedorSucursal PRIMARY KEY,
        Sucursal char(2) NOT NULL CONSTRAINT CK_VendedorSucursal CHECK (Sucursal IN ('SJ', 'LI')),
        Facturas int NOT NULL
    );
GO

DECLARE @nodo sysname = N'$(NODO)';
DECLARE @par int = CASE @nodo WHEN N'sanjose' THEN 0 WHEN N'limon' THEN 1 END;
DECLARE @sucursal char(2) = CASE @nodo WHEN N'sanjose' THEN 'SJ' WHEN N'limon' THEN 'LI' END;
DELETE FROM dbo.VendedorSucursal;

DECLARE @persona int, @cantidad int, @totalSJ int = 0, @totalLI int = 0;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT PersonID, SUM(Facturas)
    FROM (
        SELECT SalespersonPersonID AS PersonID, COUNT(*) AS Facturas FROM Sales.Invoices GROUP BY SalespersonPersonID
        UNION ALL
        SELECT DISTINCT SalespersonPersonID, 0 FROM Sales.Orders
    ) v
    WHERE PersonID IS NOT NULL
    GROUP BY PersonID
    ORDER BY SUM(Facturas) DESC, PersonID;
OPEN c;
FETCH NEXT FROM c INTO @persona, @cantidad;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF @totalSJ <= @totalLI
    BEGIN
        INSERT INTO dbo.VendedorSucursal VALUES (@persona, 'SJ', @cantidad);
        SET @totalSJ += @cantidad;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.VendedorSucursal VALUES (@persona, 'LI', @cantidad);
        SET @totalLI += @cantidad;
    END
    FETCH NEXT FROM c INTO @persona, @cantidad;
END
CLOSE c;
DEALLOCATE c;

IF EXISTS (SELECT 1 FROM Sales.Invoices I
           WHERE NOT EXISTS (SELECT 1 FROM dbo.VendedorSucursal V WHERE V.PersonID = I.SalespersonPersonID))
   OR EXISTS (SELECT 1 FROM Sales.Orders O
              WHERE NOT EXISTS (SELECT 1 FROM dbo.VendedorSucursal V WHERE V.PersonID = O.SalespersonPersonID))
    THROW 50110, 'Hay facturas o pedidos sin vendedor asignado a una sucursal; no se fragmenta.', 1;

IF EXISTS (SELECT 1 FROM Sales.Invoices I
           JOIN Sales.Orders O ON O.OrderID = I.OrderID
           JOIN dbo.VendedorSucursal VI ON VI.PersonID = I.SalespersonPersonID
           JOIN dbo.VendedorSucursal VO ON VO.PersonID = O.SalespersonPersonID
           WHERE VI.Sucursal <> VO.Sucursal)
    THROW 50111, 'Hay facturas cuyo pedido quedaría en otra sucursal; no se fragmenta.', 1;

PRINT CONCAT('Vendedores repartidos: San Jose ', @totalSJ, ' facturas, Limon ', @totalLI, ' facturas');

SELECT InvoiceID INTO #facturas FROM Sales.Invoices I
WHERE @sucursal IS NULL
   OR NOT EXISTS (SELECT 1 FROM dbo.VendedorSucursal V WHERE V.PersonID = I.SalespersonPersonID AND V.Sucursal = @sucursal);

SELECT OrderID INTO #pedidos FROM Sales.Orders O
WHERE @sucursal IS NULL
   OR NOT EXISTS (SELECT 1 FROM dbo.VendedorSucursal V WHERE V.PersonID = O.SalespersonPersonID AND V.Sucursal = @sucursal);

SELECT PurchaseOrderID INTO #compras FROM Purchasing.PurchaseOrders
WHERE @par IS NULL OR PurchaseOrderID % 2 <> @par;

BEGIN TRANSACTION;

DELETE FROM Warehouse.StockItemTransactions
WHERE InvoiceID IN (SELECT InvoiceID FROM #facturas)
   OR PurchaseOrderID IN (SELECT PurchaseOrderID FROM #compras)
   OR (InvoiceID IS NULL AND PurchaseOrderID IS NULL AND (@par IS NULL OR StockItemTransactionID % 2 <> @par));
PRINT CONCAT('StockItemTransactions borradas: ', @@ROWCOUNT);

DELETE FROM Sales.CustomerTransactions
WHERE InvoiceID IN (SELECT InvoiceID FROM #facturas)
   OR (InvoiceID IS NULL AND (@par IS NULL OR CustomerTransactionID % 2 <> @par));
PRINT CONCAT('CustomerTransactions borradas: ', @@ROWCOUNT);

DELETE FROM Sales.InvoiceLines WHERE InvoiceID IN (SELECT InvoiceID FROM #facturas);
DELETE FROM Sales.Invoices WHERE InvoiceID IN (SELECT InvoiceID FROM #facturas);
PRINT CONCAT('Invoices borradas: ', @@ROWCOUNT);

DELETE FROM Sales.OrderLines WHERE OrderID IN (SELECT OrderID FROM #pedidos);
DELETE FROM Sales.Orders WHERE OrderID IN (SELECT OrderID FROM #pedidos);
PRINT CONCAT('Orders borrados: ', @@ROWCOUNT);

DELETE FROM Purchasing.SupplierTransactions
WHERE PurchaseOrderID IN (SELECT PurchaseOrderID FROM #compras)
   OR (PurchaseOrderID IS NULL AND (@par IS NULL OR SupplierTransactionID % 2 <> @par));
DELETE FROM Purchasing.PurchaseOrderLines WHERE PurchaseOrderID IN (SELECT PurchaseOrderID FROM #compras);
DELETE FROM Purchasing.PurchaseOrders WHERE PurchaseOrderID IN (SELECT PurchaseOrderID FROM #compras);
PRINT CONCAT('PurchaseOrders borradas: ', @@ROWCOUNT);

IF @par IS NULL
    DELETE FROM Warehouse.StockItemHoldings;
ELSE
    UPDATE Warehouse.StockItemHoldings
    SET QuantityOnHand = CASE WHEN @par = 0 THEN CEILING(QuantityOnHand / 2.0) ELSE FLOOR(QuantityOnHand / 2.0) END;

INSERT INTO dbo.ControlFragmentacion (Paso) VALUES (N'horizontal');
COMMIT TRANSACTION;
PRINT 'Fragmentacion horizontal aplicada';
GO

SET NOEXEC OFF;
GO
