CREATE OR ALTER PROCEDURE SP_GetAllSuppliers
AS
BEGIN
    SELECT S.SupplierID as SupplierID,
    S.SupplierReference as SupplierReference,
    S.SupplierName as SupplierName,
    SC.SupplierCategoryName as SupplierCategoryName,
    P.FullName as PrimaryContactName,
    P2.FullName as AlternateContactName,
    DM.DeliveryMethodName as DeliveryMethodName,
    C.CityName as DeliveryCityName,
    SS.DeliveryPostalCode as DeliveryPostalCode,
    SS.PhoneNumber as PhoneNumber,
    SS.FaxNumber as FaxNumber,
    SS.WebsiteURL as WebsiteURL,
    SS.DeliveryAddressLine1 as DeliveryAddressLine1,
    SS.DeliveryAddressLine2 as DeliveryAddressLine2,
    SS.PostalAddressLine1 as PostalAddressLine1,
    SS.PostalAddressLine2 as PostalAddressLine2,
    SS.Latitud as DeliveryLatitude,
    SS.Longitud as DeliveryLongitude,
    SS.BankAccountBranch as BankAccountBranch,
    SS.BankAccountName as BankAccountName,
    SS.BankAccountNumber as BankAccountNumber,
    S.PaymentDays as PaymentDays
    FROM Syn_Suppliers S
    INNER JOIN Syn_SuppliersSensible SS ON SS.SupplierID = S.SupplierID
    INNER JOIN Syn_SupplierCategories SC ON SC.SupplierCategoryID = S.SupplierCategoryID
    INNER JOIN Syn_DeliveryMethods DM ON S.DeliveryMethodID = DM.DeliveryMethodID
    INNER JOIN Syn_People P ON P.PersonID = SS.PrimaryContactPersonID
    LEFT JOIN Syn_People P2 ON P2.PersonID = SS.AlternateContactPersonID
    LEFT JOIN Syn_Cities C ON C.CityID = S.DeliveryCityID
    ORDER BY S.SupplierName ASC;
END;
GO