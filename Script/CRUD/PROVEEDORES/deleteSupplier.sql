CREATE OR ALTER PROCEDURE SP_DeleteSupplier
    @SupplierID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF OBJECT_ID(N'Purchasing.SuppliersSensible') IS NULL
        THROW 50090, 'Los proveedores solo se crean, editan o eliminan en el corporativo.', 1;

    IF NOT EXISTS (SELECT 1 FROM Syn_Suppliers WHERE SupplierID = @SupplierID)
        THROW 50001, 'El proveedor indicado no existe.', 1;

    DECLARE @Usos INT;
    EXEC sp_executesql N'
        SELECT @Usos =
              (SELECT COUNT(*) FROM LS_SANJOSE.WWI_SanJose.Purchasing.PurchaseOrders WHERE SupplierID = @Id)
            + (SELECT COUNT(*) FROM LS_SANJOSE.WWI_SanJose.Purchasing.SupplierTransactions WHERE SupplierID = @Id)
            + (SELECT COUNT(*) FROM LS_LIMON.WWI_Limon.Purchasing.PurchaseOrders WHERE SupplierID = @Id)
            + (SELECT COUNT(*) FROM LS_LIMON.WWI_Limon.Purchasing.SupplierTransactions WHERE SupplierID = @Id);',
        N'@Id INT, @Usos INT OUTPUT', @SupplierID, @Usos OUTPUT;

    IF @Usos > 0
        THROW 50002, 'No se puede eliminar el proveedor porque tiene movimientos de inventario u otros registros relacionados.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Syn_SuppliersSensibleDatos WHERE SupplierID = @SupplierID;
        DELETE FROM Syn_Suppliers WHERE SupplierID = @SupplierID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 547
            THROW 50002, 'No se puede eliminar el proveedor porque tiene movimientos de inventario u otros registros relacionados.', 1;

        THROW;
    END CATCH;
END;
GO