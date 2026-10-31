use WideWorldImporters;
GO
CREATE OR ALTER PROCEDURE SP_UpdateSupplier
    @SupplierID INT,
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

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Contactos: si no se eligió una persona existente pero se escribió un nombre, se crea en Application.People
        EXEC SP_ObtenerOCrearPersona @PrimaryContactName, @LastEditedBy, @PrimaryContactPersonID OUTPUT;
        EXEC SP_ObtenerOCrearPersona @AlternateContactName, @LastEditedBy, @AlternateContactPersonID OUTPUT;

        IF @PrimaryContactPersonID IS NULL
            THROW 50030, 'Indique el contacto primario: elija una persona o escriba el nombre de una nueva.', 1;

        IF NOT EXISTS (SELECT 1 FROM Syn_Suppliers WHERE SupplierID = @SupplierID)
            THROW 50004, 'El proveedor indicado no existe.', 1;

        IF EXISTS (SELECT 1 FROM Syn_Suppliers WHERE SupplierName = @SupplierName AND SupplierID <> @SupplierID)
            THROW 50005, 'Ya existe otro proveedor con ese nombre.', 1;

        UPDATE Syn_Suppliers
        SET SupplierReference = @SupplierReference,
            SupplierName = @SupplierName,
            SupplierCategoryID = @SupplierCategoryID,
            PrimaryContactPersonID = @PrimaryContactPersonID,
            AlternateContactPersonID = COALESCE(NULLIF(@AlternateContactPersonID, 0), @PrimaryContactPersonID),
            DeliveryMethodID = @DeliveryMethodID,
            DeliveryCityID = @DeliveryCityID,
            PostalCityID = @PostalCityID,
            DeliveryPostalCode = @DeliveryPostalCode,
            PostalPostalCode = @PostalPostalCode,
            PhoneNumber = ISNULL(@PhoneNumber, ''),
            FaxNumber = ISNULL(@FaxNumber, ''),
            WebsiteURL = ISNULL(@WebsiteURL, ''),
            DeliveryAddressLine1 = @DeliveryAddressLine1,
            DeliveryAddressLine2 = @DeliveryAddressLine2,
            PostalAddressLine1 = @PostalAddressLine1,
            PostalAddressLine2 = @PostalAddressLine2,
            DeliveryLocation = CASE
                WHEN @DeliveryLatitude IS NULL AND @DeliveryLongitude IS NULL
                    THEN NULL
                ELSE GEOGRAPHY::Point(@DeliveryLatitude, @DeliveryLongitude, 4326)
            END,
            BankAccountBranch = @BankAccountBranch,
            BankAccountName = @BankAccountName,
            BankAccountNumber = @BankAccountNumber,
            PaymentDays = @PaymentDays,
            LastEditedBy = @LastEditedBy
        WHERE SupplierID = @SupplierID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO