use WideWorldImporters;
GO
CREATE OR ALTER PROCEDURE SP_DeleteSale
    @InvoiceID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Syn_Invoices WHERE InvoiceID = @InvoiceID)
            THROW 50001, 'La venta indicada no existe.', 1;

        -- Se devuelve al inventario lo que tenía la factura y se borran sus movimientos
        UPDATE SIH
        SET SIH.QuantityOnHand = SIH.QuantityOnHand + IL.Cantidad,
            SIH.LastEditedWhen = SYSDATETIME()
        FROM Syn_StockItemHoldings SIH
        INNER JOIN (SELECT StockItemID, SUM(Quantity) AS Cantidad
                    FROM Syn_InvoiceLines WHERE InvoiceID = @InvoiceID GROUP BY StockItemID) IL
            ON IL.StockItemID = SIH.StockItemID;

        DELETE FROM Syn_StockItemTransactions WHERE InvoiceID = @InvoiceID;

        DELETE FROM Syn_InvoiceLines WHERE InvoiceID = @InvoiceID;
        DELETE FROM Syn_Invoices WHERE InvoiceID = @InvoiceID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547
            THROW 50002, 'No se puede eliminar la venta porque tiene registros relacionados.', 1;
        THROW;
    END CATCH;
END;
GO