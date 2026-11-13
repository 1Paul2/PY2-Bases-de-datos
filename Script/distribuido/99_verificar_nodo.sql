SET NOCOUNT ON;

DECLARE @agente nvarchar(60) = (SELECT TOP 1 status_desc FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%');
DECLARE @version nvarchar(20) = CASE CAST(SERVERPROPERTY('ProductMajorVersion') AS int)
    WHEN 15 THEN N'2019' WHEN 16 THEN N'2022' WHEN 17 THEN N'2025' ELSE N'?' END;

PRINT CONCAT('  Motor     : SQL Server ', @version, ' (', CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(20)), ', ', CAST(SERVERPROPERTY('Edition') AS nvarchar(60)), ')');
PRINT CONCAT('  Agent     : ', ISNULL(@agente, N'?'));
PRINT CONCAT('  Hora      : ', CONVERT(nvarchar(19), SYSDATETIME(), 120));
DECLARE @bases nvarchar(max) = (SELECT STRING_AGG(name, N', ') FROM sys.databases WHERE database_id > 4);
PRINT CONCAT('  Bases     : ', @bases);
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = N'repl_distributor')
    EXEC (N'DECLARE @dmk nvarchar(2) = CASE WHEN EXISTS (SELECT 1 FROM distribution.sys.symmetric_keys WHERE name = N''##MS_DatabaseMasterKey##'') THEN N''si'' ELSE N''no'' END;
        PRINT CONCAT(''  Distrib.  : si (master key en distribution: '', @dmk, '')'');');

DECLARE @base sysname = (SELECT TOP 1 name FROM sys.databases WHERE name LIKE N'WWI[_]%');
IF @base IS NOT NULL
    EXEC (N'USE ' + @base + N';
    DECLARE @fact int = (SELECT COUNT(*) FROM Sales.Invoices),
            @ped int = (SELECT COUNT(*) FROM Sales.Orders),
            @oc int = (SELECT COUNT(*) FROM Purchasing.PurchaseOrders),
            @exist bigint = (SELECT SUM(CAST(QuantityOnHand AS bigint)) FROM Warehouse.StockItemHoldings),
            @sens int = (SELECT COUNT(*) FROM sys.columns
                         WHERE object_id IN (OBJECT_ID(N''Sales.Customers''), OBJECT_ID(N''Purchasing.Suppliers''), OBJECT_ID(N''Application.People''))
                           AND name IN (N''PhoneNumber'', N''EmailAddress'', N''BankAccountNumber'', N''DeliveryAddressLine1'', N''DeliveryLocation''));
    PRINT CONCAT(''  Datos     : '', @fact, '' facturas, '', @ped, '' pedidos, '', @oc, '' ordenes de compra, existencias '', ISNULL(@exist, 0));
    IF OBJECT_ID(N''dbo.VendedorSucursal'') IS NOT NULL AND OBJECT_ID(N''Sales.CustomersSensible'') IS NULL
        EXEC (N''DECLARE @n int, @f int, @v nvarchar(400);
              SELECT @n = COUNT(*), @f = SUM(Facturas), @v = STRING_AGG(CAST(PersonID AS varchar(10)), '''', '''') WITHIN GROUP (ORDER BY PersonID)
              FROM dbo.VendedorSucursal WHERE Sucursal = CASE DB_NAME() WHEN N''''WWI_SanJose'''' THEN ''''SJ'''' ELSE ''''LI'''' END;
              PRINT CONCAT(''''  Vendedores: '''', @n, '''' ('''', @v, ''''), '''', @f, '''' facturas al repartir'''');'');
    IF OBJECT_ID(N''Sales.CustomersSensible'') IS NOT NULL
        EXEC (N''DECLARE @c int = (SELECT COUNT(*) FROM Sales.CustomersSensible), @p int = (SELECT COUNT(*) FROM Purchasing.SuppliersSensible), @g int = (SELECT COUNT(*) FROM Application.PeopleSensible);
              PRINT CONCAT(''''  Sensibles : '''', @c, '''' clientes, '''', @p, '''' proveedores, '''', @g, '''' personas (fragmento sensible)'''');'');
    ELSE
        PRINT CONCAT(''  Sensibles : '', CASE WHEN @sens = 0 THEN N''ninguna columna sensible'' ELSE CONCAT(@sens, N'' columnas sensibles'') END);
    IF OBJECT_ID(N''Seguridad.Usuarios'') IS NOT NULL
        EXEC (N''DECLARE @u int = (SELECT COUNT(*) FROM Seguridad.Usuarios);
              PRINT CONCAT(''''  Usuarios  : '''', @u, '''' (llave de contrasenas: '''', CASE WHEN KEY_ID(N''''LlaveUsuarios'''') IS NULL THEN N''''no'''' ELSE N''''si'''' END, '''')'''');'');');

IF @base IS NOT NULL
    EXEC (N'USE ' + @base + N';
    DECLARE @r nvarchar(max);
    IF OBJECT_ID(N''dbo.sysmergepublications'') IS NOT NULL AND OBJECT_ID(N''Sales.CustomersSensible'') IS NOT NULL
    BEGIN
        EXEC sp_executesql N''SELECT @r = STRING_AGG(CAST(t AS nvarchar(max)), N'''', '''') FROM (
            SELECT p.name + N'''' (merge, '''' + CAST(COUNT(s.subid) AS nvarchar(10)) + N'''' suscripciones)'''' t
            FROM dbo.sysmergepublications p
            LEFT JOIN dbo.sysmergesubscriptions s ON s.pubid = p.pubid AND s.subscriber_server <> @@SERVERNAME AND s.status = 1
            GROUP BY p.name
            UNION ALL
            SELECT p.name + N'''' (transaccional, '''' + CAST(COUNT(DISTINCT s.srvname) AS nvarchar(10)) + N'''' suscripciones)''''
            FROM dbo.syspublications p
            LEFT JOIN dbo.sysarticles a ON a.pubid = p.pubid
            LEFT JOIN dbo.syssubscriptions s ON s.artid = a.artid AND s.status = 2 AND s.srvid >= 0
            GROUP BY p.name) x;'', N''@r nvarchar(max) OUTPUT'', @r OUTPUT;
        PRINT CONCAT(''  Publica   : '', ISNULL(@r, N''ninguna''));
    END
    ELSE IF OBJECT_ID(N''Sales.CustomersSensible'') IS NULL
    BEGIN
        DECLARE @merge int = (SELECT COUNT(*) FROM sys.triggers WHERE parent_id = OBJECT_ID(N''Warehouse.StockItems'') AND name LIKE N''MSmerge%'');
        DECLARE @tran int = 0;
        IF OBJECT_ID(N''dbo.MSreplication_subscriptions'') IS NOT NULL
            EXEC sp_executesql N''SELECT @n = COUNT(*) FROM dbo.MSreplication_subscriptions;'', N''@n int OUTPUT'', @tran OUTPUT;
        PRINT CONCAT(''  Recibe    : catalogo por merge '', CASE WHEN @merge > 0 THEN N''(activo)'' ELSE N''(sin suscribir)'' END,
                     '', '', @tran, '' publicaciones transaccionales'');
    END');

IF @base IS NOT NULL
    EXEC (N'USE ' + @base + N';
    IF SCHEMA_ID(N''Resumen'') IS NOT NULL
    BEGIN
        DECLARE @tablas int = (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N''Resumen''));
        DECLARE @vistas int = (SELECT COUNT(*) FROM sys.views WHERE schema_id = SCHEMA_ID(N''Resumen''));
        DECLARE @sj bigint = (SELECT SUM(rows) FROM sys.partitions WHERE object_id = OBJECT_ID(N''Resumen.Facturas_SJ'') AND index_id IN (0, 1));
        DECLARE @li bigint = (SELECT SUM(rows) FROM sys.partitions WHERE object_id = OBJECT_ID(N''Resumen.Facturas_LI'') AND index_id IN (0, 1));
        PRINT CONCAT(''  Resumen   : '', @tablas, '' tablas, '', @vistas, '' vistas, facturas SJ '', ISNULL(@sj, 0), '' / LI '', ISNULL(@li, 0));
    END
    IF OBJECT_ID(N''Sales.CustomersSensible'') IS NULL AND OBJECT_ID(N''dbo.syspublications'') IS NOT NULL
    BEGIN
        DECLARE @pubs nvarchar(max);
        EXEC sp_executesql N''SELECT @p = STRING_AGG(name, N'''', '''') FROM dbo.syspublications;'', N''@p nvarchar(max) OUTPUT'', @pubs OUTPUT;
        PRINT CONCAT(''  Publica   : '', ISNULL(@pubs, N''ninguna''), '' (hacia el corporativo)'');
    END
    DECLARE @app nvarchar(max) = (
        SELECT STRING_AGG(CONCAT(x.usuario, N'' ('', x.rol, N'', '', x.permisos, N'' permisos)''), N'', '')
        FROM (SELECT u.name AS usuario, r.name AS rol,
                     (SELECT COUNT(*) FROM sys.database_permissions p WHERE p.grantee_principal_id = r.principal_id) AS permisos
              FROM sys.database_role_members m
              JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
              JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
              WHERE r.name LIKE N''rol[_]%'') x);
    PRINT CONCAT(''  App       : '', ISNULL(@app, N''sin usuarios de la aplicacion''));');

DECLARE @ls sysname, @inicio datetime2, @ms int;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.servers WHERE is_linked = 1 AND name LIKE N'LS[_]%' ORDER BY name;
OPEN c;
FETCH NEXT FROM c INTO @ls;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @inicio = SYSDATETIME();
    BEGIN TRY
        EXEC sp_testlinkedserver @ls;
        SET @ms = DATEDIFF(millisecond, @inicio, SYSDATETIME());
        PRINT CONCAT('  ', @ls, REPLICATE(N' ', 15 - LEN(@ls)), ': responde (', @ms, ' ms)');
    END TRY
    BEGIN CATCH
        SET @ms = DATEDIFF(millisecond, @inicio, SYSDATETIME());
        PRINT CONCAT('  ', @ls, REPLICATE(N' ', 15 - LEN(@ls)), ': NO RESPONDE tras ', @ms, ' ms');
    END CATCH
    FETCH NEXT FROM c INTO @ls;
END
CLOSE c;
DEALLOCATE c;
