USE WideWorldImporters;
GO

-- Persona con la que se registran los cambios hechos desde la página web (LastEditedBy).
-- Se crea una sola vez; los SPs la buscan por nombre.
IF NOT EXISTS (SELECT 1 FROM Syn_People WHERE FullName = 'PagWeb')
    INSERT INTO Syn_People (FullName, PreferredName, IsPermittedToLogon, IsExternalLogonProvider,
                            IsSystemUser, IsEmployee, IsSalesperson, LastEditedBy)
    VALUES ('PagWeb', 'PagWeb', 0, 0, 1, 1, 0, 1);
GO

CREATE OR ALTER FUNCTION FN_EditorWeb()
RETURNS INT
AS
BEGIN
    RETURN ISNULL((SELECT TOP 1 PersonID FROM Syn_People WHERE FullName = 'PagWeb'), 1);
END;
GO

/*
  Catálogos para llenar las listas de selección y los buscadores de los formularios.
  Así la interfaz no pide IDs a mano: el usuario elige el nombre y se guarda el ID.
*/

CREATE OR ALTER PROCEDURE SP_GetCustomerCategories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CustomerCategoryID, CustomerCategoryName
    FROM Syn_CustomerCategories
    ORDER BY CustomerCategoryName;
END;
GO

CREATE OR ALTER PROCEDURE SP_GetBuyingGroups
AS
BEGIN
    SET NOCOUNT ON;
    SELECT BuyingGroupID, BuyingGroupName
    FROM Syn_BuyingGroups
    ORDER BY BuyingGroupName;
END;
GO

CREATE OR ALTER PROCEDURE SP_GetDeliveryMethods
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DeliveryMethodID, DeliveryMethodName
    FROM Syn_DeliveryMethods
    ORDER BY DeliveryMethodName;
END;
GO

CREATE OR ALTER PROCEDURE SP_GetColors
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ColorID, ColorName
    FROM Syn_Colors
    ORDER BY ColorName;
END;
GO

CREATE OR ALTER PROCEDURE SP_GetPackageTypes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PackageTypeID, PackageTypeName
    FROM Syn_PackageTypes
    ORDER BY PackageTypeName;
END;
GO

CREATE OR ALTER PROCEDURE SP_GetSuppliersCatalog
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SupplierID, SupplierName
    FROM Syn_Suppliers
    ORDER BY SupplierName;
END;
GO

-- Hay miles de ciudades, por eso se buscan por texto y se devuelven pocas
CREATE OR ALTER PROCEDURE SP_SearchCities
    @Criterio NVARCHAR(50) = NULL,
    @Cantidad INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Cantidad)
        C.CityID,
        C.CityName,
        SP.StateProvinceName,
        C.CityName + ', ' + SP.StateProvinceName AS Texto
    FROM Syn_Cities C
    INNER JOIN Syn_StateProvinces SP ON SP.StateProvinceID = C.StateProvinceID
    WHERE @Criterio IS NULL OR @Criterio = '' OR C.CityName LIKE @Criterio + '%'
    ORDER BY C.CityName, SP.StateProvinceName;
END;
GO

CREATE OR ALTER PROCEDURE SP_SearchPeople
    @Criterio NVARCHAR(50) = NULL,
    @SoloVendedores BIT = 0,
    @Cantidad INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Cantidad)
        P.PersonID,
        P.FullName
    FROM Syn_People P
    WHERE (@Criterio IS NULL OR @Criterio = ''
           OR P.FullName LIKE @Criterio + '%'
           OR P.FullName LIKE '% ' + @Criterio + '%')
      AND (@SoloVendedores = 0 OR P.IsSalesperson = 1)
    ORDER BY P.FullName;
END;
GO

CREATE OR ALTER PROCEDURE SP_SearchCustomers
    @Criterio NVARCHAR(100) = NULL,
    @Cantidad INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Cantidad)
        C.CustomerID,
        C.CustomerName,
        C.DeliveryMethodID,
        C.PrimaryContactPersonID,
        P.FullName AS PrimaryContactName
    FROM Syn_Customers C
    INNER JOIN Syn_People P ON P.PersonID = C.PrimaryContactPersonID
    WHERE @Criterio IS NULL OR @Criterio = '' OR C.CustomerName LIKE '%' + @Criterio + '%'
    ORDER BY C.CustomerName;
END;
GO

CREATE OR ALTER PROCEDURE SP_SearchStockItems
    @Criterio NVARCHAR(100) = NULL,
    @Cantidad INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Cantidad)
        SI.StockItemID,
        SI.StockItemName,
        SI.UnitPrice,
        SI.TaxRate,
        ISNULL(SIH.QuantityOnHand, 0) AS QuantityOnHand
    FROM Syn_StockItems SI
    LEFT JOIN Syn_StockItemHoldings SIH ON SIH.StockItemID = SI.StockItemID
    WHERE @Criterio IS NULL OR @Criterio = '' OR SI.StockItemName LIKE '%' + @Criterio + '%'
    ORDER BY SI.StockItemName;
END;
GO

-- Años que existen en la base, para los filtros de las estadísticas
-- @Tipo: 'ventas' (facturas), 'compras' (órdenes de compra) o 'inventario' (movimientos)
CREATE OR ALTER PROCEDURE SP_GetYears
    @Tipo VARCHAR(20) = 'ventas'
AS
BEGIN
    SET NOCOUNT ON;

    IF @Tipo = 'compras'
        SELECT DISTINCT YEAR(OrderDate) AS Anio FROM Syn_PurchaseOrders ORDER BY Anio;
    ELSE IF @Tipo = 'inventario'
        SELECT DISTINCT YEAR(TransactionOccurredWhen) AS Anio FROM Syn_StockItemTransactions ORDER BY Anio;
    ELSE
        SELECT DISTINCT YEAR(InvoiceDate) AS Anio FROM Syn_Invoices ORDER BY Anio;
END;
GO

-- Meses para los filtros de las estadísticas
CREATE OR ALTER PROCEDURE SP_GetMonths
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Mes, Nombre
    FROM (VALUES
        (1, 'Enero'), (2, 'Febrero'), (3, 'Marzo'), (4, 'Abril'),
        (5, 'Mayo'), (6, 'Junio'), (7, 'Julio'), (8, 'Agosto'),
        (9, 'Septiembre'), (10, 'Octubre'), (11, 'Noviembre'), (12, 'Diciembre')
    ) AS M(Mes, Nombre)
    ORDER BY Mes;
END;
GO

/*
  Opciones para los FILTROS: solo las que tienen registros asociados
  (para los formularios se usan las listas completas de arriba).
*/
CREATE OR ALTER PROCEDURE SP_GetCustomerCategoriesInUse
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CC.CustomerCategoryID, CC.CustomerCategoryName
    FROM Syn_CustomerCategories CC
    WHERE EXISTS (SELECT 1 FROM Syn_Customers C WHERE C.CustomerCategoryID = CC.CustomerCategoryID)
    ORDER BY CC.CustomerCategoryName;
END;
GO

CREATE OR ALTER PROCEDURE SP_GetSupplierCategoriesInUse
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SC.SupplierCategoryID, SC.SupplierCategoryName
    FROM Syn_SupplierCategories SC
    WHERE EXISTS (SELECT 1 FROM Syn_Suppliers S WHERE S.SupplierCategoryID = SC.SupplierCategoryID)
    ORDER BY SC.SupplierCategoryName;
END;
GO

CREATE OR ALTER PROCEDURE SP_GetDeliveryMethodsInUse
    @Tipo VARCHAR(20) = 'clientes'   -- 'clientes' o 'proveedores'
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DM.DeliveryMethodID, DM.DeliveryMethodName
    FROM Syn_DeliveryMethods DM
    WHERE (@Tipo = 'clientes' AND EXISTS (SELECT 1 FROM Syn_Customers C WHERE C.DeliveryMethodID = DM.DeliveryMethodID))
       OR (@Tipo = 'proveedores' AND EXISTS (SELECT 1 FROM Syn_Suppliers S WHERE S.DeliveryMethodID = DM.DeliveryMethodID))
    ORDER BY DM.DeliveryMethodName;
END;
GO

CREATE OR ALTER PROCEDURE SP_GetStockGroupsInUse
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SG.StockGroupID, SG.StockGroupName
    FROM Syn_StockGroups SG
    WHERE EXISTS (SELECT 1 FROM Syn_StockItemStockGroups G WHERE G.StockGroupID = SG.StockGroupID)
    ORDER BY SG.StockGroupName;
END;
GO

/*
  Devuelve el ID de una persona para usarla como contacto.
    - Si @PersonID viene con valor, valida que exista y lo devuelve.
    - Si no, y se escribió un nombre: reutiliza la persona con ese nombre exacto
      o la crea en Application.People (igual que el PRY2).
    - Si no hay ID ni nombre, devuelve NULL.
  Se llama desde los SPs de clientes y proveedores, dentro de su transacción.
*/
CREATE OR ALTER PROCEDURE SP_ObtenerOCrearPersona
    @Nombre NVARCHAR(50) = NULL,
    @EditadoPor INT = NULL,
    @PersonID INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF ISNULL(@PersonID, 0) > 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM Syn_People WHERE PersonID = @PersonID)
            THROW 50031, 'La persona indicada como contacto no existe.', 1;
        RETURN;
    END;

    SET @PersonID = NULL;
    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    IF @Nombre IS NULL RETURN;

    SELECT TOP 1 @PersonID = PersonID
    FROM Syn_People
    WHERE FullName = @Nombre
    ORDER BY PersonID;

    IF @PersonID IS NOT NULL RETURN;

    SET @PersonID = NEXT VALUE FOR Sequences.PersonID;

    INSERT INTO Syn_People (PersonID, FullName, PreferredName, IsPermittedToLogon, IsExternalLogonProvider,
                            IsSystemUser, IsEmployee, IsSalesperson, LastEditedBy)
    VALUES (@PersonID, @Nombre, @Nombre, 0, 0, 0, 0, 0, ISNULL(@EditadoPor, dbo.FN_EditorWeb()));
END;
GO
