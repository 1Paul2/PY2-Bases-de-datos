USE WideWorldImporters;
GO

 -- #3
CREATE OR ALTER PROCEDURE sp_top5_productos_ganancia
    @anio INT = NULL,
    @anioFin INT = NULL,
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SET NOCOUNT ON;

    IF @anio IS NULL AND @anioFin IS NOT NULL
        SET @anio = @anioFin;

    IF @anio IS NOT NULL AND @anioFin IS NULL
        SET @anioFin = @anio;

    IF @anio IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM Syn_Invoices WHERE YEAR(InvoiceDate) = @anio)
            THROW 50001, 'El año indicado no existe en la base de datos.', 1;

        IF NOT EXISTS (SELECT 1 FROM Syn_Invoices WHERE YEAR(InvoiceDate) = @anioFin)
            THROW 50002, 'El año final no existe en la base de datos.', 1;

        IF @anio > @anioFin
            THROW 50003, 'El año de inicio no puede ser mayor que el año final.', 1;
    END;

    WITH GananciaPorProducto AS (
        SELECT
            YEAR(I.InvoiceDate) AS Anio,
            SI.StockItemID,
            SI.StockItemName,
            SUM(IL.LineProfit) AS Ganancia
        FROM Syn_Invoices I
        INNER JOIN Syn_InvoiceLines IL ON IL.InvoiceID = I.InvoiceID
        INNER JOIN Syn_StockItems SI ON SI.StockItemID = IL.StockItemID
        WHERE @anio IS NULL OR YEAR(I.InvoiceDate) BETWEEN @anio AND @anioFin
        GROUP BY YEAR(I.InvoiceDate), SI.StockItemID, SI.StockItemName
    ),
    Ranking AS (
        SELECT
            Anio,
            StockItemName,
            Ganancia,
            DENSE_RANK() OVER (PARTITION BY Anio ORDER BY Ganancia DESC) AS Posicion
        FROM GananciaPorProducto
    )
    SELECT
        COUNT(*) OVER () AS TotalRegistros,
        Anio,
        Posicion,
        StockItemName AS Producto,
        Ganancia
    FROM Ranking
    WHERE Posicion <= 5
    ORDER BY Anio, Posicion, StockItemName
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;
END;
GO