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
    IF OBJECT_ID(N''Sales.CustomersSensible'') IS NOT NULL
        EXEC (N''DECLARE @c int = (SELECT COUNT(*) FROM Sales.CustomersSensible), @p int = (SELECT COUNT(*) FROM Purchasing.SuppliersSensible), @g int = (SELECT COUNT(*) FROM Application.PeopleSensible);
              PRINT CONCAT(''''  Sensibles : '''', @c, '''' clientes, '''', @p, '''' proveedores, '''', @g, '''' personas (fragmento sensible)'''');'');
    ELSE
        PRINT CONCAT(''  Sensibles : '', CASE WHEN @sens = 0 THEN N''ninguna columna sensible'' ELSE CONCAT(@sens, N'' columnas sensibles'') END);
    IF OBJECT_ID(N''Seguridad.Usuarios'') IS NOT NULL
        EXEC (N''DECLARE @u int = (SELECT COUNT(*) FROM Seguridad.Usuarios);
              PRINT CONCAT(''''  Usuarios  : '''', @u, '''' (llave de contrasenas: '''', CASE WHEN KEY_ID(N''''LlaveUsuarios'''') IS NULL THEN N''''no'''' ELSE N''''si'''' END, '''')'''');'');');

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
