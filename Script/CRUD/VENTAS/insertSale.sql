USE WideWorldImporters;
GO

CREATE OR ALTER PROCEDURE SP_InsertSale
    @CustomerID INT,
    @DeliveryMethodID INT,
    @CustomerPurchaseOrderNumber NVARCHAR(20),
    @ContactPersonID  INT,
    @SalespersonPersonID INT,
    @InvoiceDate DATE,
    @DeliveryInstructions NVARCHAR(500),
    @Lines NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Validaciones
    IF NOT EXISTS (SELECT 1 FROM Syn_Customers WHERE CustomerID = @CustomerID)
        THROW 50010, 'El cliente indicado no existe.', 1;

    IF NOT EXISTS (SELECT 1 FROM Syn_DeliveryMethods WHERE DeliveryMethodID = @DeliveryMethodID)
        THROW 50011, 'El método de entrega indicado no existe.', 1;

    IF @Lines IS NULL OR LTRIM(RTRIM(@Lines)) = ''
        THROW 50012, 'Debe incluir al menos una línea de factura.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- PARSER: cada línea es StockItemID|Cantidad|PrecioUnitario|Impuesto|Descripcion, separadas por ;
        ;WITH Filas AS (
            SELECT LTRIM(RTRIM(value)) AS Fila
            FROM STRING_SPLIT(@Lines, ';')
            WHERE LTRIM(RTRIM(value)) <> ''
        ),
        Campos AS (
            SELECT
                F.Fila,
                LTRIM(RTRIM(P1.value)) AS StockItemID,
                LTRIM(RTRIM(P2.value)) AS Quantity,
                LTRIM(RTRIM(P3.value)) AS UnitPrice,
                LTRIM(RTRIM(P4.value)) AS TaxRate,
                LTRIM(RTRIM(P5.value)) AS Description
            FROM Filas F
            CROSS APPLY (SELECT value FROM STRING_SPLIT(F.Fila, '|') ORDER BY (SELECT NULL) OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY) P1
            CROSS APPLY (SELECT value FROM STRING_SPLIT(F.Fila, '|') ORDER BY (SELECT NULL) OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY) P2
            CROSS APPLY (SELECT value FROM STRING_SPLIT(F.Fila, '|') ORDER BY (SELECT NULL) OFFSET 2 ROWS FETCH NEXT 1 ROWS ONLY) P3
            CROSS APPLY (SELECT value FROM STRING_SPLIT(F.Fila, '|') ORDER BY (SELECT NULL) OFFSET 3 ROWS FETCH NEXT 1 ROWS ONLY) P4
            CROSS APPLY (SELECT value FROM STRING_SPLIT(F.Fila, '|') ORDER BY (SELECT NULL) OFFSET 4 ROWS FETCH NEXT 1 ROWS ONLY) P5
        )
        SELECT
            CAST(StockItemID AS INT) AS StockItemID,
            CAST(Quantity AS INT) AS Quantity,
            CAST(UnitPrice AS DECIMAL(18,2)) AS UnitPrice,
            CAST(TaxRate AS DECIMAL(18,3)) AS TaxRate,
            Description
        INTO #Lineas
        FROM Campos;

        -- Si ninguna fila tuvo los 5 campos, el parser las descarta 
        IF NOT EXISTS (SELECT 1 FROM #Lineas)
            THROW 50014, 'Las líneas de factura no tienen un formato válido.', 1;

        IF EXISTS (
            SELECT 1 FROM #Lineas L
            WHERE NOT EXISTS (SELECT 1 FROM Syn_StockItems SI WHERE SI.StockItemID = L.StockItemID)
        )
            THROW 50013, 'Una o más líneas referencian un producto inexistente.', 1;

        IF EXISTS (SELECT 1 FROM #Lineas WHERE Quantity <= 0 OR UnitPrice < 0 OR TaxRate < 0)
            THROW 50016, 'Las cantidades deben ser mayores que cero y los precios e impuestos no pueden ser negativos.', 1;

        -- Inventario: no se puede vender más de lo que hay disponible
        DECLARE @SinInventario NVARCHAR(2000);
        SELECT @SinInventario = STRING_AGG(CAST(SI.StockItemName AS NVARCHAR(MAX)) + ' (disponible: '
                   + CAST(CAST(ISNULL(SIH.QuantityOnHand, 0) AS INT) AS NVARCHAR(20)) + ')', '; ')
        FROM (SELECT StockItemID, SUM(Quantity) AS Cantidad FROM #Lineas GROUP BY StockItemID) L
        INNER JOIN Syn_StockItems SI ON SI.StockItemID = L.StockItemID
        LEFT JOIN Syn_StockItemHoldings SIH ON SIH.StockItemID = L.StockItemID
        WHERE L.Cantidad > ISNULL(SIH.QuantityOnHand, 0);

        IF @SinInventario IS NOT NULL
        BEGIN
            SET @SinInventario = LEFT('No hay suficiente inventario para: ' + @SinInventario, 2000);
            THROW 50015, @SinInventario, 1;
        END

        DECLARE @BillToCustomerID INT;
        SELECT @BillToCustomerID = BillToCustomerID
        FROM Syn_Customers
        WHERE CustomerID = @CustomerID;

        IF @BillToCustomerID IS NULL
            SET @BillToCustomerID = @CustomerID;

        DECLARE @NewInvoiceID INT = NEXT VALUE FOR Sequences.InvoiceID;

        INSERT INTO Syn_Invoices
        (
            InvoiceID, CustomerID, BillToCustomerID, DeliveryMethodID,
            ContactPersonID, AccountsPersonID, SalespersonPersonID, PackedByPersonID,
            InvoiceDate, CustomerPurchaseOrderNumber, IsCreditNote,
            DeliveryInstructions, TotalDryItems, TotalChillerItems, LastEditedBy
        )
        VALUES
        (
            @NewInvoiceID, @CustomerID, @BillToCustomerID, @DeliveryMethodID,
            @ContactPersonID, @ContactPersonID, @SalespersonPersonID, @SalespersonPersonID,
            @InvoiceDate, @CustomerPurchaseOrderNumber, 0,
            @DeliveryInstructions, 0, 0, @SalespersonPersonID
        );

        
        INSERT INTO Syn_InvoiceLines
        (
            InvoiceID, StockItemID, Description,
            PackageTypeID, Quantity, UnitPrice, TaxRate, TaxAmount,
            LineProfit, ExtendedPrice, LastEditedBy, LastEditedWhen
        )
        SELECT
            @NewInvoiceID,
            L.StockItemID,
            ISNULL(NULLIF(L.Description, ''), SI.StockItemName),
            SI.UnitPackageID,
            L.Quantity,
            L.UnitPrice,
            L.TaxRate,
            T.TaxAmount,
            CAST(L.Quantity * (L.UnitPrice - ISNULL(SIH.LastCostPrice, 0)) AS DECIMAL(18,2)),
            CAST(L.Quantity * L.UnitPrice AS DECIMAL(18,2)) + T.TaxAmount,
            @SalespersonPersonID,
            SYSDATETIME()
        FROM #Lineas L
        INNER JOIN Syn_StockItems SI ON SI.StockItemID = L.StockItemID
        LEFT JOIN Syn_StockItemHoldings SIH ON SIH.StockItemID = L.StockItemID
        CROSS APPLY (
            SELECT CAST(ROUND(L.Quantity * L.UnitPrice * L.TaxRate / 100.0, 2) AS DECIMAL(18,2)) AS TaxAmount
        ) T;


        -- Se descuenta el inventario y se registra el movimiento (Stock Issue), igual que en la base original
        UPDATE SIH
        SET SIH.QuantityOnHand = SIH.QuantityOnHand - L.Cantidad,
            SIH.LastEditedBy = @SalespersonPersonID,
            SIH.LastEditedWhen = SYSDATETIME()
        FROM Syn_StockItemHoldings SIH
        INNER JOIN (SELECT StockItemID, SUM(Quantity) AS Cantidad FROM #Lineas GROUP BY StockItemID) L
            ON L.StockItemID = SIH.StockItemID;

        DECLARE @TipoSalida INT;
        SELECT @TipoSalida = TransactionTypeID FROM Syn_TransactionTypes WHERE TransactionTypeName = 'Stock Issue';

        IF @TipoSalida IS NOT NULL
            INSERT INTO Syn_StockItemTransactions
                (StockItemID, TransactionTypeID, CustomerID, InvoiceID, TransactionOccurredWhen, Quantity, LastEditedBy)
            SELECT L.StockItemID, @TipoSalida, @CustomerID, @NewInvoiceID, SYSDATETIME(), -L.Cantidad, @SalespersonPersonID
            FROM (SELECT StockItemID, SUM(Quantity) AS Cantidad FROM #Lineas GROUP BY StockItemID) L;

        -- Totales de artículos secos y refrigerados de la factura
        UPDATE I
        SET I.TotalDryItems = T.Secos,
            I.TotalChillerItems = T.Refrigerados
        FROM Syn_Invoices I
        CROSS APPLY (
            SELECT ISNULL(SUM(CASE WHEN SI.IsChillerStock = 0 THEN L.Quantity END), 0) AS Secos,
                   ISNULL(SUM(CASE WHEN SI.IsChillerStock = 1 THEN L.Quantity END), 0) AS Refrigerados
            FROM #Lineas L INNER JOIN Syn_StockItems SI ON SI.StockItemID = L.StockItemID
        ) T
        WHERE I.InvoiceID = @NewInvoiceID;

        DROP TABLE #Lineas;

        COMMIT TRANSACTION;

        SELECT @NewInvoiceID AS NewInvoiceID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Lineas') IS NOT NULL DROP TABLE #Lineas;
        THROW;
    END CATCH;
END;
GO