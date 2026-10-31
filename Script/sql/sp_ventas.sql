use WideWorldImporters
GO

CREATE OR ALTER PROCEDURE SP_GetSales
    @CustomerName NVARCHAR(100) = NULL,
    @InvoiceDateFrom DATE = NULL,
    @InvoiceDateTo DATE = NULL,
    @MinTotalAmount DECIMAL(18, 2) = NULL,
    @MaxTotalAmount DECIMAL(18, 2) = NULL,
    @Pagina INT = 1,
    @PorPagina INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT I.InvoiceID as InvoiceID,
        I.InvoiceDate as InvoiceDate,
        C.CustomerName as CustomerName,
        D.DeliveryMethodName as DeliveryMethod,
        SUM(IL.ExtendedPrice) as TotalAmount
    FROM Syn_Invoices I
    INNER JOIN Syn_Customers C ON I.CustomerID = C.CustomerID
    INNER JOIN Syn_DeliveryMethods D ON I.DeliveryMethodID = D.DeliveryMethodID
    LEFT JOIN Syn_InvoiceLines IL ON I.InvoiceID = IL.InvoiceID
    WHERE (@CustomerName IS NULL OR C.CustomerName LIKE '%' + @CustomerName + '%')
        AND (@InvoiceDateFrom IS NULL OR I.InvoiceDate >= @InvoiceDateFrom)
        AND (@InvoiceDateTo IS NULL OR I.InvoiceDate <= @InvoiceDateTo)
    GROUP BY I.InvoiceID, I.InvoiceDate, C.CustomerName, D.DeliveryMethodName
    HAVING (@MinTotalAmount IS NULL OR SUM(IL.ExtendedPrice) >= @MinTotalAmount)
        AND (@MaxTotalAmount IS NULL OR SUM(IL.ExtendedPrice) <= @MaxTotalAmount)
    ORDER BY C.CustomerName ASC, I.InvoiceDate DESC
    OFFSET (@Pagina - 1) * @PorPagina ROWS
    FETCH NEXT @PorPagina ROWS ONLY;
END;
GO


CREATE OR ALTER PROCEDURE SP_GetSalesCount
    @CustomerName NVARCHAR(100) = NULL,
    @InvoiceDateFrom DATE = NULL,
    @InvoiceDateTo DATE = NULL,
    @MinTotalAmount DECIMAL(18, 2) = NULL,
    @MaxTotalAmount DECIMAL(18, 2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) as Total
    FROM (
        SELECT I.InvoiceID
        FROM Syn_Invoices I
        INNER JOIN Syn_Customers C ON I.CustomerID = C.CustomerID
        LEFT JOIN Syn_InvoiceLines IL ON I.InvoiceID = IL.InvoiceID
        WHERE (@CustomerName IS NULL OR C.CustomerName LIKE '%' + @CustomerName + '%')
            AND (@InvoiceDateFrom IS NULL OR I.InvoiceDate >= @InvoiceDateFrom)
            AND (@InvoiceDateTo IS NULL OR I.InvoiceDate <= @InvoiceDateTo)
        GROUP BY I.InvoiceID
        HAVING (@MinTotalAmount IS NULL OR SUM(IL.ExtendedPrice) >= @MinTotalAmount)
            AND (@MaxTotalAmount IS NULL OR SUM(IL.ExtendedPrice) <= @MaxTotalAmount)
    ) AS sub;
END;
GO


CREATE OR ALTER PROCEDURE SP_GetSaleHeader
    @InvoiceID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT I.InvoiceID as InvoiceID,
        C.CustomerName as CustomerName,
        C.CustomerID as CustomerID,
        D.DeliveryMethodName as DeliveryMethod,
        I.DeliveryMethodID as DeliveryMethodID,
        I.CustomerPurchaseOrderNumber as CustomerPurchaseOrderNumber,
        P.FullName as ContactPerson,
        I.ContactPersonID as ContactPersonID,
        P2.FullName as Salesperson,
        I.SalespersonPersonID as SalespersonPersonID,
        I.InvoiceDate as InvoiceDate,
        I.DeliveryInstructions as DeliveryInstructions,
        ISNULL(SUM(IL.ExtendedPrice - IL.TaxAmount), 0) as Subtotal,
        ISNULL(SUM(IL.TaxAmount), 0) as TotalTax,
        ISNULL(SUM(IL.ExtendedPrice), 0) as TotalAmount
    FROM Syn_Invoices I
    INNER JOIN Syn_Customers C ON I.CustomerID = C.CustomerID
    INNER JOIN Syn_DeliveryMethods D ON I.DeliveryMethodID = D.DeliveryMethodID
    INNER JOIN Syn_People P ON I.ContactPersonID = P.PersonID
    INNER JOIN Syn_People P2 ON I.SalespersonPersonID = P2.PersonID
    LEFT JOIN Syn_InvoiceLines IL ON I.InvoiceID = IL.InvoiceID
    WHERE I.InvoiceID = @InvoiceID
    GROUP BY I.InvoiceID, C.CustomerName, C.CustomerID, D.DeliveryMethodName,
        I.DeliveryMethodID, I.CustomerPurchaseOrderNumber, P.FullName,
        I.ContactPersonID, P2.FullName, I.SalespersonPersonID,
        I.InvoiceDate, I.DeliveryInstructions;
END;
GO

CREATE OR ALTER PROCEDURE SP_GetSaleDetails
    @InvoiceID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT SI.StockItemID as StockItemID,
        SI.StockItemName as StockItemName,
        IL.Quantity as Quantity,
        IL.UnitPrice as UnitPrice,
        IL.TaxRate as TaxRate,
        IL.TaxAmount as TaxAmount,
        IL.ExtendedPrice as ExtendedPrice,
        IL.ExtendedPrice as TotalPorLinea
    FROM Syn_InvoiceLines IL
    INNER JOIN Syn_StockItems SI ON IL.StockItemID = SI.StockItemID
    WHERE IL.InvoiceID = @InvoiceID
    ORDER BY SI.StockItemName ASC;
END;
GO
