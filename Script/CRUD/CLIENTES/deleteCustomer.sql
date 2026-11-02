CREATE OR ALTER PROCEDURE SP_DeleteCustomer
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF OBJECT_ID(N'Sales.CustomersSensible') IS NULL
        THROW 50090, 'Los clientes solo se crean, editan o eliminan en el corporativo.', 1;

    IF NOT EXISTS (SELECT 1 FROM Syn_Customers WHERE CustomerID = @CustomerID)
        THROW 50001, 'El cliente indicado no existe.', 1;

    DECLARE @Usos INT;
    EXEC sp_executesql N'
        SELECT @Usos =
              (SELECT COUNT(*) FROM LS_SANJOSE.WWI_SanJose.Sales.Invoices WHERE CustomerID = @Id OR BillToCustomerID = @Id)
            + (SELECT COUNT(*) FROM LS_SANJOSE.WWI_SanJose.Sales.Orders WHERE CustomerID = @Id)
            + (SELECT COUNT(*) FROM LS_SANJOSE.WWI_SanJose.Sales.CustomerTransactions WHERE CustomerID = @Id)
            + (SELECT COUNT(*) FROM LS_LIMON.WWI_Limon.Sales.Invoices WHERE CustomerID = @Id OR BillToCustomerID = @Id)
            + (SELECT COUNT(*) FROM LS_LIMON.WWI_Limon.Sales.Orders WHERE CustomerID = @Id)
            + (SELECT COUNT(*) FROM LS_LIMON.WWI_Limon.Sales.CustomerTransactions WHERE CustomerID = @Id);',
        N'@Id INT, @Usos INT OUTPUT', @CustomerID, @Usos OUTPUT;

    IF @Usos > 0
        THROW 50002, 'No se puede eliminar el cliente porque tiene facturas, pedidos u otros registros relacionados.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Syn_CustomersSensibleDatos WHERE CustomerID = @CustomerID;
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
