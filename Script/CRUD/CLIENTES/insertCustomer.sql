USE WideWorldImporters;
GO
CREATE OR ALTER PROCEDURE SP_InsertCustomer
    @CustomerName NVARCHAR(100),
    @CustomerCategoryID INT,
    @BuyingGroupID INT = NULL,
    @PrimaryContactPersonID INT = NULL,
    @AlternateContactPersonID INT = NULL,
    @PrimaryContactName NVARCHAR(50) = NULL,     -- nombre de un contacto nuevo
    @AlternateContactName NVARCHAR(50) = NULL,
    @BillToCustomerID INT = NULL,
    @DeliveryMethodID INT,
    @DeliveryCityID INT,
    @PostalCityID INT,
    @DeliveryPostalCode NVARCHAR(10),
    @PostalPostalCode NVARCHAR(20),
    @PhoneNumber NVARCHAR(20),
    @FaxNumber NVARCHAR(20),
    @PaymentDays INT,
    @StandardDiscountPercentage DECIMAL(18, 3) = NULL,   -- valores por defecto los pone la base
    @IsStatementSent BIT = NULL,
    @IsOnCreditHold BIT = NULL,
    @WebsiteURL NVARCHAR(100),
    @DeliveryAddressLine1 NVARCHAR(60),
    @DeliveryAddressLine2 NVARCHAR(60) = NULL,
    @PostalAddressLine1 NVARCHAR(60),
    @PostalAddressLine2 NVARCHAR(60) = NULL,
    @AccountOpenedDate DATE = NULL,
    @DeliveryLatitude DECIMAL(9, 6) = NULL,
    @DeliveryLongitude DECIMAL(9, 6) = NULL,
    @LastEditedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @LastEditedBy = ISNULL(@LastEditedBy, dbo.FN_EditorWeb());

    IF (@DeliveryLatitude IS NULL AND @DeliveryLongitude IS NOT NULL)
       OR (@DeliveryLatitude IS NOT NULL AND @DeliveryLongitude IS NULL)
        THROW 50001, 'Debe indicar ambas coordenadas o dejar ambas vacias.', 1;

    IF @DeliveryLatitude IS NOT NULL AND @DeliveryLatitude NOT BETWEEN -90 AND 90
        THROW 50002, 'La latitud debe estar entre -90 y 90.', 1;

    IF @DeliveryLongitude IS NOT NULL AND @DeliveryLongitude NOT BETWEEN -180 AND 180
        THROW 50003, 'La longitud debe estar entre -180 y 180.', 1;

    IF EXISTS (SELECT 1 FROM Syn_Customers WHERE CustomerName = @CustomerName)
        THROW 50004, 'Ya existe un cliente con ese nombre.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Contactos: si no se eligió una persona existente pero se escribió un nombre, se crea en Application.People
        EXEC SP_ObtenerOCrearPersona @PrimaryContactName, @LastEditedBy, @PrimaryContactPersonID OUTPUT;
        EXEC SP_ObtenerOCrearPersona @AlternateContactName, @LastEditedBy, @AlternateContactPersonID OUTPUT;

        IF @PrimaryContactPersonID IS NULL
            THROW 50030, 'Indique el contacto primario: elija una persona o escriba el nombre de una nueva.', 1;

        -- El ID sale de la secuencia, no de IDENTITY
        DECLARE @NewCustomerID INT = NEXT VALUE FOR Sequences.CustomerID;

        INSERT INTO Syn_Customers (CustomerID, CustomerName, CustomerCategoryID, BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID, BillToCustomerID, DeliveryMethodID, DeliveryCityID, PostalCityID, DeliveryPostalCode, PostalPostalCode, PhoneNumber, FaxNumber, PaymentDays, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, PostalAddressLine1, PostalAddressLine2, AccountOpenedDate, DeliveryLocation, LastEditedBy)
        VALUES (
            @NewCustomerID,
            @CustomerName,
            @CustomerCategoryID,
            NULLIF(@BuyingGroupID, 0),
            @PrimaryContactPersonID,
            NULLIF(@AlternateContactPersonID, 0),
            -- BillToCustomerID es NOT NULL: si no viene, el cliente se factura a si mismo
            COALESCE(NULLIF(@BillToCustomerID, 0), @NewCustomerID),
            @DeliveryMethodID,
            @DeliveryCityID,
            @PostalCityID,
            @DeliveryPostalCode,
            @PostalPostalCode,
            ISNULL(@PhoneNumber, ''),
            ISNULL(@FaxNumber, ''),
            @PaymentDays,
            ISNULL(@StandardDiscountPercentage, 0),
            ISNULL(@IsStatementSent, 0),
            ISNULL(@IsOnCreditHold, 0),
            ISNULL(@WebsiteURL, ''),
            @DeliveryAddressLine1,
            @DeliveryAddressLine2,
            @PostalAddressLine1,
            @PostalAddressLine2,
            ISNULL(@AccountOpenedDate, CAST(GETDATE() AS DATE)),
            CASE WHEN @DeliveryLatitude IS NULL AND @DeliveryLongitude IS NULL THEN NULL ELSE GEOGRAPHY::Point(@DeliveryLatitude, @DeliveryLongitude, 4326) END,
            COALESCE(@LastEditedBy, dbo.FN_EditorWeb())
        );

        SELECT @NewCustomerID AS NewCustomerID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO