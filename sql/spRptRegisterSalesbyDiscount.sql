USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterSalesByDiscount]    Script Date: 05/13/2014 14:03:54 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterSalesByDiscount]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterSalesByDiscount]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterSalesByDiscount]    Script Date: 05/13/2014 14:03:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptRegisterSalesByDiscount]     
   
 --=============================================    
 --Author:  Travis Pollock
 --Description: <Register Sales by Discount - Reports sales made at the POS by Discount>  
 -- 20150923(knc): Add coupon sales  
 --=============================================    
  
	@OperatorID  AS INT,    
	@StartDate  AS DATETIME,    
	@EndDate  AS DATETIME,    
	@Session  AS INT,
	@StaffID as  int  
 


--set @OperatorID = 1   
--set @StartDate = '09/23/2015 00:00:00'  
--set @EndDate = '09/23/2015 00:00:00'  
--set @StaffID = 4  
--set @Session = 0

AS  
     
SET NOCOUNT ON    
   
Declare @Sales table    
 (    
	discount			NVARCHAR(64),    
	itemQty				INT,            
	Amount				money,
	staffName			NVARCHAR(64)          
 );    
         
 --      
 -- Insert Register Sales by Discount
 --    
 INSERT INTO @Sales    
  (    
   discount,    
   itemQty,
   amount,
   staffName
  )    
 SELECT d.DiscountTypeName + ' ' + convert(nvarchar,(-1 * rd.DiscountAmount)),
		Sum(rd.Quantity),
		case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rd.DiscountAmount)  
			when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rd.DiscountAmount)  
		end,
		0
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
 join DiscountTypes d on (rd.DiscountTypeID = d.DiscountTypeID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and (@StaffID = 0 or rr.StaffID = @StaffID)
 and rd.VoidedRegisterReceiptID IS NULL  -- Only include sales that have not been voided
 and rd.DiscountTypeID is not null -- Only include function discounts
GROUP BY  d.DiscountTypeName, rd.DiscountAmount, rr.TransactionTypeID
Order By d.DiscountTypeName

 INSERT INTO @Sales    
  (    
   discount,    
   itemQty,
   amount,
   staffName
  )  
select CouponName, SUM(QuantityNet), SUM(NetSales), '' from dbo.FindCouponSales(@OperatorID, @StartDate, @EndDate, @Session)
where (StaffID = @StaffID or @StaffID = 0)
group by CouponName

Update @Sales
Set staffName = (Select s.FirstName + ' ' + s.LastName
				From Staff s
				Where (s.StaffID = @StaffID))

Select *
From @Sales
       
SET NOCOUNT OFF
    
GO

