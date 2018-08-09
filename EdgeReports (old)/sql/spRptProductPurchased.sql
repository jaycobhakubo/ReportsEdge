USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPurchasedProduct]    Script Date: 08/08/2012 11:09:00 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPurchasedProduct]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPurchasedProduct]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPurchasedProduct]    Script Date: 08/08/2012 11:09:00 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



--------
--kc:US2125:8.7.2012:created a new report per manager

CREATE proc [dbo].[spRptPurchasedProduct]
--declare
@OperatorID int,
@ProductItemID int,
@StartDate datetime,
@EndDate datetime

as
begin
-------------------------------
--set @ProductItemID  = 23
--set @StartDate = '7/9/1998 07:02:45'
--set @EndDate  = '07/9/2013 05:01:45'
--set @OperatorID = 1
-------------------------------------
declare @ItemName varchar(500)
select @ItemName = ItemName from ProductItem where 
ProductItemID = @ProductItemID and OperatorID = @OperatorID

select  
--rdi.RegisterDetailItemID ,rd.RegisterDetailID ,rr.RegisterReceiptID, rr.GamingDate -- DO NOT DELETE ,
distinct(rr.PlayerID),
LastName +', '+P.FirstName as [Name],
a.Address1+' '+isnull(Address2,'') as [Address] ,
a.City,
a.Zip ,
p.Phone as [Phone Number] ,
p.EMail as [Email Address],
p.BirthDate as [Date of Birth],
p.Gender ,
rdi.ProductItemName,
count(rr.PlayerID) as [NumberOfItemPurchased]
from 
RegisterDetailItems rdi 
left join RegisterDetail rd on rd.RegisterDetailID = rdi.RegisterDetailID 
left join RegisterReceipt rr on rr.RegisterReceiptID = rd.RegisterReceiptID 
left join Player p on p.PlayerID = rr.PlayerID 
left join [Address] a on a.AddressID = p.AddressID 
where rr.TransactionTypeID = 1
and rr.Playerid is not null
and rr.SaleSuccess = 1
and (p.FirstName is not null and p.lastname is not null) 
and ProductItemName = @ItemName 
and rr.GamingDate  >= CAST(CONVERT(varchar(12), @StartDate, 101) AS SMALLDATETIME)
and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS SMALLDATETIME)
and(rr.OperatorID = @OperatorID or @OperatorID = 0)
group by 
rr.PlayerID,
LastName, P.FirstName, 
a.Address1, Address2,
a.City,
a.Zip ,
p.Phone  ,
p.EMail ,
p.BirthDate ,
p.Gender ,
rdi.ProductItemName



end


GO


