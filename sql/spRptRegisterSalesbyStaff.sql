USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterSalesByStaff]    Script Date: 05/13/2014 14:03:54 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterSalesByStaff]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterSalesByStaff]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterSalesByStaff]    Script Date: 05/13/2014 14:03:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptRegisterSalesByStaff]     
   
 --=============================================    
 --Author:  Travis Pollock
 --Description: <Register Sales by Staff - Reports sales made at the POS by Staff>    
 --20150917(knc): Add coupon Sales. 
 --			  :Revert back to its original states the coupon sales its being added on the previous SP.
 --=============================================    
  
	@OperatorID  AS INT,    
	@StartDate  AS DATETIME,    
	@EndDate  AS DATETIME,    
	@Session  AS INT,
	@StaffID as  int  
AS   

-->>>>>>>>>>>>>>>>>>TEST START<<<<<<<<<<<<<<<<<<  
--declare  
--@OperatorID  as int,  
--@StartDate  as datetime,  
--@EndDate  as datetime,  
--@StaffID  as int,  
--@Session  as int  
  
  
--set @OperatorID = 1   
--set @StartDate = '09/16/2015 00:00:00'  
--set @EndDate = '09/16/2015 00:00:00'  
--set @StaffID = 0  
--set @Session = 0
--TEST END  
-->>>>>>>>>>>>>>>>>>>>TEST END<<<<<<<<<<<<<<<<<<<<<
     
SET NOCOUNT ON    
   
Declare @Sales table    
 (          
	Amount				money,
	staffName			NVARCHAR(64),
	staffID				INT          
 );    
         
 --      
 -- Insert Register Sales by Discount
 --    
 INSERT INTO @Sales    
  (    
   amount,
   staffName,
   staffID
  )    
SELECT case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rd.PackagePrice) --- sum(c.Value)--Decuct the total amount to coupon amount
			when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rd.PackagePrice) --+ sum(c.Value)--Return coupon
		end,
		s.FirstName + ' ' + s.LastName,
		s.StaffID
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
 join Staff s on (s.StaffID = rr.StaffID)
 --left join CompAward ca on rd.CompAwardID = ca.CompAwardID
 --left join Comps c on ca.CompID = c.CompID
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and (@StaffID = 0 or rr.StaffID = @StaffID)
 and rd.VoidedRegisterReceiptID IS NULL  -- Only include sales that have not been voided
 and rd.DiscountTypeID is not null -- Only include function discounts
GROUP BY  s.StaffID, s.FirstName, s.LastName, rr.TransactionTypeID

--      
 -- Insert Register Sales
 --    
 INSERT INTO @Sales    
  (    
   amount,
   staffName,
   staffID
  )    

SELECT case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rd.PackagePrice) --- sum(c.Value)--Decuct the total amount to coupon amount
			when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rd.PackagePrice) --+ sum(c.Value)--Return coupon
		end,
		s.FirstName + ' ' + s.LastName,
		s.StaffID
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
 join Staff s on (s.StaffID = rr.StaffID)
 --left join CompAward ca on rd.CompAwardID = ca.CompAwardID
 --left join Comps c on ca.CompID = c.CompID
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and (@StaffID = 0 or rr.StaffID = @StaffID)
 and rd.VoidedRegisterReceiptID IS NULL  -- Only include sales that have not been voided
 and rd.DiscountTypeID is null -- Only include function discounts
GROUP BY  s.StaffID, s.FirstName, s.LastName, rr.TransactionTypeID

Select	staffID,
		staffName,
		SUM(Amount) as Amount
From @Sales 
Group By staffID, staffName
       
SET NOCOUNT OFF
    
GO

