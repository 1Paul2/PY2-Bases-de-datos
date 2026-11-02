CREATE OR ALTER PROCEDURE SP_DeleteStockItem
    @StockItemID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Syn_StockItems WHERE StockItemID = @StockItemID)
            THROW 50001, 'El producto indicado no existe.', 1;

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