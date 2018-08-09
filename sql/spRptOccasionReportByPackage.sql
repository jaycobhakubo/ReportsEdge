USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionByPackage]    Script Date: 04/17/2015 15:32:36 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptOccasionByPackage]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptOccasionByPackage]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionByPackage]    Script Date: 04/17/2015 15:32:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		FortuNet
-- Create date: 2015.04.16
-- Description:	Package sales
-- =============================================
CREATE PROCEDURE [dbo].[spRptOccasionByPackage]
	-- Add the parameters for the stored procedure here
	@OperatorID  as int,  
	@StartDate  as datetime,  
	@Session  as int  
AS
BEGIN
	SET NOCOUNT ON;
	
	Declare @EndDate as datetime
	Set @EndDate = @StartDate

    -- Insert statements for procedure here
	Declare @Sales table    
 (    
	packageName			NVARCHAR(64),    
	itemQty				INT,            
	price               money,
	Amount				money,
	voidAmt				money,
	PaperAmt			money,
	ElectronicAmt		money,
	PullTabAmt			money,
	BingoOtherAmt		money		
 );    
         
 --      
 -- Insert Register Sales by Package
 --    
 INSERT INTO @Sales    
  (    
   packageName,    
   itemQty,
   price,
   amount
  )    
 SELECT rd.PackageName,    
		Sum(rd.Quantity),
		rd.PackagePrice,   
		case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rd.PackagePrice)  
			when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rd.PackagePrice)  
		end
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL  -- Do not include voided transactions
 and rd.DiscountTypeID is null -- Do not include function discounts
GROUP BY  rd.PackageName, rd.PackagePrice, rr.TransactionTypeID
Order By rd.PackageName, rd.PackagePrice

INSERT INTO @Sales    
  (    
   voidAmt
  )    
 SELECT	sum(rd.Quantity * rd.PackagePrice)  
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1) 
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session) 
 and rd.VoidedRegisterReceiptID IS not NULL	 
 and rd.DiscountTypeID is null -- Do not include function discounts
GROUP BY  rd.PackageName, rd.PackagePrice, rr.TransactionTypeID
Order By rd.PackageName, rd.PackagePrice

INSERT INTO @Sales    
  (    
   ElectronicAmt
  )    
 SELECT	case when rr.TransactionTypeId = 1 then sum((rd.Quantity * rdi.Qty) * rdi.Price)  
			when rr.TransactionTypeId = 3 then sum((-1 * rd.Quantity * rdi.Qty) * rdi.Price)  
		end
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
 join ProductType pt on (pt.ProductTypeID = rdi.ProductTypeID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL  -- Do not include voided transactions
 AND rdi.ProductTypeID IN (1, 2, 3, 4, 5) -- Electronic Sales
 AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)  -- Electronic
 and rd.DiscountTypeID is null -- Do not include function discounts
GROUP BY  pt.ProductType, rr.TransactionTypeID
Order By pt.ProductType

INSERT INTO @Sales    
  (    
   PaperAmt
  )    
 SELECT	case when rr.TransactionTypeId = 1 then sum((rd.Quantity * rdi.Qty) * rdi.Price)  
			when rr.TransactionTypeId = 3 then sum((-1 * rd.Quantity * rdi.Qty) * rdi.Price)  
		end
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
 join ProductType pt on (pt.ProductTypeID = rdi.ProductTypeID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL  -- Do not include voided transactions
 AND rdi.ProductTypeID IN (1, 2, 3, 4, 16) -- Electronic Sales
 AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)  -- Paper
 and rd.DiscountTypeID is null -- Do not include function discounts
GROUP BY  pt.ProductType, rr.TransactionTypeID
Order By pt.ProductType

INSERT INTO @Sales    
  (    
   PullTabAmt
  )    
 SELECT	case when rr.TransactionTypeId = 1 then sum((rd.Quantity * rdi.Qty) * rdi.Price)  
			when rr.TransactionTypeId = 3 then sum((-1 * rd.Quantity * rdi.Qty) * rdi.Price)  
		end
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
 join ProductType pt on (pt.ProductTypeID = rdi.ProductTypeID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL  -- Do not include voided transactions
 AND rdi.ProductTypeID = 17 -- Pull Tab
 and rd.DiscountTypeID is null -- Do not include function discounts
GROUP BY  pt.ProductType, rr.TransactionTypeID
Order By pt.ProductType

INSERT INTO @Sales    
  (    
   BingoOtherAmt
  )    
 SELECT	case when rr.TransactionTypeId = 1 then sum((rd.Quantity * rdi.Qty) * rdi.Price)  
			when rr.TransactionTypeId = 3 then sum((-1 * rd.Quantity * rdi.Qty) * rdi.Price)  
		end
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
 join ProductType pt on (pt.ProductTypeID = rdi.ProductTypeID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL  -- Do not include voided transactions
 AND rdi.ProductTypeID = 14 -- Bingo Other
 and rd.DiscountTypeID is null -- Do not include function discounts
GROUP BY  pt.ProductType, rr.TransactionTypeID
Order By pt.ProductType


Select packageName,
	   SUM(itemQty) as Qty,
	   SUM(Amount)  as SalesTotal,
	   SUM(voidAmt)	as VoidTotal,
	   SUM(ElectronicAmt) as ElectronicTotal,
	   SUM(PaperAmt) as PaperTotal,
	   SUM(PullTabAmt) as PullTabTotal,
	   SUM(BingoOtherAmt) as BingoOtherTotal
From @Sales
Group By packageName

SET NOCOUNT OFF

END

GO

