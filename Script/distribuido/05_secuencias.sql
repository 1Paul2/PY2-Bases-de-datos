SET NOCOUNT ON;
USE [$(BASE)];
GO

DECLARE @inicio bigint = CASE N'$(NODO)' WHEN N'sanjose' THEN 1000000 WHEN N'limon' THEN 2000000 END;

IF @inicio IS NULL
BEGIN
    PRINT 'Corporativo: las secuencias siguen desde su valor actual';
    RETURN;
END

DECLARE @sql nvarchar(max) = N'', @cantidad int = 0;
SELECT @sql += N'ALTER SEQUENCE Sequences.' + QUOTENAME(name) + N' RESTART WITH ' + CAST(@inicio AS nvarchar(20)) + N';',
       @cantidad += 1
FROM sys.sequences
WHERE schema_id = SCHEMA_ID(N'Sequences') AND CAST(current_value AS bigint) < @inicio;

EXEC (@sql);
PRINT CONCAT(@cantidad, ' secuencias reiniciadas desde ', @inicio, ' (las demas ya estaban en su rango)');
GO
