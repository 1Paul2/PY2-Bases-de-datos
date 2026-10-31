USE WideWorldImporters;
GO

-- #9

DROP SYNONYM IF EXISTS Syn_StockItemTransactions;
CREATE SYNONYM Syn_StockItemTransactions FOR Warehouse.StockItemTransactions;
GO

CREATE OR ALTER PROCEDURE sp_rotacion_inventario
    @anio INT = NULL,
    @categoria VARCHAR(100) = NULL,
    @proveedor VARCHAR(100) = NULL,
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que el año exista en los movimientos de inventario
    IF @anio IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM Syn_StockItemTransactions
                       WHERE YEAR(TransactionOccurredWhen) = @anio)
        THROW 50001, 'El año indicado no existe en la base de datos.', 1;

    -- Última fecha con datos
    DECLARE @ultima DATE;
    SELECT @ultima = MAX(CAST(TransactionOccurredWhen AS DATE))
    FROM Syn_StockItemTransactions;

    WITH Productos AS (
        SELECT SI.StockItemID, SI.StockItemName, S.SupplierName
        FROM Syn_StockItems SI
        INNER JOIN Syn_Suppliers S ON S.SupplierID = SI.SupplierID
        WHERE (@proveedor IS NULL OR S.SupplierName LIKE '%' + @proveedor + '%')
          AND (@categoria IS NULL OR EXISTS (
                SELECT 1
                FROM Syn_StockItemStockGroups SIG
                INNER JOIN Syn_StockGroups SG ON SG.StockGroupID = SIG.StockGroupID
                WHERE SIG.StockItemID = SI.StockItemID
                  AND SG.StockGroupName LIKE '%' + @categoria + '%'))
    ),
    MovimientosAnio AS (
        SELECT
            T.StockItemID,
            YEAR(T.TransactionOccurredWhen) AS Anio,
            SUM(T.Quantity) AS MovimientoNeto,
            SUM(CASE WHEN T.CustomerID IS NOT NULL AND T.Quantity < 0
                     THEN -T.Quantity ELSE 0 END) AS UnidadesVendidas
        FROM Syn_StockItemTransactions T
        INNER JOIN Productos P ON P.StockItemID = T.StockItemID
        GROUP BY T.StockItemID, YEAR(T.TransactionOccurredWhen)
    ),
    Movimiento AS (
        SELECT
            M.StockItemID, M.Anio, M.MovimientoNeto, M.UnidadesVendidas,
            -- suma de los movimientos hasta el cierre de cada año
            SUM(M.MovimientoNeto) OVER (PARTITION BY M.StockItemID ORDER BY M.Anio
                                        ROWS UNBOUNDED PRECEDING) AS MovimientoAcumulado,
            -- suma de todos los movimientos del producto
            SUM(M.MovimientoNeto) OVER (PARTITION BY M.StockItemID) AS MovimientoTotal,
            -- existencia real actual del producto
            ISNULL(H.QuantityOnHand, 0) AS ExistenciaActual
        FROM MovimientosAnio M
        LEFT JOIN Syn_StockItemHoldings H ON H.StockItemID = M.StockItemID
    ),
    Acumulado AS (
        SELECT
            StockItemID, Anio, MovimientoNeto, UnidadesVendidas,
            MovimientoAcumulado, MovimientoTotal, ExistenciaActual,
            MIN(MovimientoAcumulado) OVER (PARTITION BY StockItemID) AS MinimoAcumulado
        FROM Movimiento
    ),
    Inventario AS (
        SELECT
            A.StockItemID, A.Anio, A.UnidadesVendidas,
            -- La base no trae saldo de apertura. Se parte de la existencia actual y se
            -- retrocede con los movimientos; si los movimientos del producto no cuadran
            -- con su existencia actual, el saldo inicial es el mínimo que evita
            -- inventarios negativos (nunca menor que cero).
            B.SaldoInicial + A.MovimientoAcumulado AS InventarioFinal,
            B.SaldoInicial + A.MovimientoAcumulado - A.MovimientoNeto AS InventarioInicial
        FROM Acumulado A
        CROSS APPLY (
            SELECT MAX(V.Valor) AS SaldoInicial
            FROM (VALUES
                (CAST(A.ExistenciaActual - A.MovimientoTotal AS DECIMAL(18,3))),
                (CAST(-A.MinimoAcumulado AS DECIMAL(18,3))),
                (CAST(0 AS DECIMAL(18,3)))
            ) V(Valor)
        ) B
    ),
    Calculo AS (
        SELECT
            I.StockItemID, I.Anio, I.UnidadesVendidas,
            I.InventarioInicial, I.InventarioFinal,
            (I.InventarioInicial + I.InventarioFinal) / 2.0 AS InventarioPromedio,
            DATEDIFF(DAY, DATEFROMPARTS(I.Anio, 1, 1),
                     CASE WHEN DATEFROMPARTS(I.Anio, 12, 31) > @ultima
                          THEN @ultima ELSE DATEFROMPARTS(I.Anio, 12, 31) END) + 1 AS DiasPeriodo
        FROM Inventario I
        WHERE @anio IS NULL OR I.Anio = @anio    -- el filtro va después de los acumulados
    )
    SELECT
        COUNT(*) OVER () AS TotalRegistros,
        P.StockItemName AS Producto,
        P.SupplierName  AS Proveedor,
        C.Anio,
        C.InventarioInicial,
        C.InventarioFinal,
        CAST(C.InventarioPromedio AS DECIMAL(18,2)) AS InventarioPromedio,
        C.UnidadesVendidas,
        CAST(C.UnidadesVendidas / NULLIF(C.InventarioPromedio, 0) AS DECIMAL(18,2)) AS Rotacion,
        CAST(C.DiasPeriodo * C.InventarioPromedio
             / NULLIF(C.UnidadesVendidas, 0) AS DECIMAL(18,2)) AS DiasRotacion
    FROM Calculo C
    INNER JOIN Productos P ON P.StockItemID = C.StockItemID
    ORDER BY P.StockItemName, C.Anio
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;
END;
GO