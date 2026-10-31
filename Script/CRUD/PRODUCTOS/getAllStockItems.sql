use WideWorldImporters;
GO
CREATE OR ALTER PROCEDURE SP_GetAllStockItems
AS
BEGIN
    SELECT SI.StockItemID as StockItemID,
        SI.StockItemName as StockItemName,
        S.SupplierName as SupplierName,
        C.ColorName as ColorName,
        PT.PackageTypeName as UnitPackageTypeName,
        PT2.PackageTypeName as OuterPackageTypeName,
        SI.QuantityPerOuter as QuantityPerOuter,
        SI.Brand as Brand,
        SI.Size as Size,
        SI.TaxRate as TaxRate,
        SI.UnitPrice as UnitPrice,
        SI.RecommendedRetailPrice as RecommendedRetailPrice,
        SI.TypicalWeightPerUnit as TypicalWeightPerUnit,
        SI.SearchDetails as SearchDetail,
        SIH.QuantityOnHand as QuantityOnHand,
        SIH.BinLocation as BinLocation
    FROM Syn_StockItems SI
    INNER JOIN Syn_Suppliers S ON S.SupplierID = SI.SupplierID
    LEFT JOIN Syn_Colors C ON C.ColorID = SI.ColorID
    INNER JOIN Syn_StockItemHoldings SIH ON SIH.StockItemID = SI.StockItemID
    INNER JOIN Syn_PackageTypes PT ON PT.PackageTypeID = SI.UnitPackageID
    INNER JOIN Syn_PackageTypes PT2 ON PT2.PackageTypeID = SI.OuterPackageID
    ORDER BY SI.StockItemName ASC
END;
GO
