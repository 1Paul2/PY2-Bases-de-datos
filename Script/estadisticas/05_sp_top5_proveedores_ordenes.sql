USE WideWorldImporters;
GO

-- #5


CREATE OR ALTER PROCEDURE sp_top5_proveedores_ordenes
    @anioInicio INT = NULL,  
    @anioFin INT = NULL,
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SET NOCOUNT ON;

    -- Si no se indican, se usa el rango completo de la base
    IF @anioInicio IS NULL SELECT @anioInicio = MIN(YEAR(OrderDate)) FROM Syn_PurchaseOrders;
    IF @anioFin    IS NULL SELECT @anioFin    = MAX(YEAR(OrderDate)) FROM Syn_PurchaseOrders;

    -- Validar que los años existan en la base de datos
    IF NOT EXISTS (SELECT 1 FROM Syn_PurchaseOrders WHERE YEAR(OrderDate) = @anioInicio)
        THROW 50001, 'El año de inicio no existe en la base de datos.', 1;

    IF NOT EXISTS (SELECT 1 FROM Syn_PurchaseOrders WHERE YEAR(OrderDate) = @anioFin)
        THROW 50002, 'El año final no existe en la base de datos.', 1;

    IF @anioInicio > @anioFin
        THROW 50003, 'El año de inicio no puede ser mayor que el año final.', 1;

    WITH TotalPorOrden AS (
        SELECT
            PO.PurchaseOrderID,
            PO.SupplierID,
            YEAR(PO.OrderDate) AS Anio,
            SUM(POL.OrderedOuters * POL.ExpectedUnitPricePerOuter) AS TotalOrden
        FROM Syn_PurchaseOrders PO
        INNER JOIN Syn_PurchaseOrderLines POL ON POL.PurchaseOrderID = PO.PurchaseOrderID
        WHERE YEAR(PO.OrderDate) BETWEEN @anioInicio AND @anioFin
        GROUP BY PO.PurchaseOrderID, PO.SupplierID, YEAR(PO.OrderDate)
    ),
    OrdenesPorProveedor AS (
        SELECT
            T.Anio,
            S.SupplierID,
            S.SupplierName,
            COUNT(*) AS CantidadOrdenes,
            SUM(T.TotalOrden) AS MontoTotal
        FROM TotalPorOrden T
        INNER JOIN Syn_Suppliers S ON S.SupplierID = T.SupplierID
        GROUP BY T.Anio, S.SupplierID, S.SupplierName
    ),
    Ranking AS (
        SELECT
            Anio,
            SupplierName,
            CantidadOrdenes,
            MontoTotal,
            DENSE_RANK() OVER (PARTITION BY Anio ORDER BY CantidadOrdenes DESC) AS Posicion
        FROM OrdenesPorProveedor
    )
    SELECT
        COUNT(*) OVER () AS TotalRegistros,
        Anio,
        Posicion,
        SupplierName AS Proveedor,
        CantidadOrdenes,
        MontoTotal
    FROM Ranking
    WHERE Posicion <= 5
    ORDER BY Anio, Posicion, SupplierName
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;
END;
GO
