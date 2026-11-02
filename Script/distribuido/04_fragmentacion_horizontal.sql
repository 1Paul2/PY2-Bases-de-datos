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

DECLARE @nodo sysname = N'$(NODO)';
DECLARE @vendedores TABLE (PersonID int PRIMARY KEY);
DECLARE @par int = CASE @nodo WHEN N'sanjose' THEN 0 WHEN N'limon' THEN 1 END;

IF @nodo = N'sanjose' INSERT INTO @vendedores VALUES (2), (3), (6), (7), (8);
IF @nodo = N'limon'   INSERT INTO @vendedores VALUES (13), (14), (15), (16), (20);

SELECT InvoiceID INTO #facturas FROM Sales.Invoices
WHERE SalespersonPersonID NOT IN (SELECT PersonID FROM @vendedores);

SELECT OrderID INTO #pedidos FROM Sales.Orders
WHERE SalespersonPersonID NOT IN (SELECT PersonID FROM @vendedores);

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
