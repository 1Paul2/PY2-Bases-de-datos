USE WideWorldImporters;
GO

-- #8

CREATE OR ALTER PROCEDURE sp_seguimiento_compras_proveedor
    @anio INT = NULL,
    @mes INT = NULL,
    @categoria VARCHAR(100) = NULL,
    @proveedor VARCHAR(100) = NULL,
    @categoriaId INT = NULL,     -- grupo de producto (categoría)
    @subcategoriaId INT = NULL,  -- segundo grupo del producto (subcategoría)
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validaciones
    IF @anio IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM Syn_PurchaseOrders WHERE YEAR(OrderDate) = @anio)
        THROW 50001, 'El año indicado no existe en la base de datos.', 1;

    IF @mes IS NOT NULL AND @mes NOT BETWEEN 1 AND 12
        THROW 50002, 'El mes debe estar entre 1 y 12.', 1;

    WITH Lineas AS (
        SELECT
            PO.SupplierID,
            PO.PurchaseOrderID,
            PO.OrderDate,
            YEAR(PO.OrderDate) AS Anio,
            MONTH(PO.OrderDate) AS Mes,
            POL.OrderedOuters,
            POL.OrderedOuters * POL.ExpectedUnitPricePerOuter AS Monto
        FROM Syn_PurchaseOrders PO
        INNER JOIN Syn_PurchaseOrderLines POL ON POL.PurchaseOrderID = PO.PurchaseOrderID
        WHERE (@anio IS NULL OR YEAR(PO.OrderDate)  = @anio)
          AND (@mes  IS NULL OR MONTH(PO.OrderDate) = @mes)
          AND (@categoria IS NULL OR EXISTS (
                SELECT 1
                FROM Syn_StockItemStockGroups SIG
                INNER JOIN Syn_StockGroups SG ON SG.StockGroupID = SIG.StockGroupID
                WHERE SIG.StockItemID = POL.StockItemID
                  AND SG.StockGroupName LIKE '%' + @categoria + '%'))
          AND (@categoriaId IS NULL OR EXISTS (
                SELECT 1 FROM Syn_StockItemStockGroups SIG
                WHERE SIG.StockItemID = POL.StockItemID AND SIG.StockGroupID = @categoriaId))
          AND (@subcategoriaId IS NULL OR EXISTS (
                SELECT 1 FROM Syn_StockItemStockGroups SIG
                WHERE SIG.StockItemID = POL.StockItemID AND SIG.StockGroupID = @subcategoriaId))
          AND (@proveedor IS NULL OR EXISTS (
                SELECT 1 FROM Syn_Suppliers SF
                WHERE SF.SupplierID = PO.SupplierID AND SF.SupplierName LIKE '%' + @proveedor + '%'))
    ),
    Resumen AS (
        SELECT
            SupplierID, Anio, Mes,
            COUNT(DISTINCT PurchaseOrderID) AS CantidadOrdenes,
            SUM(Monto) AS MontoTotal,
            SUM(OrderedOuters) AS CantidadTotal,
            MIN(OrderedOuters) AS CantidadMinima,
            MAX(OrderedOuters) AS CantidadMaxima
        FROM Lineas
        GROUP BY SupplierID, Anio, Mes
    ),
    Ordenes AS (
        SELECT
            SupplierID, Anio, Mes, PurchaseOrderID, OrderDate,
            ROW_NUMBER() OVER (PARTITION BY SupplierID, Anio, Mes
                               ORDER BY OrderDate ASC,  PurchaseOrderID ASC)  AS RnPrimera,
            ROW_NUMBER() OVER (PARTITION BY SupplierID, Anio, Mes
                               ORDER BY OrderDate DESC, PurchaseOrderID DESC) AS RnUltima
        FROM (SELECT DISTINCT SupplierID, Anio, Mes, PurchaseOrderID, OrderDate FROM Lineas) O
    )
    SELECT
        COUNT(*) OVER () AS TotalRegistros,
        S.SupplierName AS Proveedor,
        R.Anio,
        R.Mes,
        R.CantidadOrdenes,
        R.MontoTotal,
        P.PurchaseOrderID AS PrimeraOrden,
        P.OrderDate AS FechaPrimera,
        U.PurchaseOrderID AS UltimaOrden,
        U.OrderDate AS FechaUltima,
        R.CantidadTotal,
        R.CantidadMinima,
        R.CantidadMaxima
    FROM Resumen R
    INNER JOIN Syn_Suppliers S ON S.SupplierID = R.SupplierID
    INNER JOIN Ordenes P ON P.SupplierID = R.SupplierID AND P.Anio = R.Anio
                        AND P.Mes = R.Mes AND P.RnPrimera = 1
    INNER JOIN Ordenes U ON U.SupplierID = R.SupplierID AND U.Anio = R.Anio
                        AND U.Mes = R.Mes AND U.RnUltima = 1
    ORDER BY S.SupplierName, R.Anio, R.Mes
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;
END;
GO