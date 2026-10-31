use WideWorldImporters;
GO
CREATE OR ALTER PROCEDURE SP_DeleteSupplier
    @SupplierID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Syn_Suppliers
        WHERE SupplierID = @SupplierID;

        IF @@ROWCOUNT = 0
            THROW 50001, 'El proveedor indicado no existe.', 1;

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