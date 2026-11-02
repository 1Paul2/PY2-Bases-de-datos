CREATE OR ALTER PROCEDURE SP_GetAllCustomers
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        C.CustomerID,
        C.CustomerName,
        CC.CustomerCategoryName,
        BG.BuyingGroupName,
        P1.FullName AS PrimaryContact,
        P2.FullName AS AlternateContact,
        B.CustomerName AS BillToCustomer,
        DM.DeliveryMethodName,
        City.CityName AS DeliveryCity,
        S.PostalPostalCode,
        S.PhoneNumber,
        S.FaxNumber,
        C.PaymentDays,
        S.WebsiteURL,
        S.DeliveryAddressLine1,
        S.DeliveryAddressLine2,
        S.PostalAddressLine1,
        S.PostalAddressLine2,
        S.Latitud AS DeliveryLatitude,
        S.Longitud AS DeliveryLongitude
    FROM Syn_Customers C
    INNER JOIN Syn_CustomersSensible S
        ON S.CustomerID = C.CustomerID
    INNER JOIN Syn_CustomerCategories CC
        ON C.CustomerCategoryID = CC.CustomerCategoryID
    LEFT JOIN Syn_BuyingGroups BG
        ON C.BuyingGroupID = BG.BuyingGroupID
    INNER JOIN Syn_People P1
        ON S.PrimaryContactPersonID = P1.PersonID
    LEFT JOIN Syn_People P2
        ON S.AlternateContactPersonID = P2.PersonID
    LEFT JOIN Syn_Customers B 
        ON C.BillToCustomerID = B.CustomerID
    INNER JOIN Syn_DeliveryMethods DM 
        ON C.DeliveryMethodID = DM.DeliveryMethodID
    LEFT JOIN Syn_Cities City 
        ON C.DeliveryCityID = City.CityID
    ORDER BY C.CustomerName ASC;
END;
GO