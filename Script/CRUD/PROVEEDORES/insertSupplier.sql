USE WideWorldImporters;
GO
CREATE OR ALTER PROCEDURE SP_InsertSupplier
    @SupplierReference NVARCHAR(40),
    @SupplierName NVARCHAR(100),
    @SupplierCategoryID INT,
    @PrimaryContactPersonID INT = NULL,
    @AlternateContactPersonID INT = NULL,
    @PrimaryContactName NVARCHAR(50) = NULL,     -- nombre de un contacto nuevo
    @AlternateContactName NVARCHAR(50) = NULL,
    @DeliveryMethodID INT,
    @DeliveryCityID INT,
    @PostalCityID INT,
    @DeliveryPostalCode NVARCHAR(20),
    @PostalPostalCode NVARCHAR(20),
    @PhoneNumber NVARCHAR(40),
    @FaxNumber NVARCHAR(40),
    @WebsiteURL NVARCHAR(512),
    @DeliveryAddressLine1 NVARCHAR(120),
    @DeliveryAddressLine2 NVARCHAR(120) = NULL,
    @PostalAddressLine1 NVARCHAR(120),
    @PostalAddressLine2 NVARCHAR(120) = NULL,
    @DeliveryLatitude DECIMAL(9, 6) = NULL,
    @DeliveryLongitude DECIMAL(9, 6) = NULL,
    @BankAccountBranch NVARCHAR(100),
    @BankAccountName NVARCHAR(100),
    @BankAccountNumber NVARCHAR(40),
    @PaymentDays INT,
    @LastEditedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Quién hizo el cambio lo decide la base: si no viene, se usa la persona PagWeb (usuario de la página web)
    SET @LastEditedBy = ISNULL(@LastEditedBy, dbo.FN_EditorWeb());

    IF (@DeliveryLatitude IS NULL AND @DeliveryLongitude IS NOT NULL)
       OR (@DeliveryLatitude IS NOT NULL AND @DeliveryLongitude IS NULL)
        THROW 50001, 'Debe indicar ambas coordenadas o dejar ambas vacias.', 1;

    IF @DeliveryLatitude IS NOT NULL AND @DeliveryLatitude NOT BETWEEN -90 AND 90
        THROW 50002, 'La latitud debe estar entre -90 y 90.', 1;

    IF @DeliveryLongitude IS NOT NULL AND @DeliveryLongitude NOT BETWEEN -180 AND 180
        THROW 50003, 'La longitud debe estar entre -180 y 180.', 1;

    IF EXISTS (SELECT 1 FROM Syn_Suppliers WHERE SupplierName = @SupplierName)
        THROW 50004, 'Ya existe un proveedor con ese nombre.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Contactos: si no se eligió una persona existente pero se escribió un nombre, se crea en Application.People
        EXEC SP_ObtenerOCrearPersona @PrimaryContactName, @LastEditedBy, @PrimaryContactPersonID OUTPUT;
        EXEC SP_ObtenerOCrearPersona @AlternateContactName, @LastEditedBy, @AlternateContactPersonID OUTPUT;

        IF @PrimaryContactPersonID IS NULL
            THROW 50030, 'Indique el contacto primario: elija una persona o escriba el nombre de una nueva.', 1;

        -- El ID sale de la secuencia, no de IDENTITY
        DECLARE @NewSupplierID INT = NEXT VALUE FOR Sequences.SupplierID;

        INSERT INTO Syn_Suppliers (
            SupplierID,
            SupplierReference,
            SupplierName,
            SupplierCategoryID,
            PrimaryContactPersonID,
            AlternateContactPersonID,
            DeliveryMethodID,
            DeliveryCityID,
            PostalCityID,
            DeliveryPostalCode,
            PostalPostalCode,
            PhoneNumber,
            FaxNumber,
            WebsiteURL,
            DeliveryAddressLine1,
            DeliveryAddressLine2,
            PostalAddressLine1,
            PostalAddressLine2,
            DeliveryLocation,
            BankAccountBranch,
            BankAccountName,
            BankAccountNumber,
            PaymentDays,
            LastEditedBy
        )
        VALUES (
            @NewSupplierID,
            @SupplierReference,
            @SupplierName,
            @SupplierCategoryID,
            @PrimaryContactPersonID,
            COALESCE(NULLIF(@AlternateContactPersonID, 0), @PrimaryContactPersonID),
            @DeliveryMethodID,
            @DeliveryCityID,
            @PostalCityID,
            @DeliveryPostalCode,
            @PostalPostalCode,
            ISNULL(@PhoneNumber, ''),
            ISNULL(@FaxNumber, ''),
            ISNULL(@WebsiteURL, ''),
            @DeliveryAddressLine1,
            @DeliveryAddressLine2,
            @PostalAddressLine1,
            @PostalAddressLine2,
            CASE
                WHEN @DeliveryLatitude IS NULL AND @DeliveryLongitude IS NULL
                    THEN NULL
                ELSE GEOGRAPHY::Point(@DeliveryLatitude, @DeliveryLongitude, 4326)
            END,
            @BankAccountBranch,
            @BankAccountName,
            @BankAccountNumber,
            @PaymentDays,
            @LastEditedBy
        );

        SELECT @NewSupplierID AS NewSupplierID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO