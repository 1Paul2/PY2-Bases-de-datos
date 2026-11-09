SET NOCOUNT ON;
USE [$(BASE)];
GO

-- CORPORATIVO: registrar las sucursales como publicadores en el distribuidor
IF N'$(NODO)' = N'corporativo'
BEGIN
    DECLARE @sucursal sysname;
    -- Define la lista que se va a recorrer.
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT s FROM (VALUES (N'sanjose'), (N'limon')) v(s);
    OPEN c;
    -- Lee la c para poder copia el nombre de la variable @sucursal
    FETCH NEXT FROM c INTO @sucursal;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM msdb.dbo.MSdistpublishers WHERE name = @sucursal)
        BEGIN
            EXEC sp_adddistpublisher
                @publisher = @sucursal,
                @distribution_db = N'distribution',
                @working_directory = N'/var/opt/mssql/repldata',
                -- El numero de acceso para la sucursal
                @security_mode = 0,
                @login = N'sa',
                @password = N'$(SA_PASSWORD)';
            PRINT CONCAT(@sucursal, ' registrado como publicador');
        END
        ELSE
            PRINT CONCAT(@sucursal, ' ya estaba registrado como publicador');
        -- Pasamos a la siguiente sucursal
        FETCH NEXT FROM c INTO @sucursal;
    END
    CLOSE c;
    DEALLOCATE c;

    -- Esquema donde llegan las ventas y compras replicadas de las sucursales
    IF SCHEMA_ID(N'Resumen') IS NULL
        EXEC (N'CREATE SCHEMA Resumen');
END
GO

-- Si esta es diferente a corporativo
IF N'$(NODO)' <> N'corporativo'
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = N'repl_distributor')
        BEGIN
            EXEC (N'USE master; EXEC sp_adddistributor @distributor = N''corporativo'', @password = N''$(SA_PASSWORD)'';');
            PRINT 'Distribuidor creado';
        END
    ELSE
        PRINT 'La sucursal ya tenía distribuidor configurado';
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = DB_NAME() AND is_published = 1)
        BEGIN
            EXEC sp_replicationdboption @dbname = N'$(BASE)', @optname = N'publish', @value = N'true';
                PRINT 'Base habilitada para publicar';
        END
    ELSE
        PRINT 'La base ya estaba habilitada para publicar';

END
GO

IF N'$(NODO)' <> N'corporativo'
BEGIN
    BEGIN TRY
        DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)';
        EXEC sp_addlogreader_agent @publisher_security_mode = 0, @publisher_login = N'wwi_replicacion', @publisher_password = @clave;
        PRINT 'Agente lector del log creado';
    END TRY
    BEGIN CATCH
        PRINT 'El agente ya existe';
    END CATCH
END
GO

-- PASO 6: crea la publicación de la sucursal (PubVentasSJ / PubVentasLI)
IF N'$(NODO)' <> N'corporativo'
BEGIN
    DECLARE @pub sysname = CASE N'$(NODO)' WHEN N'sanjose' THEN N'PubVentasSJ' ELSE N'PubVentasLI' END;

    IF NOT EXISTS (SELECT 1 FROM dbo.syspublications WHERE name = @pub)
    BEGIN
        EXEC sp_addpublication @publication = @pub,
            @description = N'Ventas, compras y movimientos de la sucursal hacia el corporativo',
            @status = N'active', @repl_freq = N'continuous', @independent_agent = N'true',
            @immediate_sync = N'false', @allow_push = N'true', @allow_pull = N'false';
        EXEC sp_grant_publication_access @publication = @pub, @login = N'wwi_replicacion';
        PRINT CONCAT('Publicacion ', @pub, ' creada');
    END
    ELSE
        PRINT CONCAT('La publicacion ', @pub, ' ya existia');
END
GO

-- PASO 7: agrega las 5 tablas a la publicación; llegan al corporativo como Resumen.<Tabla>_SJ / _LI
-- y solo con las columnas que usan las estadísticas
IF N'$(NODO)' <> N'corporativo'
BEGIN
    DECLARE @pub sysname = CASE N'$(NODO)' WHEN N'sanjose' THEN N'PubVentasSJ' ELSE N'PubVentasLI' END;
    DECLARE @sufijo nvarchar(3) = CASE N'$(NODO)' WHEN N'sanjose' THEN N'_SJ' ELSE N'_LI' END;
    DECLARE @articulo sysname, @esquema sysname, @tabla sysname, @columnas nvarchar(max),
            @destino sysname, @ins nvarchar(255), @upd nvarchar(255), @del nvarchar(255),
            @columna sysname, @operacion nvarchar(4);

    -- Nombre en el corporativo, tabla de origen y columnas que viajan
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT a, e, t, cols FROM (VALUES
            (N'Facturas',      N'Sales',      N'Invoices',
             N'InvoiceID,CustomerID,SalespersonPersonID,DeliveryMethodID,InvoiceDate'),
            (N'LineasFactura', N'Sales',      N'InvoiceLines',
             N'InvoiceLineID,InvoiceID,StockItemID,Quantity,ExtendedPrice,LineProfit'),
            (N'Compras',       N'Purchasing', N'PurchaseOrders',
             N'PurchaseOrderID,SupplierID,OrderDate'),
            (N'LineasCompra',  N'Purchasing', N'PurchaseOrderLines',
             N'PurchaseOrderLineID,PurchaseOrderID,StockItemID,OrderedOuters,ExpectedUnitPricePerOuter'),
            (N'Movimientos',   N'Warehouse',  N'StockItemTransactions',
             N'StockItemTransactionID,StockItemID,TransactionTypeID,CustomerID,InvoiceID,SupplierID,PurchaseOrderID,TransactionOccurredWhen,Quantity')
        ) v(a, e, t, cols);
    OPEN c;
    FETCH NEXT FROM c INTO @articulo, @esquema, @tabla, @columnas;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.sysarticles a JOIN dbo.syspublications p ON p.pubid = a.pubid
                       WHERE p.name = @pub AND a.name = @articulo)
        BEGIN
            -- Nombres propios para que los procedimientos de SJ y LI no choquen en el corporativo
            SET @destino = @articulo + @sufijo;
            SET @ins = N'CALL sp_MSins_Resumen' + @destino;
            SET @upd = N'SCALL sp_MSupd_Resumen' + @destino;
            SET @del = N'CALL sp_MSdel_Resumen' + @destino;

            EXEC sp_addarticle @publication = @pub, @article = @articulo,
                @source_owner = @esquema, @source_object = @tabla,
                @destination_owner = N'Resumen', @destination_table = @destino,
                @vertical_partition = N'true', @pre_creation_cmd = N'none',
                @ins_cmd = @ins, @upd_cmd = @upd, @del_cmd = @del;

            -- Las columnas de la lista se agregan; las demás se quitan
            DECLARE cc CURSOR LOCAL FAST_FORWARD FOR
                SELECT name FROM sys.columns WHERE object_id = OBJECT_ID(@esquema + N'.' + @tabla);
            OPEN cc;
            FETCH NEXT FROM cc INTO @columna;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @operacion = CASE WHEN @columna IN (SELECT value FROM STRING_SPLIT(@columnas, N','))
                                      THEN N'add' ELSE N'drop' END;
                EXEC sp_articlecolumn @publication = @pub, @article = @articulo,
                    @column = @columna, @operation = @operacion;
                FETCH NEXT FROM cc INTO @columna;
            END
            CLOSE cc;
            DEALLOCATE cc;

            PRINT CONCAT('Articulo ', @esquema, '.', @tabla, ' -> Resumen.', @destino);
        END
        ELSE
            PRINT CONCAT('El articulo ', @articulo, ' ya estaba en ', @pub);

        FETCH NEXT FROM c INTO @articulo, @esquema, @tabla, @columnas;
    END
    CLOSE c;
    DEALLOCATE c;
END
GO

-- PASO 8: suscribe al corporativo a la publicación; sin snapshot, porque las tablas Resumen.* ya existen allá
IF N'$(NODO)' <> N'corporativo'
BEGIN
    DECLARE @pub sysname = CASE N'$(NODO)' WHEN N'sanjose' THEN N'PubVentasSJ' ELSE N'PubVentasLI' END;
    DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)';

    IF NOT EXISTS (SELECT 1 FROM dbo.syssubscriptions s
                   JOIN dbo.sysarticles a ON a.artid = s.artid
                   JOIN dbo.syspublications p ON p.pubid = a.pubid
                   WHERE p.name = @pub AND s.srvname = N'corporativo')
    BEGIN
        EXEC sp_addsubscription @publication = @pub, @subscriber = N'corporativo',
            @destination_db = N'WWI_Corporativo', @subscription_type = N'Push',
            @sync_type = N'replication support only';
        EXEC sp_addpushsubscription_agent @publication = @pub, @subscriber = N'corporativo',
            @subscriber_db = N'WWI_Corporativo',
            @subscriber_security_mode = 0, @subscriber_login = N'wwi_replicacion', @subscriber_password = @clave,
            @frequency_type = 64;
        PRINT CONCAT('Suscripcion del corporativo a ', @pub, ' creada');
    END
    ELSE
        PRINT CONCAT('El corporativo ya estaba suscrito a ', @pub);
END
GO

