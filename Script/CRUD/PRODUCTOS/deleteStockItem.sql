CREATE OR ALTER PROCEDURE SP_ProductoEnUso
    @StockItemID INT,
    @Usos INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) = N'SELECT @Usos = 0';
    DECLARE @origen NVARCHAR(200);
    DECLARE @origenes TABLE (prefijo NVARCHAR(200));

    INSERT INTO @origenes VALUES (N'');
    IF DB_NAME() <> N'WWI_SanJose' INSERT INTO @origenes VALUES (N'LS_SANJOSE.WWI_SanJose.');
    IF DB_NAME() <> N'WWI_Limon'   INSERT INTO @origenes VALUES (N'LS_LIMON.WWI_Limon.');

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT prefijo FROM @origenes;
    OPEN c;
    FETCH NEXT FROM c INTO @origen;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql += N'
            + (SELECT COUNT(*) FROM ' + @origen + N'Sales.InvoiceLines WHERE StockItemID = @Id)
            + (SELECT COUNT(*) FROM ' + @origen + N'Sales.OrderLines WHERE StockItemID = @Id)
            + (SELECT COUNT(*) FROM ' + @origen + N'Purchasing.PurchaseOrderLines WHERE StockItemID = @Id)
            + (SELECT COUNT(*) FROM ' + @origen + N'Warehouse.StockItemTransactions WHERE StockItemID = @Id)'
            + CASE WHEN @origen <> N'' THEN N'
            + (SELECT COUNT(*) FROM ' + @origen + N'Warehouse.StockItemHoldings WHERE StockItemID = @Id AND QuantityOnHand > 0)' ELSE N'' END;
        FETCH NEXT FROM c INTO @origen;
    END
    CLOSE c;
    DEALLOCATE c;

    EXEC sp_executesql @sql, N'@Id INT, @Usos INT OUTPUT', @StockItemID, @Usos OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE SP_DeleteStockItem
    @StockItemID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM Syn_StockItems WHERE StockItemID = @StockItemID)
        THROW 50001, 'El producto indicado no existe.', 1;

    DECLARE @Usos INT;
    EXEC dbo.SP_ProductoEnUso @StockItemID, @Usos OUTPUT;

    IF @Usos > 0
        THROW 50002, 'No se puede eliminar el producto porque tiene ventas, movimientos o existencias en alguna sucursal.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Syn_StockItemStockGroups WHERE StockItemID = @StockItemID;
        DELETE FROM Syn_StockItemHoldings    WHERE StockItemID = @StockItemID;
        DELETE FROM Syn_StockItems WHERE StockItemID = @StockItemID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 547
            THROW 50002, 'No se puede eliminar el producto porque tiene movimientos de inventario u otros registros relacionados.', 1;
        THROW;
    END CATCH;
END;
GO
