USE WideWorldImporters;
GO

-- #1
-- Monto mínimo, máximo y promedio de las órdenes de compra por proveedor y categoría (ROLLUP)

CREATE OR ALTER PROCEDURE sp_estadistica_proveedor
    @proveedor VARCHAR(100) = '',
    @categoria VARCHAR(100) = '',
    @Pagina INT = NULL,       -- página a consultar (NULL = todas)
    @PorPagina INT = NULL     -- registros por página (NULL = todos)
AS
BEGIN
    SET NOCOUNT ON;

    WITH TotalesPorPedido AS (
        SELECT
            S.SupplierName,
            SC.SupplierCategoryName,
            PO.PurchaseOrderID,
            SUM(POL.OrderedOuters * POL.ExpectedUnitPricePerOuter) AS TotalPedido
        FROM Syn_Suppliers S
        INNER JOIN Syn_SupplierCategories SC ON SC.SupplierCategoryID = S.SupplierCategoryID
        INNER JOIN Syn_PurchaseOrders PO ON PO.SupplierID = S.SupplierID
        INNER JOIN Syn_PurchaseOrderLines POL ON POL.PurchaseOrderID = PO.PurchaseOrderID
        WHERE S.SupplierName LIKE '%' + ISNULL(@proveedor, '') + '%'
          AND SC.SupplierCategoryName LIKE '%' + ISNULL(@categoria, '') + '%'
        GROUP BY S.SupplierName, SC.SupplierCategoryName, PO.PurchaseOrderID
    )
    SELECT
        COUNT(*) OVER () AS TotalRegistros,
        CASE WHEN GROUPING(SupplierName) = 1 THEN 'Total general' ELSE SupplierName END AS Proveedor,
        CASE WHEN GROUPING(SupplierCategoryName) = 1 THEN 'Total' ELSE SupplierCategoryName END AS Categoria,
        MIN(TotalPedido) AS Minimo,
        MAX(TotalPedido) AS Maximo,
        AVG(TotalPedido) AS Promedio
    FROM TotalesPorPedido
    GROUP BY ROLLUP (SupplierName, SupplierCategoryName)
    ORDER BY GROUPING(SupplierName), SupplierName, GROUPING(SupplierCategoryName), SupplierCategoryName
    OFFSET (ISNULL(@Pagina, 1) - 1) * ISNULL(@PorPagina, 2147483647) ROWS
    FETCH NEXT ISNULL(@PorPagina, 2147483647) ROWS ONLY;
END;
GO
