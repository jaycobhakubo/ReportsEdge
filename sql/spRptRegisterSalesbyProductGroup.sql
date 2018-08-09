USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterSalesByProductGroup]    Script Date: 05/13/2014 14:03:54 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterSalesByProductGroup]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterSalesByProductGroup]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterSalesByProductGroup]    Script Date: 05/13/2014 14:03:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptRegisterSalesByProductGroup]     
   
 --=============================================    
 --Author:  Travis Pollock
 --Description: <Register Sales by Product Group - Reports sales made at the POS by Product Group>    
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
--set @StartDate = '03/18/2014 00:00:00'  
--set @EndDate = '03/18/2014 00:00:00'  
--set @StaffID = 0  
--set @Session = 1  
--TEST END  
-->>>>>>>>>>>>>>>>>>>>TEST END<<<<<<<<<<<<<<<<<<<<<
     
SET NOCOUNT ON    
   
Declare @Sales table    
 (    
	productGroup		NVARCHAR(64),    
	itemQty				INT,            
	Amount				money,
	staffName			NVARCHAR(64)          
 );    
         
 --      
 -- Insert Register Sales by Package
 --    
 INSERT INTO @Sales    
  (    
   productGroup,    
   itemQty,
   amount,
   staffName
  )    
 SELECT rdi.GroupName,    
		Sum(rd.Quantity * rdi.Qty),
		case when rr.TransactionTypeId = 1 then sum((rd.Quantity * rdi.Qty) * rdi.Price)  
			when rr.TransactionTypeId = 3 then sum((-1 * rd.Quantity * rdi.Qty) * rdi.Price)  
		end,
		0
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and (@StaffID = 0 or rr.StaffID = @StaffID)
 and rd.VoidedRegisterReceiptID IS NULL  -- Do not include voided transactions
 and rd.DiscountTypeID is null -- Do not include function discounts
GROUP BY  rdi.GroupName, rr.TransactionTypeID
Order By rdi.GroupName 

Update @Sales
Set staffName = (Select s.FirstName + ' ' + s.LastName
				From Staff s
				Where (s.StaffID = @StaffID))

Select *
From @Sales
       
SET NOCOUNT OFF
    
GO

