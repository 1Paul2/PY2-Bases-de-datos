USE WideWorldImporters;
GO

-- #6
CREATE OR ALTER PROCEDURE sp_matriz_ventas_categoria_anio
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cols NVARCHAR(MAX);  
    DECLARE @colsSelect NVARCHAR(MAX);  
    DECLARE @sql NVARCHAR(MAX);

    -- Años en los que realmente hubo ventas
    SELECT @cols = STUFF((
        SELECT ',' + QUOTENAME(CAST(Anio AS VARCHAR(4)))
        FROM (SELECT DISTINCT YEAR(InvoiceDate) AS Anio FROM Syn_Invoices) A
        ORDER BY Anio
        FOR XML PATH('')), 1, 1, '');

    SELECT @colsSelect = STUFF((
        SELECT ',ISNULL(' + QUOTENAME(CAST(Anio AS VARCHAR(4))) + ', 0) AS '
               + QUOTENAME(CAST(Anio AS VARCHAR(4)))
        FROM (SELECT DISTINCT YEAR(InvoiceDate) AS Anio FROM Syn_Invoices) A
        ORDER BY Anio
        FOR XML PATH('')), 1, 1, '');

    SET @sql = N'
        SELECT COUNT(*) OVER () AS TotalRegistros, Categoria, ' + @colsSelect + N'
        FROM (
            SELECT
                SG.StockGroupName   AS Categoria,
                YEAR(I.InvoiceDate) AS Anio,
                IL.ExtendedPrice    AS Monto
            FROM Syn_Invoices I
            INNER JOIN Syn_InvoiceLines IL 
                ON IL.InvoiceID = I.InvoiceID
            -- Cada venta se suma en TODAS las categorías (grupos) del producto,
            -- así aparecen todas las categorías que tienen ventas
            INNER JOIN Syn_StockItemStockGroups SIG
                ON SIG.StockItemID = IL.StockItemID
            INNER JOIN Syn_StockGroups SG
                ON SG.StockGroupID = SIG.StockGroupID
        ) Origen
        PIVOT (
            SUM(Monto) FOR Anio IN (' + @cols + N')
        ) AS Matriz
        ORDER BY Categoria
        OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
        FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;';

    EXEC sp_executesql @sql, N'@Pagina INT, @PorPagina INT', @Pagina = @Pagina, @PorPagina = @PorPagina;
END;
GO
