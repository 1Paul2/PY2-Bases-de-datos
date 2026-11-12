SET NOCOUNT ON;

DECLARE @nodo sysname = N'$(NODO)';
DECLARE @base sysname = N'$(BASE)';
DECLARE @clave nvarchar(128) = N'$(APP_PASSWORD)';
DECLARE @app sysname = CASE @nodo
    WHEN N'corporativo' THEN N'app_corporativo'
    WHEN N'sanjose' THEN N'app_admin_sj'
    WHEN N'limon' THEN N'app_admin_li' END;
DECLARE @login sysname, @sql nvarchar(max);

IF @app IS NULL
    THROW 50100, 'NODO debe ser corporativo, sanjose o limon.', 1;

DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT @app UNION ALL SELECT N'app_login';
OPEN c;
FETCH NEXT FROM c INTO @login;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @login)
        SET @sql = N'CREATE LOGIN ' + QUOTENAME(@login) + N' WITH PASSWORD = ' + QUOTENAME(@clave, '''') +
                   N', DEFAULT_DATABASE = ' + QUOTENAME(@base) + N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
    ELSE
        SET @sql = N'ALTER LOGIN ' + QUOTENAME(@login) + N' WITH PASSWORD = ' + QUOTENAME(@clave, '''') +
                   N', DEFAULT_DATABASE = ' + QUOTENAME(@base) + N';';
    EXEC (@sql);
    FETCH NEXT FROM c INTO @login;
END
CLOSE c;
DEALLOCATE c;
GO

USE [$(BASE)];
GO

DECLARE @nodo sysname = N'$(NODO)';
DECLARE @app sysname = CASE @nodo
    WHEN N'corporativo' THEN N'app_corporativo'
    WHEN N'sanjose' THEN N'app_admin_sj'
    ELSE N'app_admin_li' END;
DECLARE @rol sysname = CASE @nodo WHEN N'corporativo' THEN N'rol_corporativo' ELSE N'rol_administrador' END;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'rol_login' AND type = 'R')
    EXEC (N'CREATE ROLE rol_login;');
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @rol AND type = 'R')
    EXEC (N'CREATE ROLE ' + @rol + N';');

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'app_login')
    EXEC (N'CREATE USER app_login FOR LOGIN app_login;');
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @app)
    EXEC (N'CREATE USER ' + @app + N' FOR LOGIN ' + @app + N';');

EXEC (N'ALTER ROLE rol_login ADD MEMBER app_login;');
EXEC (N'ALTER ROLE ' + @rol + N' ADD MEMBER ' + @app + N';');

DECLARE @permisos TABLE (Rol sysname, Permiso nvarchar(20), Objeto nvarchar(256));

INSERT INTO @permisos (Rol, Permiso, Objeto)
SELECT N'rol_login', N'EXECUTE', N'Seguridad.SP_IniciarSesion';

INSERT INTO @permisos (Rol, Permiso, Objeto)
SELECT r.Rol, N'EXECUTE', N'dbo.' + p.Nombre
FROM (VALUES (N'rol_administrador'), (N'rol_corporativo')) r (Rol)
CROSS JOIN (VALUES
    (N'SP_GetCustomerCategories'), (N'SP_GetBuyingGroups'), (N'SP_GetDeliveryMethods'), (N'SP_GetColors'),
    (N'SP_GetPackageTypes'), (N'SP_GetSuppliersCatalog'), (N'SP_GetStockGroups'), (N'SP_GetSupplierCategories'),
    (N'SP_SearchCities'), (N'SP_SearchPeople'), (N'SP_SearchCustomers'), (N'SP_SearchStockItems'),
    (N'SP_GetYears'), (N'SP_GetMonths'), (N'SP_GetCustomerCategoriesInUse'), (N'SP_GetSupplierCategoriesInUse'),
    (N'SP_GetDeliveryMethodsInUse'), (N'SP_GetStockGroupsInUse')) p (Nombre);

INSERT INTO @permisos (Rol, Permiso, Objeto)
SELECT r.Rol, N'EXECUTE', N'dbo.' + p.Nombre
FROM (VALUES (N'rol_administrador'), (N'rol_corporativo')) r (Rol)
CROSS JOIN (VALUES
    (N'SP_CLIENTES'), (N'SP_LISTA_CLIENTES'), (N'SP_GetSuppliers'), (N'SP_GetSupplierDetails'),
    (N'SP_GetStockItems'), (N'SP_GetStockItemDetails')) p (Nombre);

INSERT INTO @permisos (Rol, Permiso, Objeto)
SELECT N'rol_administrador', N'EXECUTE', N'dbo.' + Nombre
FROM (VALUES
    (N'SP_InsertStockItem'), (N'SP_UpdateStockItem'), (N'SP_DeleteStockItem'),
    (N'SP_GetSales'), (N'SP_GetSalesCount'), (N'SP_GetSaleHeader'), (N'SP_GetSaleDetails'), (N'SP_InsertSale')) p (Nombre);

INSERT INTO @permisos (Rol, Permiso, Objeto)
SELECT N'rol_corporativo', N'EXECUTE', N'dbo.' + Nombre
FROM (VALUES
    (N'SP_InsertCustomer'), (N'SP_UpdateCustomer'), (N'SP_DeleteCustomer'),
    (N'SP_InsertSupplier'), (N'SP_UpdateSupplier'), (N'SP_DeleteSupplier'),
    (N'sp_estadistica_proveedor'), (N'sp_estadistica_cliente'), (N'sp_top5_productos_ganancia'),
    (N'sp_top5_clientes_facturas'), (N'sp_top5_proveedores_ordenes'), (N'sp_matriz_ventas_categoria_anio'),
    (N'sp_seguimiento_compras_cliente'), (N'sp_seguimiento_compras_proveedor'), (N'sp_rotacion_inventario'),
    (N'sp_metodo_envio_favorito')) p (Nombre);

INSERT INTO @permisos (Rol, Permiso, Objeto)
SELECT N'rol_administrador', N'SELECT', Nombre
FROM (VALUES (N'Sales.InvoiceLines'), (N'Sales.OrderLines'), (N'Purchasing.PurchaseOrderLines'),
             (N'Warehouse.StockItemTransactions')) p (Nombre);

INSERT INTO @permisos (Rol, Permiso, Objeto)
SELECT N'rol_corporativo', N'SELECT', Nombre
FROM (VALUES (N'dbo.Syn_Invoices'), (N'dbo.Syn_InvoiceLines'), (N'dbo.Syn_StockItemStockGroups'), (N'dbo.Syn_StockGroups')) p (Nombre);

INSERT INTO @permisos (Rol, Permiso, Objeto)
SELECT N'rol_corporativo', N'VIEW DEFINITION', Nombre
FROM (VALUES (N'Sales.CustomersSensible'), (N'Purchasing.SuppliersSensible')) p (Nombre);

DECLARE @r sysname, @permiso nvarchar(20), @objeto nvarchar(256), @dados int = 0, @faltan int = 0;

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT pr.name, pe.permission_name, QUOTENAME(OBJECT_SCHEMA_NAME(pe.major_id)) + N'.' + QUOTENAME(OBJECT_NAME(pe.major_id))
    FROM sys.database_permissions pe
    JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
    WHERE pr.name IN (N'rol_login', @rol) AND pe.class = 1;
OPEN c;
FETCH NEXT FROM c INTO @r, @permiso, @objeto;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC (N'REVOKE ' + @permiso + N' ON ' + @objeto + N' FROM ' + @r + N';');
    FETCH NEXT FROM c INTO @r, @permiso, @objeto;
END
CLOSE c;
DEALLOCATE c;

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT Rol, Permiso, Objeto FROM @permisos WHERE Rol IN (N'rol_login', @rol);
OPEN c;
FETCH NEXT FROM c INTO @r, @permiso, @objeto;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID(@objeto) IS NOT NULL
    BEGIN
        EXEC (N'GRANT ' + @permiso + N' ON ' + @objeto + N' TO ' + @r + N';');
        SET @dados += 1;
    END
    ELSE IF @permiso = N'EXECUTE'
        SET @faltan += 1;
    FETCH NEXT FROM c INTO @r, @permiso, @objeto;
END
CLOSE c;
DEALLOCATE c;

PRINT CONCAT('Usuarios ', @app, ' (', @rol, ') y app_login (rol_login): ', @dados, ' permisos');
IF @faltan > 0
    PRINT CONCAT('Faltan ', @faltan, ' procedimientos por instalar; volver a correr levantar para darles permiso');
GO
