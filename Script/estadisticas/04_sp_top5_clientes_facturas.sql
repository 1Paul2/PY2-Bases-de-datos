USE WideWorldImporters;
GO

 -- #4

CREATE OR ALTER PROCEDURE sp_top5_clientes_facturas
    @anioInicio INT = NULL,  
    @anioFin INT = NULL,
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SET NOCOUNT ON;

    -- Si no se indican, se usa el rango completo de la base
    IF @anioInicio IS NULL SELECT @anioInicio = MIN(YEAR(InvoiceDate)) FROM Syn_Invoices;
    IF @anioFin IS NULL SELECT @anioFin    = MAX(YEAR(InvoiceDate)) FROM Syn_Invoices;

    -- Validar que los años existan en la base de datos
    IF NOT EXISTS (SELECT 1 FROM Syn_Invoices WHERE YEAR(InvoiceDate) = @anioInicio)
        THROW 50001, 'El año de inicio no existe en la base de datos.', 1;

    IF NOT EXISTS (SELECT 1 FROM Syn_Invoices WHERE YEAR(InvoiceDate) = @anioFin)
        THROW 50002, 'El año final no existe en la base de datos.', 1;

    IF @anioInicio > @anioFin
        THROW 50003, 'El año de inicio no puede ser mayor que el año final.', 1;

    WITH TotalPorFactura AS (
        SELECT
            I.InvoiceID,
            I.CustomerID,
            YEAR(I.InvoiceDate) AS Anio,
            SUM(IL.ExtendedPrice) AS TotalFactura
        FROM Syn_Invoices I
        INNER JOIN Syn_InvoiceLines IL ON IL.InvoiceID = I.InvoiceID
        WHERE YEAR(I.InvoiceDate) BETWEEN @anioInicio AND @anioFin
        GROUP BY I.InvoiceID, I.CustomerID, YEAR(I.InvoiceDate)
    ),
    FacturasPorCliente AS (
        SELECT
            T.Anio,
            C.CustomerID,
            C.CustomerName,
            COUNT(*)            AS CantidadFacturas,
            SUM(T.TotalFactura) AS MontoTotal
        FROM TotalPorFactura T
        INNER JOIN Syn_Customers C ON C.CustomerID = T.CustomerID
        GROUP BY T.Anio, C.CustomerID, C.CustomerName
    ),
    Ranking AS (
        SELECT
            Anio,
            CustomerName,
            CantidadFacturas,
            MontoTotal,
            DENSE_RANK() OVER (PARTITION BY Anio ORDER BY CantidadFacturas DESC) AS Posicion
        FROM FacturasPorCliente
    )
    SELECT
        COUNT(*) OVER () AS TotalRegistros,
        Anio,
        Posicion,
        CustomerName AS Cliente,
        CantidadFacturas,
        MontoTotal
    FROM Ranking
    WHERE Posicion <= 5
    ORDER BY Anio, Posicion, CustomerName
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;
END;
GO
