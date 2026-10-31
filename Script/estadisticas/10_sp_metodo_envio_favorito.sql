USE WideWorldImporters;
GO

-- #10 

CREATE OR ALTER PROCEDURE sp_metodo_envio_favorito
    @anio INT = NULL,
    @mes INT = NULL,
    @catCliente VARCHAR(100) = NULL,   
    @catProducto VARCHAR(100) = NULL,  
    @producto VARCHAR(100) = NULL,  
    @soloFavorito BIT = 1,
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

    WITH Ventas AS (
        SELECT
            I.InvoiceID,
            I.DeliveryMethodID,
            C.DeliveryCityID
        FROM Syn_Invoices I
        INNER JOIN Syn_Customers C          ON C.CustomerID = I.CustomerID
        INNER JOIN Syn_CustomerCategories CC ON CC.CustomerCategoryID = C.CustomerCategoryID
        WHERE (@anio IS NULL OR YEAR(I.InvoiceDate)  = @anio)
          AND (@mes  IS NULL OR MONTH(I.InvoiceDate) = @mes)
          AND (@catCliente IS NULL OR CC.CustomerCategoryName LIKE '%' + @catCliente + '%')
          AND ((@catProducto IS NULL AND @producto IS NULL) OR EXISTS (
                SELECT 1
                FROM Syn_InvoiceLines IL
                INNER JOIN Syn_StockItems SI ON SI.StockItemID = IL.StockItemID
                WHERE IL.InvoiceID = I.InvoiceID
                  AND (@producto IS NULL OR SI.StockItemName LIKE '%' + @producto + '%')
                  AND (@catProducto IS NULL OR EXISTS (
                        SELECT 1
                        FROM Syn_StockItemStockGroups SIG
                        INNER JOIN Syn_StockGroups SG ON SG.StockGroupID = SIG.StockGroupID
                        WHERE SIG.StockItemID = SI.StockItemID
                          AND SG.StockGroupName LIKE '%' + @catProducto + '%'))))
    ),
    Conteo AS (
        SELECT
            DeliveryCityID,
            DeliveryMethodID,
            COUNT(*) AS CantidadVentas
        FROM Ventas
        GROUP BY DeliveryCityID, DeliveryMethodID
    ),
    Ranking AS (
        SELECT
            DeliveryCityID,
            DeliveryMethodID,
            CantidadVentas,
            SUM(CantidadVentas) OVER (PARTITION BY DeliveryCityID) AS TotalVentasLugar,
            DENSE_RANK() OVER (PARTITION BY DeliveryCityID
                               ORDER BY CantidadVentas DESC) AS Posicion
        FROM Conteo
    )
    SELECT
        COUNT(*) OVER () AS TotalRegistros,
        SP.StateProvinceName AS Provincia,
        CI.CityName AS Ciudad,
        DM.DeliveryMethodName AS MetodoEnvio,
        R.CantidadVentas,
        R.TotalVentasLugar,
        R.Posicion
    FROM Ranking R
    INNER JOIN Syn_Cities CI ON CI.CityID = R.DeliveryCityID
    INNER JOIN Syn_StateProvinces SP ON SP.StateProvinceID = CI.StateProvinceID
    INNER JOIN Syn_DeliveryMethods DM ON DM.DeliveryMethodID = R.DeliveryMethodID
    WHERE @soloFavorito = 0 OR R.Posicion = 1
    ORDER BY R.CantidadVentas DESC, SP.StateProvinceName, CI.CityName, R.Posicion
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;
END;
GO



