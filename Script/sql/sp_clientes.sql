CREATE OR ALTER PROCEDURE SP_CLIENTES_ConContacto
    @Nombre VARCHAR(100)
AS
BEGIN 
    SELECT SC.CustomerID AS CustomerID,
    SC.CustomerCategoryID AS CustomerCategoryID,
    SC.BuyingGroupID AS BuyingGroupID,
    S.PrimaryContactPersonID AS PrimaryContactPersonID,
    S.AlternateContactPersonID AS AlternateContactPersonID,
    SC.BillToCustomerID AS BillToCustomerID,
    SC.DeliveryMethodID AS DeliveryMethodID,
    SC.DeliveryCityID AS DeliveryCityID,
    SC.PostalCityID AS PostalCityID,
    SC.CustomerName as Nombre,
    SCC.CustomerCategoryName as Categoría,
    -- Columnas para mostrar: los valores vacíos ya vienen con su texto desde la base
    ISNULL(SB.BuyingGroupName, 'No pertenece a un grupo de compra') as Grupo_de_compra,
    AP1.FullName as Contacto_Primario,
    ISNULL(AP2.FullName, 'No posee contacto alternativo') as Contacto_Secundario,
    AP2.FullName AS AlternateContactName,
    BillTo.CustomerName AS Cliente_por_facturar,
    ADM.DeliveryMethodName as Métodos_de_entrega,
    AC.CityName as Ciudad_de_entrega,
    S.DeliveryPostalCode as Código_postal,
    PC.CityName as Ciudad_postal,
    ISNULL(NULLIF(S.PhoneNumber, ''), 'No indica') AS Telefono,
    ISNULL(NULLIF(S.FaxNumber, ''), 'No indica') AS Fax,
    SC.PaymentDays as Días_de_gracia_para_pagar,
    S.WebsiteURL AS Sitio_web,
    S.DeliveryAddressLine1 AS Direccion_Entrega_1,
    ISNULL(NULLIF(S.DeliveryAddressLine2, ''), 'No indica') AS Direccion_Entrega_2,
    S.PostalAddressLine1 AS Direccion_Postal_1,
    ISNULL(NULLIF(S.PostalAddressLine2, ''), 'No indica') AS Direccion_Postal_2,
    S.PostalPostalCode AS PostalPostalCode,
    S.DeliveryPostalCode AS DeliveryPostalCode,
    S.PhoneNumber AS PhoneNumber,
    S.FaxNumber AS FaxNumber,
    SC.PaymentDays AS PaymentDays,
    SC.StandardDiscountPercentage AS StandardDiscountPercentage,
    SC.IsStatementSent AS IsStatementSent,
    SC.IsOnCreditHold AS IsOnCreditHold,
    S.WebsiteURL AS WebsiteURL,
    S.DeliveryAddressLine1 AS DeliveryAddressLine1,
    S.DeliveryAddressLine2 AS DeliveryAddressLine2,
    S.PostalAddressLine1 AS PostalAddressLine1,
    S.PostalAddressLine2 AS PostalAddressLine2,
    SC.AccountOpenedDate AS AccountOpenedDate,
    S.Latitud AS Latitud,
    S.Longitud AS Longitud,
    S.Latitud AS DeliveryLatitude,
    S.Longitud AS DeliveryLongitude,
    CAST(1 AS bit) AS ContactoDisponible
        FROM Syn_Customers SC
        INNER JOIN Syn_CustomersSensible S ON S.CustomerID = SC.CustomerID
        INNER JOIN Syn_CustomerCategories SCC ON SCC.CustomerCategoryID = SC.CustomerCategoryID
        LEFT JOIN Syn_BuyingGroups SB ON SB.BuyingGroupID = SC.BuyingGroupID
        INNER JOIN Syn_People AP1 ON AP1.PersonID = S.PrimaryContactPersonID
        LEFT JOIN Syn_People AP2 ON AP2.PersonID = S.AlternateContactPersonID
        LEFT JOIN Syn_Customers BillTo ON BillTo.CustomerID = SC.BillToCustomerID
        INNER JOIN Syn_DeliveryMethods ADM ON ADM.DeliveryMethodID = SC.DeliveryMethodID
        LEFT JOIN Syn_Cities AC ON AC.CityID = SC.DeliveryCityID
        LEFT JOIN Syn_Cities PC ON PC.CityID = SC.PostalCityID

    WHERE SC.CustomerName = @Nombre
    GROUP BY SC.CustomerID, SC.CustomerCategoryID, SC.BuyingGroupID, S.PrimaryContactPersonID,
        S.AlternateContactPersonID, SC.BillToCustomerID, SC.DeliveryMethodID, SC.DeliveryCityID,
        SC.PostalCityID,
        SC.CustomerName, SCC.CustomerCategoryName, SB.BuyingGroupName, AP1.FullName,
        AP2.FullName, BillTo.CustomerName, ADM.DeliveryMethodName, AC.CityName, PC.CityName, S.PostalPostalCode,
        S.DeliveryPostalCode,
        S.PhoneNumber, S.FaxNumber, SC.PaymentDays, SC.StandardDiscountPercentage, SC.IsStatementSent, SC.IsOnCreditHold, S.WebsiteURL, S.DeliveryAddressLine1,
        S.DeliveryAddressLine2, S.PostalAddressLine1, S.PostalAddressLine2, SC.AccountOpenedDate,
        S.Latitud,
        S.Longitud
    ORDER BY SC.CustomerName ASC
END;
GO

CREATE OR ALTER PROCEDURE SP_CLIENTES_SinContacto
    @Nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NoDisponible NVARCHAR(60) = N'No disponible: el corporativo no responde';

    SELECT SC.CustomerID AS CustomerID,
    SC.CustomerCategoryID AS CustomerCategoryID,
    SC.BuyingGroupID AS BuyingGroupID,
    CAST(NULL AS INT) AS PrimaryContactPersonID,
    CAST(NULL AS INT) AS AlternateContactPersonID,
    SC.BillToCustomerID AS BillToCustomerID,
    SC.DeliveryMethodID AS DeliveryMethodID,
    SC.DeliveryCityID AS DeliveryCityID,
    SC.PostalCityID AS PostalCityID,
    SC.CustomerName as Nombre,
    SCC.CustomerCategoryName as Categoría,
    ISNULL(SB.BuyingGroupName, 'No pertenece a un grupo de compra') as Grupo_de_compra,
    @NoDisponible as Contacto_Primario,
    @NoDisponible as Contacto_Secundario,
    CAST(NULL AS NVARCHAR(50)) AS AlternateContactName,
    BillTo.CustomerName AS Cliente_por_facturar,
    ADM.DeliveryMethodName as Métodos_de_entrega,
    AC.CityName as Ciudad_de_entrega,
    @NoDisponible as Código_postal,
    PC.CityName as Ciudad_postal,
    @NoDisponible AS Telefono,
    @NoDisponible AS Fax,
    SC.PaymentDays as Días_de_gracia_para_pagar,
    @NoDisponible AS Sitio_web,
    @NoDisponible AS Direccion_Entrega_1,
    @NoDisponible AS Direccion_Entrega_2,
    @NoDisponible AS Direccion_Postal_1,
    @NoDisponible AS Direccion_Postal_2,
    CAST(NULL AS NVARCHAR(10)) AS PostalPostalCode,
    CAST(NULL AS NVARCHAR(10)) AS DeliveryPostalCode,
    CAST(NULL AS NVARCHAR(20)) AS PhoneNumber,
    CAST(NULL AS NVARCHAR(20)) AS FaxNumber,
    SC.PaymentDays AS PaymentDays,
    SC.StandardDiscountPercentage AS StandardDiscountPercentage,
    SC.IsStatementSent AS IsStatementSent,
    SC.IsOnCreditHold AS IsOnCreditHold,
    CAST(NULL AS NVARCHAR(256)) AS WebsiteURL,
    CAST(NULL AS NVARCHAR(60)) AS DeliveryAddressLine1,
    CAST(NULL AS NVARCHAR(60)) AS DeliveryAddressLine2,
    CAST(NULL AS NVARCHAR(60)) AS PostalAddressLine1,
    CAST(NULL AS NVARCHAR(60)) AS PostalAddressLine2,
    SC.AccountOpenedDate AS AccountOpenedDate,
    CAST(NULL AS FLOAT) AS Latitud,
    CAST(NULL AS FLOAT) AS Longitud,
    CAST(NULL AS FLOAT) AS DeliveryLatitude,
    CAST(NULL AS FLOAT) AS DeliveryLongitude,
    CAST(0 AS bit) AS ContactoDisponible
        FROM Syn_Customers SC
        INNER JOIN Syn_CustomerCategories SCC ON SCC.CustomerCategoryID = SC.CustomerCategoryID
        LEFT JOIN Syn_BuyingGroups SB ON SB.BuyingGroupID = SC.BuyingGroupID
        LEFT JOIN Syn_Customers BillTo ON BillTo.CustomerID = SC.BillToCustomerID
        INNER JOIN Syn_DeliveryMethods ADM ON ADM.DeliveryMethodID = SC.DeliveryMethodID
        LEFT JOIN Syn_Cities AC ON AC.CityID = SC.DeliveryCityID
        LEFT JOIN Syn_Cities PC ON PC.CityID = SC.PostalCityID
    WHERE SC.CustomerName = @Nombre
    ORDER BY SC.CustomerName ASC
END;
GO

CREATE OR ALTER PROCEDURE SP_CLIENTES
    @Nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        EXEC dbo.SP_CLIENTES_ConContacto @Nombre = @Nombre;
    END TRY
    BEGIN CATCH
        EXEC dbo.SP_CLIENTES_SinContacto @Nombre = @Nombre;
    END CATCH
END;
GO

--EXEC SP_LISTA_CLIENTES @Apodo = 'Tail';
--EXEC SP_CLIENTES @Nombre = 'Tailspin Toys (Arbor Vitae, WI)';
CREATE OR ALTER PROCEDURE SP_LISTA_CLIENTES
    @Apodo VARCHAR(100) = NULL,
    @CustomerCategoryID INT = NULL,
    @DeliveryMethodID INT = NULL,
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*) OVER () AS TotalRegistros,
        SC.CustomerID AS CustomerID,
        SC.CustomerName AS Nombre,
        SCC.CustomerCategoryName AS Categoria,
        ADM.DeliveryMethodName AS Metodo_de_entrega
    FROM Syn_Customers SC
    INNER JOIN Syn_CustomerCategories SCC ON SCC.CustomerCategoryID = SC.CustomerCategoryID
    INNER JOIN Syn_DeliveryMethods ADM ON ADM.DeliveryMethodID = SC.DeliveryMethodID
    WHERE (@Apodo IS NULL OR SC.CustomerName LIKE '%' + @Apodo + '%')
      AND (@CustomerCategoryID IS NULL OR SC.CustomerCategoryID = @CustomerCategoryID)
      AND (@DeliveryMethodID IS NULL OR SC.DeliveryMethodID = @DeliveryMethodID)
    ORDER BY SC.CustomerName ASC
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;
END;
GO
