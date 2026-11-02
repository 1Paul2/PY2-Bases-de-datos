CREATE OR ALTER PROCEDURE SP_InsertCustomer
    @CustomerName NVARCHAR(100),
    @CustomerCategoryID INT,
    @BuyingGroupID INT = NULL,
    @PrimaryContactPersonID INT = NULL,
    @AlternateContactPersonID INT = NULL,
    @PrimaryContactName NVARCHAR(50) = NULL,
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
    @StandardDiscountPercentage DECIMAL(18, 3) = NULL,
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

    IF OBJECT_ID(N'Sales.CustomersSensible') IS NULL
        THROW 50090, 'Los clientes solo se crean, editan o eliminan en el corporativo.', 1;

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

        EXEC SP_ObtenerOCrearPersona @PrimaryContactName, @LastEditedBy, @PrimaryContactPersonID OUTPUT;
        EXEC SP_ObtenerOCrearPersona @AlternateContactName, @LastEditedBy, @AlternateContactPersonID OUTPUT;

        IF @PrimaryContactPersonID IS NULL
            THROW 50030, 'Indique el contacto primario: elija una persona o escriba el nombre de una nueva.', 1;

        DECLARE @NewCustomerID INT = NEXT VALUE FOR Sequences.CustomerID;

        INSERT INTO Syn_Customers (CustomerID, CustomerName, CustomerCategoryID, BuyingGroupID, BillToCustomerID, DeliveryMethodID, DeliveryCityID, PostalCityID, PaymentDays, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, AccountOpenedDate, LastEditedBy)
        VALUES (
            @NewCustomerID,
            @CustomerName,
            @CustomerCategoryID,
            NULLIF(@BuyingGroupID, 0),
            COALESCE(NULLIF(@BillToCustomerID, 0), @NewCustomerID),
            @DeliveryMethodID,
            @DeliveryCityID,
            @PostalCityID,
            @PaymentDays,
            ISNULL(@StandardDiscountPercentage, 0),
            ISNULL(@IsStatementSent, 0),
            ISNULL(@IsOnCreditHold, 0),
            ISNULL(@AccountOpenedDate, CAST(GETDATE() AS DATE)),
            COALESCE(@LastEditedBy, dbo.FN_EditorWeb())
        );

        INSERT INTO Syn_CustomersSensibleDatos (CustomerID, PrimaryContactPersonID, AlternateContactPersonID, PhoneNumber, FaxNumber, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2, PostalPostalCode)
        VALUES (
            @NewCustomerID,
            @PrimaryContactPersonID,
            NULLIF(@AlternateContactPersonID, 0),
            ISNULL(@PhoneNumber, ''),
            ISNULL(@FaxNumber, ''),
            ISNULL(@WebsiteURL, ''),
            @DeliveryAddressLine1,
            @DeliveryAddressLine2,
            @DeliveryPostalCode,
            CASE WHEN @DeliveryLatitude IS NULL AND @DeliveryLongitude IS NULL THEN NULL ELSE GEOGRAPHY::Point(@DeliveryLatitude, @DeliveryLongitude, 4326) END,
            @PostalAddressLine1,
            @PostalAddressLine2,
            @PostalPostalCode
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