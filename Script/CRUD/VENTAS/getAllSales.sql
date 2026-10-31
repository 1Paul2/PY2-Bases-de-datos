USE WideWorldImporters;
GO
CREATE OR ALTER PROCEDURE SP_GetAllSales
    @CustomerName VARCHAR(100) = NULL,
    @DateFrom DATE = NULL,
    @DateTo DATE = NULL,
    @MinAmount DECIMAL(18,2) = NULL,
    @MaxAmount DECIMAL(18,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        I.InvoiceID,
        I.InvoiceDate,
        C.CustomerName,
        D.DeliveryMethodName AS DeliveryMethod,
        SUM(IL.ExtendedPrice) AS TotalAmount
    FROM Syn_Invoices I
    INNER JOIN Syn_Customers C ON I.CustomerID = C.CustomerID
    INNER JOIN Syn_DeliveryMethods D ON I.DeliveryMethodID = D.DeliveryMethodID
    LEFT JOIN Syn_InvoiceLines IL ON I.InvoiceID = IL.InvoiceID
    WHERE (@CustomerName IS NULL OR C.CustomerName LIKE '%' + @CustomerName + '%')
      AND (@DateFrom IS NULL OR I.InvoiceDate >= @DateFrom)
      AND (@DateTo IS NULL OR I.InvoiceDate <= @DateTo)
    GROUP BY I.InvoiceID, I.InvoiceDate, C.CustomerName, D.DeliveryMethodName
    HAVING (@MinAmount IS NULL OR SUM(IL.ExtendedPrice) >= @MinAmount)
       AND (@MaxAmount IS NULL OR SUM(IL.ExtendedPrice) <= @MaxAmount)
    ORDER BY C.CustomerName ASC, I.InvoiceDate DESC;
END;
GO