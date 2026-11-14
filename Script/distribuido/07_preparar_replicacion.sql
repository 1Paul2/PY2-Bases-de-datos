SET NOCOUNT ON;
USE [$(BASE)];
GO

DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)';
DECLARE @sql nvarchar(max);
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'wwi_replicacion')
    SET @sql = N'CREATE LOGIN wwi_replicacion WITH PASSWORD = ' + QUOTENAME(@clave, '''') +
               N', DEFAULT_DATABASE = [$(BASE)], CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
ELSE
    SET @sql = N'ALTER LOGIN wwi_replicacion WITH PASSWORD = ' + QUOTENAME(@clave, '''') + N';';
EXEC (@sql);

IF CAST(SERVERPROPERTY('ProductMajorVersion') AS int) >= 16
    EXEC (N'USE master; GRANT VIEW SERVER PERFORMANCE STATE TO wwi_replicacion;');
ELSE
    EXEC (N'USE master; GRANT VIEW SERVER STATE TO wwi_replicacion;');

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'wwi_replicacion')
    CREATE USER wwi_replicacion FOR LOGIN wwi_replicacion;
ALTER ROLE db_owner ADD MEMBER wwi_replicacion;

IF DB_ID(N'distribution') IS NOT NULL
    EXEC (N'USE distribution;
        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''wwi_replicacion'')
            CREATE USER wwi_replicacion FOR LOGIN wwi_replicacion;
        ALTER ROLE db_owner ADD MEMBER wwi_replicacion;');
PRINT 'Login wwi_replicacion listo';
GO

IF EXISTS (SELECT 1 FROM dbo.ControlFragmentacion WHERE Paso = N'preparar_replicacion')
BEGIN
    PRINT 'Preparacion de la replicacion ya aplicada';
    SET NOEXEC ON;
END
GO

DECLARE @tabla nvarchar(256), @sql nvarchar(max);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT t FROM (VALUES (N'Warehouse.StockItems'), (N'Warehouse.StockGroups'), (N'Warehouse.Colors'), (N'Warehouse.PackageTypes'),
                          (N'Sales.Customers'), (N'Purchasing.Suppliers'), (N'Application.People')) v(t);
OPEN c;
FETCH NEXT FROM c INTO @tabla;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECTPROPERTY(OBJECT_ID(@tabla), 'TableTemporalType') = 2
        EXEC (N'ALTER TABLE ' + @tabla + N' SET (SYSTEM_VERSIONING = OFF);
                ALTER TABLE ' + @tabla + N' DROP PERIOD FOR SYSTEM_TIME;');

    SET @sql = N'';
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID(@tabla)
                   AND parent_column_id = COLUMNPROPERTY(OBJECT_ID(@tabla), N'ValidFrom', 'ColumnId'))
        SET @sql += N'ALTER TABLE ' + @tabla + N' ADD DEFAULT SYSUTCDATETIME() FOR ValidFrom;';
    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID(@tabla)
                   AND parent_column_id = COLUMNPROPERTY(OBJECT_ID(@tabla), N'ValidTo', 'ColumnId'))
        SET @sql += N'ALTER TABLE ' + @tabla + N' ADD DEFAULT CONVERT(datetime2(7), ''9999-12-31 23:59:59.9999999'') FOR ValidTo;';
    EXEC (@sql);

    FETCH NEXT FROM c INTO @tabla;
END
CLOSE c;
DEALLOCATE c;
PRINT 'Historial desactivado en las 7 tablas replicadas';
GO

IF COL_LENGTH(N'Warehouse.StockItems', N'LastEditedWhen') IS NULL
BEGIN
    ALTER TABLE Warehouse.StockItems ADD LastEditedWhen datetime2(7) NOT NULL
        CONSTRAINT DF_Warehouse_StockItems_LastEditedWhen DEFAULT SYSDATETIME();
    EXEC (N'UPDATE Warehouse.StockItems SET LastEditedWhen = ValidFrom;');
END
GO

DECLARE @tabla nvarchar(256), @llave sysname, @sql nvarchar(max);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT t, k FROM (VALUES (N'Warehouse.Colors', N'ColorID'), (N'Warehouse.PackageTypes', N'PackageTypeID'),
                             (N'Warehouse.StockGroups', N'StockGroupID'), (N'Warehouse.StockItems', N'StockItemID'),
                             (N'Warehouse.StockItemStockGroups', N'StockItemStockGroupID')) v(t, k);
OPEN c;
FETCH NEXT FROM c INTO @tabla, @llave;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(@tabla) AND is_rowguidcol = 1)
    BEGIN
        EXEC (N'ALTER TABLE ' + @tabla + N' ADD rowguid uniqueidentifier ROWGUIDCOL NOT NULL DEFAULT NEWSEQUENTIALID();');
        IF N'$(NODO)' <> N'corporativo'
            EXEC (N'UPDATE s SET rowguid = c.rowguid
                    FROM ' + @tabla + N' s
                    JOIN LS_CORPORATIVO.WWI_Corporativo.' + @tabla + N' c ON c.' + @llave + N' = s.' + @llave + N';');
    END
    FETCH NEXT FROM c INTO @tabla, @llave;
END
CLOSE c;
DEALLOCATE c;
PRINT 'Columnas rowguid listas';
GO

INSERT INTO dbo.ControlFragmentacion (Paso) VALUES (N'preparar_replicacion');
PRINT 'Preparacion de la replicacion aplicada';
GO

SET NOEXEC OFF;
GO
