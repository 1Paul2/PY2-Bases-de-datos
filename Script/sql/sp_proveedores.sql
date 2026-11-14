CREATE OR ALTER PROCEDURE SP_GetSupplierCategories
AS
BEGIN
    SELECT SC.SupplierCategoryID as SupplierCategoryID,
    SC.SupplierCategoryName as SupplierCategoryName
    from Syn_SupplierCategories SC
    ORDER BY SC.SupplierCategoryName ASC
END;
GO

CREATE OR ALTER PROCEDURE SP_GetSuppliers
    @Name NVARCHAR(100) = NULL,
    @SupplierCategoryID INT = NULL,
    @DeliveryMethodID INT = NULL,
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SELECT COUNT(*) OVER () AS TotalRegistros,
    S.SupplierID as SupplierID,
    S.SupplierName as SupplierName,
    SC.SupplierCategoryName as SupplierCategoryName,
    COALESCE(DM.DeliveryMethodName, 'No indica') as DeliveryMethodName
    FROM Syn_Suppliers S
    INNER JOIN Syn_SupplierCategories SC ON SC.SupplierCategoryID = S.SupplierCategoryID
    LEFT JOIN Syn_DeliveryMethods DM ON S.DeliveryMethodID = DM.DeliveryMethodID
    WHERE (@Name IS NULL OR S.SupplierName LIKE '%' + @Name + '%')
        AND (@SupplierCategoryID IS NULL OR S.SupplierCategoryID = @SupplierCategoryID)
        AND (@DeliveryMethodID IS NULL OR S.DeliveryMethodID = @DeliveryMethodID)
    ORDER BY S.SupplierName ASC
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY
END;
GO

CREATE OR ALTER PROCEDURE SP_GetSupplierDetails_ConContacto
    @SupplierID INT
AS
BEGIN
    SELECT S.SupplierReference as SupplierReference,
    S.SupplierCategoryID as SupplierCategoryID,
    SS.PrimaryContactPersonID as PrimaryContactPersonID,
    SS.AlternateContactPersonID as AlternateContactPersonID,
    S.DeliveryMethodID as DeliveryMethodID,
    S.DeliveryCityID as DeliveryCityID,
    S.PostalCityID as PostalCityID,
    S.SupplierName as SupplierName,
    SC.SupplierCategoryName as SupplierCategoryName,
    P.FullName as PrimaryContactName,
    P2.FullName as AlternateContactName,
    ISNULL(DM.DeliveryMethodName, 'No indica') as DeliveryMethodName,
    C.CityName as DeliveryCityName,
    PC.CityName as PostalCityName,
    SS.DeliveryPostalCode as DeliveryPostalCode,
    SS.PostalPostalCode as PostalPostalCode,
    SS.PhoneNumber as PhoneNumber,
    SS.FaxNumber as FaxNumber,
    SS.WebsiteURL as WebsiteURL,
    SS.DeliveryAddressLine1 as DeliveryAddressLine1,
    SS.DeliveryAddressLine2 as DeliveryAddressLine2,
    ISNULL(NULLIF(SS.DeliveryAddressLine2, ''), 'No indica') as DeliveryAddressLine2Texto,
    SS.PostalAddressLine1 as PostalAddressLine1,
    SS.PostalAddressLine2 as PostalAddressLine2,
    ISNULL(NULLIF(SS.PostalAddressLine2, ''), 'No indica') as PostalAddressLine2Texto,
    ISNULL(NULLIF(SS.FaxNumber, ''), 'No indica') as FaxTexto,
    ISNULL(NULLIF(SS.WebsiteURL, ''), 'No indica') as WebsiteTexto,
    SS.Latitud as DeliveryLatitude,
    SS.Longitud as DeliveryLongitude,
    SS.BankAccountBranch as BankAccountBranch,
    SS.BankAccountName as BankAccountName,
    SS.BankAccountNumber as BankAccountNumber,
    S.PaymentDays as PaymentDays,
    S.LastEditedBy as LastEditedBy,
    CAST(1 AS bit) as ContactoDisponible
    FROM Syn_Suppliers S
    INNER JOIN Syn_SuppliersSensible SS ON SS.SupplierID = S.SupplierID
    INNER JOIN Syn_SupplierCategories SC ON SC.SupplierCategoryID = S.SupplierCategoryID
    LEFT JOIN Syn_DeliveryMethods DM ON S.DeliveryMethodID = DM.DeliveryMethodID
    INNER JOIN Syn_People P ON P.PersonID = SS.PrimaryContactPersonID
    LEFT JOIN Syn_People P2 ON P2.PersonID = SS.AlternateContactPersonID
    LEFT JOIN Syn_Cities C ON C.CityID = S.DeliveryCityID
    LEFT JOIN Syn_Cities PC ON PC.CityID = S.PostalCityID

    WHERE S.SupplierID = @SupplierID
END;
GO

-- Mismas columnas sin el fragmento sensible: se usa cuando el corporativo no responde
CREATE OR ALTER PROCEDURE SP_GetSupplierDetails_SinContacto
    @SupplierID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NoDisponible NVARCHAR(60) = N'No disponible: el corporativo no responde';

    SELECT S.SupplierReference as SupplierReference,
    S.SupplierCategoryID as SupplierCategoryID,
    CAST(NULL AS INT) as PrimaryContactPersonID,
    CAST(NULL AS INT) as AlternateContactPersonID,
    S.DeliveryMethodID as DeliveryMethodID,
    S.DeliveryCityID as DeliveryCityID,
    S.PostalCityID as PostalCityID,
    S.SupplierName as SupplierName,
    SC.SupplierCategoryName as SupplierCategoryName,
    @NoDisponible as PrimaryContactName,
    @NoDisponible as AlternateContactName,
    ISNULL(DM.DeliveryMethodName, 'No indica') as DeliveryMethodName,
    C.CityName as DeliveryCityName,
    PC.CityName as PostalCityName,
    @NoDisponible as DeliveryPostalCode,
    @NoDisponible as PostalPostalCode,
    @NoDisponible as PhoneNumber,
    CAST(NULL AS NVARCHAR(20)) as FaxNumber,
    CAST(NULL AS NVARCHAR(256)) as WebsiteURL,
    @NoDisponible as DeliveryAddressLine1,
    CAST(NULL AS NVARCHAR(60)) as DeliveryAddressLine2,
    @NoDisponible as DeliveryAddressLine2Texto,
    @NoDisponible as PostalAddressLine1,
    CAST(NULL AS NVARCHAR(60)) as PostalAddressLine2,
    @NoDisponible as PostalAddressLine2Texto,
    @NoDisponible as FaxTexto,
    @NoDisponible as WebsiteTexto,
    CAST(NULL AS FLOAT) as DeliveryLatitude,
    CAST(NULL AS FLOAT) as DeliveryLongitude,
    @NoDisponible as BankAccountBranch,
    @NoDisponible as BankAccountName,
    @NoDisponible as BankAccountNumber,
    S.PaymentDays as PaymentDays,
    S.LastEditedBy as LastEditedBy,
    CAST(0 AS bit) as ContactoDisponible
    FROM Syn_Suppliers S
    INNER JOIN Syn_SupplierCategories SC ON SC.SupplierCategoryID = S.SupplierCategoryID
    LEFT JOIN Syn_DeliveryMethods DM ON S.DeliveryMethodID = DM.DeliveryMethodID
    LEFT JOIN Syn_Cities C ON C.CityID = S.DeliveryCityID
    LEFT JOIN Syn_Cities PC ON PC.CityID = S.PostalCityID
    WHERE S.SupplierID = @SupplierID
END;
GO

-- Si el corporativo no responde, devuelve la parte de la sucursal en vez de fallar.
-- El error del linked server puede ocurrir al compilar la consulta remota, por eso va en otro procedimiento
CREATE OR ALTER PROCEDURE SP_GetSupplierDetails
    @SupplierID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        EXEC dbo.SP_GetSupplierDetails_ConContacto @SupplierID = @SupplierID;
    END TRY
    BEGIN CATCH
        EXEC dbo.SP_GetSupplierDetails_SinContacto @SupplierID = @SupplierID;
    END CATCH
END;
GO
