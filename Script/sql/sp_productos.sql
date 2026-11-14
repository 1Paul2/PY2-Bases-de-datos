IF OBJECT_ID(N'Sales.CustomersSensible') IS NOT NULL
    EXEC (N'CREATE OR ALTER VIEW dbo.vExistenciasProducto AS
        SELECT StockItemID,
               SUM(QuantityOnHand) AS QuantityOnHand,
               CAST(NULL AS nvarchar(20)) AS BinLocation,
               CAST(NULL AS int) AS LastStocktakeQuantity,
               CAST(NULL AS decimal(18, 2)) AS LastCostPrice,
               CAST(NULL AS int) AS ReorderLevel,
               CAST(NULL AS int) AS TargetStockLevel,
               CAST(NULL AS datetime2(7)) AS LastEditedWhen
        FROM Syn_StockItemHoldings
        GROUP BY StockItemID;');
ELSE
    EXEC (N'CREATE OR ALTER VIEW dbo.vExistenciasProducto AS
        SELECT StockItemID, QuantityOnHand, BinLocation, LastStocktakeQuantity,
               LastCostPrice, ReorderLevel, TargetStockLevel, LastEditedWhen
        FROM Syn_StockItemHoldings;');
GO

CREATE OR ALTER PROCEDURE SP_GetStockGroups
AS
BEGIN
    SELECT SG.StockGroupID as StockGroupID,
    SG.StockGroupName as StockGroupName
    FROM Syn_StockGroups SG
    ORDER BY SG.StockGroupName ASC
END;
GO

CREATE OR ALTER PROCEDURE SP_GetStockItems
    @Name NVARCHAR(100) = NULL,
    @StockGroupID INT = NULL,
    @CantidadMinima INT = NULL,
    @CantidadMaxima INT = NULL,
    @Pagina INT = NULL,
    @PorPagina INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) OVER () AS TotalRegistros,
    SI.StockItemID as StockItemID,
    SI.StockItemName as StockItemName,
    STRING_AGG(SG.StockGroupName, ', ') WITHIN GROUP (ORDER BY SG.StockGroupName) as StockGroupNames,
    ISNULL(SIH.QuantityOnHand, 0) as QuantityOnHand
    FROM Syn_StockItems SI
    LEFT JOIN Syn_StockItemStockGroups SIG ON SIG.StockItemID = SI.StockItemID
    LEFT JOIN Syn_StockGroups SG ON SG.StockGroupID = SIG.StockGroupID
    LEFT JOIN dbo.vExistenciasProducto SIH ON SIH.StockItemID = SI.StockItemID
    WHERE (@Name IS NULL OR SI.StockItemName LIKE '%' + @Name + '%')
        AND (@StockGroupID IS NULL OR EXISTS (
                SELECT 1 FROM Syn_StockItemStockGroups G
                WHERE G.StockItemID = SI.StockItemID AND G.StockGroupID = @StockGroupID))
        AND (@CantidadMinima IS NULL OR ISNULL(SIH.QuantityOnHand, 0) >= @CantidadMinima)
        AND (@CantidadMaxima IS NULL OR ISNULL(SIH.QuantityOnHand, 0) <= @CantidadMaxima)
    GROUP BY SI.StockItemID, SI.StockItemName, SIH.QuantityOnHand
    ORDER BY SI.StockItemName ASC
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY
END;
GO

CREATE OR ALTER PROCEDURE SP_GetStockItemDetails
    @StockItemID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT SI.StockItemID as StockItemID,
    SI.StockItemName as StockItemName,
    S.SupplierID as SupplierID,
    S.SupplierName as SupplierName,
    SI.LeadTimeDays as LeadTimeDays,
    COALESCE(C.ColorName, 'No posee color registrado') as ColorName,
    SI.ColorID as ColorID,
    SI.UnitPackageID as UnitPackageID,
    SI.OuterPackageID as OuterPackageID,
    PT.PackageTypeName as UnitPackageTypeName,
    PT2.PackageTypeName as OuterPackageTypeName,
    SI.QuantityPerOuter as QuantityPerOuter,
    SI.Brand as Brand,
    SI.Size as Size,
    ISNULL(NULLIF(SI.Brand, ''), 'No posee marca') as BrandTexto,
    ISNULL(NULLIF(SI.Size, ''), 'No indica tamaño') as SizeTexto,
    SI.TaxRate as TaxRate,
    SI.UnitPrice as UnitPrice,
    SI.IsChillerStock as IsChillerStock,
    SI.RecommendedRetailPrice as RecommendedRetailPrice,
    SI.TypicalWeightPerUnit as TypicalWeightPerUnit,
    SI.SearchDetails as SearchDetails,
    SI.MarketingComments as MarketingComments,
    ISNULL(NULLIF(SI.MarketingComments, ''), 'Sin comentarios') as MarketingCommentsTexto,
    CASE WHEN SI.IsChillerStock = 1 THEN 'Sí' ELSE 'No' END as RefrigeradoTexto,
    SIH.QuantityOnHand as QuantityOnHand,
    SIH.BinLocation as BinLocation,
    ISNULL(NULLIF(SIH.BinLocation, ''), 'No indica') as BinLocationTexto,
    ISNULL(SIH.QuantityOnHand, 0) as QuantityOnHandTexto,
    SI.Barcode as Barcode,
    SI.InternalComments as InternalComments,
    SIH.LastStocktakeQuantity as LastStocktakeQuantity,
    SIH.LastCostPrice as LastCostPrice,
    SIH.ReorderLevel as ReorderLevel,
    SIH.TargetStockLevel as TargetStockLevel,
    (SELECT STRING_AGG(SG.StockGroupName, ', ') WITHIN GROUP (ORDER BY SG.StockGroupName)
       FROM Syn_StockItemStockGroups G
       INNER JOIN Syn_StockGroups SG ON SG.StockGroupID = G.StockGroupID
      WHERE G.StockItemID = SI.StockItemID) as StockGroupNames,
    ISNULL((SELECT STRING_AGG(SG.StockGroupName, ', ') WITHIN GROUP (ORDER BY SG.StockGroupName)
       FROM Syn_StockItemStockGroups G
       INNER JOIN Syn_StockGroups SG ON SG.StockGroupID = G.StockGroupID
      WHERE G.StockItemID = SI.StockItemID), 'Sin grupo') as StockGroupNamesTexto,
    (SELECT STRING_AGG(CAST(G.StockGroupID AS VARCHAR(10)), ',')
       FROM Syn_StockItemStockGroups G
      WHERE G.StockItemID = SI.StockItemID) as StockGroupIDs,
    CONCAT(CONVERT(VARCHAR(27), SI.LastEditedWhen, 121), '|', CONVERT(VARCHAR(27), SIH.LastEditedWhen, 121)) as Version
    FROM Syn_StockItems SI
    INNER JOIN Syn_Suppliers S ON S.SupplierID = SI.SupplierID
    LEFT JOIN Syn_Colors C ON C.ColorID = SI.ColorID
    LEFT JOIN dbo.vExistenciasProducto SIH ON SIH.StockItemID = SI.StockItemID
    INNER JOIN Syn_PackageTypes PT ON PT.PackageTypeID = SI.UnitPackageID
    INNER JOIN Syn_PackageTypes PT2 ON PT2.PackageTypeID = SI.OuterPackageID

    WHERE SI.StockItemID = @StockItemID
END;
GO
