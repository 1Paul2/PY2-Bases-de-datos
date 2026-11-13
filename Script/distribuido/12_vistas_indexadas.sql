SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
USE [$(BASE)];
GO

IF N'$(NODO)' IN (N'sanjose', N'limon') AND OBJECT_ID(N'dbo.sysarticles') IS NOT NULL
BEGIN
    DECLARE @conDrop int = (SELECT COUNT(*) FROM dbo.sysarticles
                            WHERE name IN (N'Facturas', N'LineasFactura', N'Compras', N'LineasCompra') AND pre_creation_cmd <> 2);
    IF @conDrop > 0
        PRINT CONCAT('AVISO: ', @conDrop, ' articulos de ventas todavia borran la tabla al reinicializar; reconstruya los nodos desde cero');
    ELSE
        PRINT 'Articulos de ventas: al reinicializar vacian las tablas (compatibles con las vistas indexadas)';
END
GO

IF N'$(NODO)' = N'corporativo'
BEGIN
    IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'Resumen')
          AND name IN (N'Facturas_SJ', N'LineasFactura_SJ', N'Compras_SJ', N'LineasCompra_SJ',
                       N'Facturas_LI', N'LineasFactura_LI', N'Compras_LI', N'LineasCompra_LI')) < 8
    BEGIN
        PRINT 'Las tablas Resumen todavia no estan listas; las vistas indexadas se crean al volver a correr levantar';
        RETURN;
    END

    DECLARE @suc char(2), @sql nvarchar(max);
    DECLARE s CURSOR LOCAL FAST_FORWARD FOR SELECT v FROM (VALUES ('SJ'), ('LI')) x(v);
    OPEN s;
    FETCH NEXT FROM s INTO @suc;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF OBJECT_ID(N'Resumen.ivVentasMes_' + @suc) IS NULL
        BEGIN
            SET @sql = N'CREATE VIEW Resumen.ivVentasMes_' + @suc + N' WITH SCHEMABINDING AS
                SELECT YEAR(F.InvoiceDate) AS Anio, MONTH(F.InvoiceDate) AS Mes,
                       COUNT_BIG(*) AS Lineas,
                       SUM(L.Quantity) AS Unidades,
                       SUM(L.ExtendedPrice) AS Monto,
                       SUM(L.LineProfit) AS Ganancia
                FROM Resumen.Facturas_' + @suc + N' F
                INNER JOIN Resumen.LineasFactura_' + @suc + N' L ON L.InvoiceID = F.InvoiceID
                GROUP BY YEAR(F.InvoiceDate), MONTH(F.InvoiceDate);';
            EXEC (@sql);
        END
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'Resumen.ivVentasMes_' + @suc) AND index_id = 1)
            EXEC (N'CREATE UNIQUE CLUSTERED INDEX CIX_ivVentasMes_' + @suc + N' ON Resumen.ivVentasMes_' + @suc + N' (Anio, Mes);');

        IF OBJECT_ID(N'Resumen.ivComprasMes_' + @suc) IS NULL
        BEGIN
            SET @sql = N'CREATE VIEW Resumen.ivComprasMes_' + @suc + N' WITH SCHEMABINDING AS
                SELECT YEAR(C.OrderDate) AS Anio, MONTH(C.OrderDate) AS Mes,
                       COUNT_BIG(*) AS Lineas,
                       SUM(L.OrderedOuters) AS Bultos,
                       SUM(L.OrderedOuters * ISNULL(L.ExpectedUnitPricePerOuter, 0)) AS MontoEsperado
                FROM Resumen.Compras_' + @suc + N' C
                INNER JOIN Resumen.LineasCompra_' + @suc + N' L ON L.PurchaseOrderID = C.PurchaseOrderID
                GROUP BY YEAR(C.OrderDate), MONTH(C.OrderDate);';
            EXEC (@sql);
        END
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'Resumen.ivComprasMes_' + @suc) AND index_id = 1)
            EXEC (N'CREATE UNIQUE CLUSTERED INDEX CIX_ivComprasMes_' + @suc + N' ON Resumen.ivComprasMes_' + @suc + N' (Anio, Mes);');

        FETCH NEXT FROM s INTO @suc;
    END
    CLOSE s;
    DEALLOCATE s;

    EXEC (N'CREATE OR ALTER VIEW Resumen.vVentasMes AS
        SELECT CAST(''SJ'' AS char(2)) AS Sucursal, Anio, Mes, Lineas, Unidades, Monto, Ganancia
        FROM Resumen.ivVentasMes_SJ WITH (NOEXPAND)
        UNION ALL
        SELECT CAST(''LI'' AS char(2)), Anio, Mes, Lineas, Unidades, Monto, Ganancia
        FROM Resumen.ivVentasMes_LI WITH (NOEXPAND);');

    EXEC (N'CREATE OR ALTER VIEW Resumen.vComprasMes AS
        SELECT CAST(''SJ'' AS char(2)) AS Sucursal, Anio, Mes, Lineas, Bultos, MontoEsperado
        FROM Resumen.ivComprasMes_SJ WITH (NOEXPAND)
        UNION ALL
        SELECT CAST(''LI'' AS char(2)), Anio, Mes, Lineas, Bultos, MontoEsperado
        FROM Resumen.ivComprasMes_LI WITH (NOEXPAND);');

    DECLARE @indexadas int = (SELECT COUNT(*) FROM sys.views v JOIN sys.indexes i ON i.object_id = v.object_id AND i.index_id = 1
                              WHERE v.schema_id = SCHEMA_ID(N'Resumen'));
    PRINT CONCAT('Vistas indexadas en Resumen: ', @indexadas, ' (mas vVentasMes y vComprasMes con NOEXPAND)');
END
GO
