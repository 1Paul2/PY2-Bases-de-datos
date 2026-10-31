USE WideWorldImporters;
GO

-- #7

 CREATE OR ALTER PROCEDURE sp_seguimiento_compras_cliente
    @anio INT = NULL,
    @mes INT = NULL,
    @categoria VARCHAR(100) = NULL,
    @cliente VARCHAR(100) = NULL,
    @categoriaId INT = NULL,     -- grupo de producto (categoría)
    @subcategoriaId INT = NULL,  -- segundo grupo del producto (subcategoría)
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validaciones
    IF @anio IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM Syn_Invoices WHERE YEAR(InvoiceDate) = @anio)
        THROW 50001, 'El año indicado no existe en la base de datos.', 1;

    IF @mes IS NOT NULL AND @mes NOT BETWEEN 1 AND 12
        THROW 50002, 'El mes debe estar entre 1 y 12.', 1;

    WITH Lineas AS (
        SELECT
            I.CustomerID,
            I.InvoiceID,
            I.InvoiceDate,
            YEAR(I.InvoiceDate)  AS Anio,
            MONTH(I.InvoiceDate) AS Mes,
            IL.Quantity,
            IL.ExtendedPrice
        FROM Syn_Invoices I
        INNER JOIN Syn_InvoiceLines IL ON IL.InvoiceID = I.InvoiceID
        WHERE (@anio IS NULL OR YEAR(I.InvoiceDate)  = @anio)
          AND (@mes  IS NULL OR MONTH(I.InvoiceDate) = @mes)
          AND (@categoria IS NULL OR EXISTS (
                SELECT 1
                FROM Syn_StockItemStockGroups SIG
                INNER JOIN Syn_StockGroups SG ON SG.StockGroupID = SIG.StockGroupID
                WHERE SIG.StockItemID = IL.StockItemID
                  AND SG.StockGroupName LIKE '%' + @categoria + '%'))
          AND (@categoriaId IS NULL OR EXISTS (
                SELECT 1 FROM Syn_StockItemStockGroups SIG
                WHERE SIG.StockItemID = IL.StockItemID AND SIG.StockGroupID = @categoriaId))
          AND (@subcategoriaId IS NULL OR EXISTS (
                SELECT 1 FROM Syn_StockItemStockGroups SIG
                WHERE SIG.StockItemID = IL.StockItemID AND SIG.StockGroupID = @subcategoriaId))
          AND (@cliente IS NULL OR EXISTS (
                SELECT 1 FROM Syn_Customers CF
                WHERE CF.CustomerID = I.CustomerID AND CF.CustomerName LIKE '%' + @cliente + '%'))
    ),
    Resumen AS (
        SELECT
            CustomerID, Anio, Mes,
            COUNT(DISTINCT InvoiceID) AS CantidadFacturas,
            SUM(ExtendedPrice) AS MontoTotal,
            SUM(Quantity) AS CantidadTotal,
            MIN(Quantity) AS CantidadMinima,
            MAX(Quantity) AS CantidadMaxima
        FROM Lineas
        GROUP BY CustomerID, Anio, Mes
    ),
    Facturas AS (
        SELECT
            CustomerID, Anio, Mes, InvoiceID, InvoiceDate,
            ROW_NUMBER() OVER (PARTITION BY CustomerID, Anio, Mes
                               ORDER BY InvoiceDate ASC,  InvoiceID ASC)  AS RnPrimera,
            ROW_NUMBER() OVER (PARTITION BY CustomerID, Anio, Mes
                               ORDER BY InvoiceDate DESC, InvoiceID DESC) AS RnUltima
        FROM (SELECT DISTINCT CustomerID, Anio, Mes, InvoiceID, InvoiceDate FROM Lineas) F
    )
    SELECT
        COUNT(*) OVER () AS TotalRegistros,
        C.CustomerName AS Cliente,
        R.Anio,
        R.Mes,
        R.CantidadFacturas,
        R.MontoTotal,
        P.InvoiceID AS PrimeraFactura,
        P.InvoiceDate AS FechaPrimera,
        U.InvoiceID AS UltimaFactura,
        U.InvoiceDate AS FechaUltima,
        R.CantidadTotal,
        R.CantidadMinima,
        R.CantidadMaxima
    FROM Resumen R
    INNER JOIN Syn_Customers C ON C.CustomerID = R.CustomerID
    INNER JOIN Facturas P ON P.CustomerID = R.CustomerID AND P.Anio = R.Anio
                         AND P.Mes = R.Mes AND P.RnPrimera = 1
    INNER JOIN Facturas U ON U.CustomerID = R.CustomerID AND U.Anio = R.Anio
                         AND U.Mes = R.Mes AND U.RnUltima = 1
    ORDER BY C.CustomerName, R.Anio, R.Mes
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;
END;
GO