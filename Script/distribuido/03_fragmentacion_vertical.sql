SET NOCOUNT ON;
USE [$(BASE)];
GO

IF OBJECT_ID(N'dbo.ControlFragmentacion') IS NULL
    CREATE TABLE dbo.ControlFragmentacion (
        Paso nvarchar(50) NOT NULL PRIMARY KEY,
        AplicadoEn datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
GO

IF EXISTS (SELECT 1 FROM dbo.ControlFragmentacion WHERE Paso = N'vertical')
BEGIN
    PRINT 'Fragmentacion vertical ya aplicada';
    SET NOEXEC ON;
END
GO

CREATE OR ALTER PROCEDURE dbo.Frag_EliminarColumna @tabla nvarchar(256), @columna sysname
AS
BEGIN
    DECLARE @obj int = OBJECT_ID(@tabla);
    DECLARE @col int = COLUMNPROPERTY(@obj, @columna, 'ColumnId');
    DECLARE @sql nvarchar(max) = N'';
    IF @col IS NULL RETURN;

    SELECT @sql += N'ALTER TABLE ' + @tabla + N' DROP COLUMN ' + QUOTENAME(cc.name) + N';'
    FROM sys.computed_columns cc
    JOIN sys.sql_expression_dependencies d ON d.referencing_id = cc.object_id AND d.referencing_minor_id = cc.column_id
    WHERE cc.object_id = @obj AND d.referenced_minor_id = @col;

    SELECT @sql += N'ALTER TABLE ' + @tabla + N' DROP CONSTRAINT ' + QUOTENAME(name) + N';'
    FROM sys.default_constraints WHERE parent_object_id = @obj AND parent_column_id = @col;

    SELECT @sql += N'ALTER TABLE ' + @tabla + N' DROP CONSTRAINT ' + QUOTENAME(name) + N';'
    FROM sys.check_constraints
    WHERE parent_object_id = @obj AND (parent_column_id = @col OR definition LIKE N'%' + QUOTENAME(@columna) + N'%');

    SELECT @sql += N'ALTER TABLE ' + @tabla + N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
    FROM sys.foreign_keys fk
    WHERE fk.parent_object_id = @obj
      AND EXISTS (SELECT 1 FROM sys.foreign_key_columns fc WHERE fc.constraint_object_id = fk.object_id AND fc.parent_column_id = @col);

    SELECT @sql += CASE WHEN i.is_unique_constraint = 1
                        THEN N'ALTER TABLE ' + @tabla + N' DROP CONSTRAINT ' + QUOTENAME(i.name) + N';'
                        ELSE N'DROP INDEX ' + QUOTENAME(i.name) + N' ON ' + @tabla + N';' END
    FROM sys.indexes i
    WHERE i.object_id = @obj AND i.is_primary_key = 0 AND i.name IS NOT NULL
      AND EXISTS (SELECT 1 FROM sys.index_columns ic WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.column_id = @col);

    SELECT @sql += N'DROP STATISTICS ' + @tabla + N'.' + QUOTENAME(s.name) + N';'
    FROM sys.stats s
    WHERE s.object_id = @obj AND s.user_created = 1
      AND EXISTS (SELECT 1 FROM sys.stats_columns sc WHERE sc.object_id = s.object_id AND sc.stats_id = s.stats_id AND sc.column_id = @col);

    SET @sql += N'ALTER TABLE ' + @tabla + N' DROP COLUMN ' + QUOTENAME(@columna) + N';';
    EXEC (@sql);
END
GO

CREATE OR ALTER PROCEDURE dbo.Frag_CopiarDefaults @origen nvarchar(256), @destino nvarchar(256)
AS
BEGIN
    DECLARE @sql nvarchar(max) = N'';
    SELECT @sql += N'ALTER TABLE ' + @destino + N' ADD DEFAULT ' + dc.definition + N' FOR ' + QUOTENAME(c.name) + N';'
    FROM sys.default_constraints dc
    JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = OBJECT_ID(@origen)
      AND dc.definition NOT LIKE N'%NEXT VALUE FOR%'
      AND COLUMNPROPERTY(OBJECT_ID(@destino), c.name, 'ColumnId') IS NOT NULL;
    EXEC (@sql);
END
GO

CREATE OR ALTER PROCEDURE dbo.Frag_QuitarSensibles @tabla nvarchar(256), @historial nvarchar(256), @columnas nvarchar(max)
AS
BEGIN
    DECLARE @c sysname;
    EXEC (N'ALTER TABLE ' + @tabla + N' SET (SYSTEM_VERSIONING = OFF);');

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT TRIM(NCHAR(13) + NCHAR(10) + NCHAR(9) + N' ' FROM value) FROM STRING_SPLIT(@columnas, N',');
    OPEN cur;
    FETCH NEXT FROM cur INTO @c;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.Frag_EliminarColumna @tabla, @c;
        EXEC dbo.Frag_EliminarColumna @historial, @c;
        FETCH NEXT FROM cur INTO @c;
    END
    CLOSE cur;
    DEALLOCATE cur;

    EXEC (N'ALTER TABLE ' + @tabla + N' SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = ' + @historial + N', DATA_CONSISTENCY_CHECK = ON));');
END
GO

IF N'$(NODO)' = N'corporativo' AND OBJECT_ID(N'Sales.CustomersSensible') IS NULL
    EXEC (N'
    SELECT CustomerID, PrimaryContactPersonID, AlternateContactPersonID, PhoneNumber, FaxNumber, WebsiteURL,
           DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation,
           PostalAddressLine1, PostalAddressLine2, PostalPostalCode
    INTO Sales.CustomersSensible
    FROM Sales.Customers;

    SELECT SupplierID, PrimaryContactPersonID, AlternateContactPersonID, BankAccountName, BankAccountBranch,
           BankAccountCode, BankAccountNumber, BankInternationalCode, PhoneNumber, FaxNumber, WebsiteURL,
           DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation,
           PostalAddressLine1, PostalAddressLine2, PostalPostalCode, InternalComments
    INTO Purchasing.SuppliersSensible
    FROM Purchasing.Suppliers;

    SELECT PersonID, PhoneNumber, FaxNumber, EmailAddress, LogonName, HashedPassword, IsPermittedToLogon,
           IsExternalLogonProvider, IsSystemUser, Photo, UserPreferences, CustomFields
    INTO Application.PeopleSensible
    FROM Application.People;');
GO

IF N'$(NODO)' = N'corporativo' AND OBJECT_ID(N'Sales.PK_Sales_CustomersSensible') IS NULL
BEGIN
    ALTER TABLE Sales.CustomersSensible ADD CONSTRAINT PK_Sales_CustomersSensible PRIMARY KEY (CustomerID);
    ALTER TABLE Sales.CustomersSensible ADD CONSTRAINT FK_CustomersSensible_Customers
        FOREIGN KEY (CustomerID) REFERENCES Sales.Customers (CustomerID);
    ALTER TABLE Sales.CustomersSensible ADD CONSTRAINT FK_CustomersSensible_PrimaryContact
        FOREIGN KEY (PrimaryContactPersonID) REFERENCES Application.People (PersonID);
    ALTER TABLE Sales.CustomersSensible ADD CONSTRAINT FK_CustomersSensible_AlternateContact
        FOREIGN KEY (AlternateContactPersonID) REFERENCES Application.People (PersonID);

    ALTER TABLE Purchasing.SuppliersSensible ADD CONSTRAINT PK_Purchasing_SuppliersSensible PRIMARY KEY (SupplierID);
    ALTER TABLE Purchasing.SuppliersSensible ADD CONSTRAINT FK_SuppliersSensible_Suppliers
        FOREIGN KEY (SupplierID) REFERENCES Purchasing.Suppliers (SupplierID);
    ALTER TABLE Purchasing.SuppliersSensible ADD CONSTRAINT FK_SuppliersSensible_PrimaryContact
        FOREIGN KEY (PrimaryContactPersonID) REFERENCES Application.People (PersonID);
    ALTER TABLE Purchasing.SuppliersSensible ADD CONSTRAINT FK_SuppliersSensible_AlternateContact
        FOREIGN KEY (AlternateContactPersonID) REFERENCES Application.People (PersonID);

    ALTER TABLE Application.PeopleSensible ADD CONSTRAINT PK_Application_PeopleSensible PRIMARY KEY (PersonID);
    ALTER TABLE Application.PeopleSensible ADD CONSTRAINT FK_PeopleSensible_People
        FOREIGN KEY (PersonID) REFERENCES Application.People (PersonID);
    ALTER TABLE Application.PeopleSensible ADD OtherLanguages AS JSON_QUERY(CustomFields, N'$.OtherLanguages');

    EXEC dbo.Frag_CopiarDefaults N'Sales.Customers', N'Sales.CustomersSensible';
    EXEC dbo.Frag_CopiarDefaults N'Purchasing.Suppliers', N'Purchasing.SuppliersSensible';
    EXEC dbo.Frag_CopiarDefaults N'Application.People', N'Application.PeopleSensible';
END
GO

DROP SECURITY POLICY IF EXISTS Application.FilterCustomersBySalesTerritoryRole;
DROP FUNCTION IF EXISTS Application.DetermineCustomerAccess;
DROP VIEW IF EXISTS Website.Customers, Website.Suppliers;
DROP PROCEDURE IF EXISTS Website.ActivateWebsiteLogon, Website.ChangePassword, Website.InvoiceCustomerOrders,
    Website.SearchForCustomers, Website.SearchForPeople, Website.SearchForSuppliers;
GO

EXEC dbo.Frag_QuitarSensibles N'Sales.Customers', N'Sales.Customers_Archive',
    N'PrimaryContactPersonID, AlternateContactPersonID, PhoneNumber, FaxNumber, WebsiteURL, DeliveryAddressLine1,
      DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2, PostalPostalCode';

EXEC dbo.Frag_QuitarSensibles N'Purchasing.Suppliers', N'Purchasing.Suppliers_Archive',
    N'PrimaryContactPersonID, AlternateContactPersonID, BankAccountName, BankAccountBranch, BankAccountCode,
      BankAccountNumber, BankInternationalCode, PhoneNumber, FaxNumber, WebsiteURL, DeliveryAddressLine1,
      DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2,
      PostalPostalCode, InternalComments';

EXEC dbo.Frag_QuitarSensibles N'Application.People', N'Application.People_Archive',
    N'OtherLanguages, PhoneNumber, FaxNumber, EmailAddress, LogonName, HashedPassword, IsPermittedToLogon,
      IsExternalLogonProvider, IsSystemUser, Photo, UserPreferences, CustomFields';
GO

IF N'$(NODO)' = N'corporativo'
BEGIN
    EXEC (N'CREATE OR ALTER VIEW Sales.vCustomersSensible AS
        SELECT CustomerID, PrimaryContactPersonID, AlternateContactPersonID, PhoneNumber, FaxNumber, WebsiteURL,
               DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, PostalAddressLine1, PostalAddressLine2,
               PostalPostalCode, DeliveryLocation.Lat AS Latitud, DeliveryLocation.Long AS Longitud
        FROM Sales.CustomersSensible;');

    EXEC (N'CREATE OR ALTER VIEW Purchasing.vSuppliersSensible AS
        SELECT SupplierID, PrimaryContactPersonID, AlternateContactPersonID, BankAccountName, BankAccountBranch,
               BankAccountCode, BankAccountNumber, BankInternationalCode, PhoneNumber, FaxNumber, WebsiteURL,
               DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, PostalAddressLine1, PostalAddressLine2,
               PostalPostalCode, InternalComments, DeliveryLocation.Lat AS Latitud, DeliveryLocation.Long AS Longitud
        FROM Purchasing.SuppliersSensible;');

    EXEC (N'CREATE OR ALTER VIEW Sales.vClientesCompletos AS
        SELECT c.*, s.PrimaryContactPersonID, s.AlternateContactPersonID, s.PhoneNumber, s.FaxNumber, s.WebsiteURL,
               s.DeliveryAddressLine1, s.DeliveryAddressLine2, s.DeliveryPostalCode, s.DeliveryLocation,
               s.PostalAddressLine1, s.PostalAddressLine2, s.PostalPostalCode
        FROM Sales.Customers c JOIN Sales.CustomersSensible s ON s.CustomerID = c.CustomerID;');

    EXEC (N'CREATE OR ALTER VIEW Purchasing.vProveedoresCompletos AS
        SELECT p.*, s.PrimaryContactPersonID, s.AlternateContactPersonID, s.BankAccountName, s.BankAccountBranch,
               s.BankAccountCode, s.BankAccountNumber, s.BankInternationalCode, s.PhoneNumber, s.FaxNumber,
               s.WebsiteURL, s.DeliveryAddressLine1, s.DeliveryAddressLine2, s.DeliveryPostalCode, s.DeliveryLocation,
               s.PostalAddressLine1, s.PostalAddressLine2, s.PostalPostalCode, s.InternalComments
        FROM Purchasing.Suppliers p JOIN Purchasing.SuppliersSensible s ON s.SupplierID = p.SupplierID;');

    EXEC (N'CREATE OR ALTER VIEW Application.vPersonasCompletas AS
        SELECT p.*, s.PhoneNumber, s.FaxNumber, s.EmailAddress, s.LogonName, s.HashedPassword, s.IsPermittedToLogon,
               s.IsExternalLogonProvider, s.IsSystemUser, s.Photo, s.UserPreferences, s.CustomFields, s.OtherLanguages
        FROM Application.People p JOIN Application.PeopleSensible s ON s.PersonID = p.PersonID;');
END
GO

DROP PROCEDURE dbo.Frag_EliminarColumna, dbo.Frag_CopiarDefaults, dbo.Frag_QuitarSensibles;
INSERT INTO dbo.ControlFragmentacion (Paso) VALUES (N'vertical');
PRINT 'Fragmentacion vertical aplicada';
GO

SET NOEXEC OFF;
GO

DECLARE @prefijo nvarchar(200) = CASE WHEN N'$(NODO)' = N'corporativo' THEN N'' ELSE N'LS_CORPORATIVO.WWI_Corporativo.' END;
DECLARE @escritura nvarchar(200) = CASE WHEN N'$(NODO)' = N'corporativo' THEN N'' ELSE N'dbo.SoloEnCorporativo_' END;
DECLARE @sql nvarchar(max) = N'
DROP SYNONYM IF EXISTS Syn_CustomersSensible;
DROP SYNONYM IF EXISTS Syn_CustomersSensibleDatos;
DROP SYNONYM IF EXISTS Syn_SuppliersSensible;
DROP SYNONYM IF EXISTS Syn_SuppliersSensibleDatos;
DROP SYNONYM IF EXISTS Syn_PeopleSensible;
CREATE SYNONYM Syn_CustomersSensible FOR ' + @prefijo + N'Sales.vCustomersSensible;
CREATE SYNONYM Syn_CustomersSensibleDatos FOR ' + CASE WHEN @escritura = N'' THEN N'Sales.CustomersSensible' ELSE @escritura + N'CustomersSensible' END + N';
CREATE SYNONYM Syn_SuppliersSensible FOR ' + @prefijo + N'Purchasing.vSuppliersSensible;
CREATE SYNONYM Syn_SuppliersSensibleDatos FOR ' + CASE WHEN @escritura = N'' THEN N'Purchasing.SuppliersSensible' ELSE @escritura + N'SuppliersSensible' END + N';
CREATE SYNONYM Syn_PeopleSensible FOR ' + @prefijo + N'Application.PeopleSensible;';
EXEC (@sql);
PRINT 'Sinonimos del fragmento sensible listos';
GO
