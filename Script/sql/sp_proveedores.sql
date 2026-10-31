use WideWorldImporters
GO

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

CREATE OR ALTER PROCEDURE SP_GetSupplierDetails
    @SupplierID INT
AS
BEGIN
    SELECT S.SupplierReference as SupplierReference,
    S.SupplierCategoryID as SupplierCategoryID,
    S.PrimaryContactPersonID as PrimaryContactPersonID,
    S.AlternateContactPersonID as AlternateContactPersonID,
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
    S.DeliveryPostalCode as DeliveryPostalCode,
    S.PostalPostalCode as PostalPostalCode,
    S.PhoneNumber as PhoneNumber,
    S.FaxNumber as FaxNumber,
    S.WebsiteURL as WebsiteURL,
    S.DeliveryAddressLine1 as DeliveryAddressLine1,
    S.DeliveryAddressLine2 as DeliveryAddressLine2,
    ISNULL(NULLIF(S.DeliveryAddressLine2, ''), 'No indica') as DeliveryAddressLine2Texto,
    S.PostalAddressLine1 as PostalAddressLine1,
    S.PostalAddressLine2 as PostalAddressLine2,
    ISNULL(NULLIF(S.PostalAddressLine2, ''), 'No indica') as PostalAddressLine2Texto,
    ISNULL(NULLIF(S.FaxNumber, ''), 'No indica') as FaxTexto,
    ISNULL(NULLIF(S.WebsiteURL, ''), 'No indica') as WebsiteTexto,
    S.DeliveryLocation.Lat as DeliveryLatitude,
    S.DeliveryLocation.Long as DeliveryLongitude,
    S.BankAccountBranch as BankAccountBranch,
    S.BankAccountName as BankAccountName,
    S.BankAccountNumber as BankAccountNumber,
    S.PaymentDays as PaymentDays,
    S.LastEditedBy as LastEditedBy
    FROM Syn_Suppliers S
    INNER JOIN Syn_SupplierCategories SC ON SC.SupplierCategoryID = S.SupplierCategoryID
    LEFT JOIN Syn_DeliveryMethods DM ON S.DeliveryMethodID = DM.DeliveryMethodID
    INNER JOIN Syn_People P ON P.PersonID = S.PrimaryContactPersonID
    LEFT JOIN Syn_People P2 ON P2.PersonID = S.AlternateContactPersonID
    LEFT JOIN Syn_Cities C ON C.CityID = S.DeliveryCityID
    LEFT JOIN Syn_Cities PC ON PC.CityID = S.PostalCityID

    WHERE S.SupplierID = @SupplierID
END;
GO