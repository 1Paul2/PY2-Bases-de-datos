USE WideWorldImporters;
GO

CREATE OR ALTER PROCEDURE SP_DeleteCustomer
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Syn_Customers WHERE CustomerID = @CustomerID)
            THROW 50001, 'El cliente indicado no existe.', 1;

        -- Si el cliente tiene facturas, pedidos o transacciones, esto viola una FK (547) y se revierte todo
        DELETE FROM Syn_Customers WHERE CustomerID = @CustomerID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 547
            THROW 50002, 'No se puede eliminar el cliente porque tiene facturas, pedidos u otros registros relacionados.', 1;

        THROW;
    END CATCH;
END;
GO
