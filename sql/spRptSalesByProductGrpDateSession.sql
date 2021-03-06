USE [Daily]
GO
/****** Object:  StoredProcedure [dbo].[spRptSalesByProductGrpDateSession]    Script Date: 10/23/2014 14:53:50 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSalesByProductGrpDateSession]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSalesByProductGrpDateSession]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByProductGrpDateSession]    Script Date: 12/08/2014 15:19:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    
CREATE PROCEDURE  [dbo].[spRptSalesByProductGrpDateSession]     
   
 --=============================================    
 --Author:  Travis Pollokc    
 --Description: <US3823: Sales by product grouped by date and session. Copied logic from spRptSalesByPackageTotals>    
 --=============================================    

 @OperatorID  AS INT,    
 @StartDate  AS DATETIME,    
 @EndDate  AS DATETIME,    
 @Session  AS INT 
--@StaffID as  int  
AS   


  
-->>>>>>>>>>>>>>>>>>TEST START<<<<<<<<<<<<<<<<<<  
--declare  
--@OperatorID  as int,  
--@StartDate  as datetime,  
--@EndDate  as datetime,  
--@StaffID  as int,  
--@Session  as int  
--  
--  
--set @OperatorID = 1   
--set @StartDate = '10/1/2014 00:00:00'  
--set @EndDate = '10/31/2014 00:00:00'  
--set @StaffID = 0  
--set @Session = 0  
--TEST END  
-->>>>>>>>>>>>>>>>>>>>TEST END<<<<<<<<<<<<<<<<<<<<<
  
Declare @StaffID as int
set @StaffID = 0; 
     
SET NOCOUNT ON    
    
--begin    
 -- Results table: use table var for performance    
  declare @Sales table    
 (    
  packageName         NVARCHAR(64),    
  productItemName  NVARCHAR(64),    
  staffIdNbr          int,                
  staffName           NVARCHAR(64),    
  itemQty       INT,            
  price               money,             
  gamingDate          datetime,           
  sessionNbr          int,               
  merchandise   MONEY,    
  paper    MONEY,          -- original field, represents paper sales made at a register    
  paperSalesFloor  MONEY,             
  paperSalesTotal  MONEY,              
  electronic   MONEY,    
  credit    MONEY,    
  discount   MONEY,    
  other    MONEY,    
  payouts    MONEY         
  , ProductTypeId     int             
 ,PullTab money  
 ,DeviceFee money  
 ,Tax money  
  , coupons money
 );    
    
  
    
 -- Insert Coupon Rows
Insert into @Sales
 (
	packageName,
	productItemName,
	staffIdNbr,
	staffName,
	itemQty,
	price,
	gamingDate,
	sessionNbr,
	merchandise,
	paper,
	paperSalesFloor,
	paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	payouts,
	ProductTypeId,
	PullTab,
	DeviceFee,
	Tax,
	coupons
)
Select	CouponName,
		CouponName,
		fcs.StaffID,
		s.LastName + ', ' + s.FirstName,
		SUM(QuantityNet),
		CouponValue,
		GamingDate,
		GamingSession,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		SUM(NetSales)
From dbo.FindCouponSales (@OperatorID, @StartDate, @EndDate, @Session) fcs
join Staff s on fcs.StaffID = s.StaffID
    and (@StaffID = 0 or fcs.StaffID = @StaffID)  
Group By CouponName, fcs.StaffID, CouponValue, GamingDate, GamingSession, s.LastName, s.FirstName
      
      
 --      
 -- Insert merchandise Rows      
 --    
 INSERT INTO @Sales    
  (    
   packageName,    
   productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,        
   itemQty,    
   merchandise,    
   paper, paperSalesFloor, paperSalesTotal,        
   electronic,    
   credit,    
   discount,    
   other,    
   payouts    
   , ProductTypeId    
   ,PullTab   
   ,DeviceFee , coupons      
  )    
 SELECT rd.PackageName,    
   rdi.ProductItemName,     
   --NULL,    
   --'',    
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,       
 case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty)  
       when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty)  
  end,  
  case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty * rdi.Price)  
       when rr.TransactionTypeId = 3 then sum (-1 * rd.Quantity * rdi.Qty * rdi.Price)  
  end,    
   0.00, 0.00, 0.00,    
   0.00,    
   0.00,    
   0.00,    
   0.00,    
   0.00    
   , rdi.ProductTypeID    
   ,00  
   ,00  
   ,00
 from RegisterReceipt rr  
 join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)  
 join Staff s on rr.StaffID = s.StaffID  
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
 and rr.OperatorID = @OperatorID  
 and (rdi.ProductTypeID = 7 or rdi.ProductTypeId = 6) --Merchandise or Concessions  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and (@StaffID = 0 or rr.StaffID = @StaffID)
 and rd.VoidedRegisterReceiptID IS NULL  
 and (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic  
GROUP BY  rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate  
        , sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID  
        , rr.TransactionTypeId, rd.PackageName,rdi.ProductTypeID   
          
--ELECTRONIC SALES

  
CREATE TABLE #TempDevicePerReceiptDeviceSummary  
 (   registerReceiptID INT,  deviceID   INT,  soldToMachineID  INT,   unitNumber   INT  )  
 
     INSERT INTO #TempDevicePerReceiptDeviceSummary  
 (  registerReceiptID,  deviceID, soldToMachineID,   unitNumber   )  

SELECT rr.RegisterReceiptID,  
  (SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),  
  (SELECT TOP 1 ulSoldToMachineID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),  
  (SELECT TOP 1 ulUnitNumber FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC)  
FROM RegisterReceipt rr  
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    

  
 
 INSERT INTO @Sales    
  (    
   packageName,productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,           
   itemQty,    
   merchandise,    
   paper, paperSalesFloor, paperSalesTotal,    
   electronic,    
   credit,    
   discount,    
   other,    
   payouts    
   , ProductTypeId    
   ,PullTab       
   ,DeviceFee , coupons  
  )    
 SELECT rd.PackageName,rdi.ProductItemName,    
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                         
   SUM(rd.Quantity * rdi.Qty),--itemQty,    
   0.0,--merchandise,    
   0.0, 0.0, 0.0, --paper,    
   SUM(rd.Quantity * rdi.Qty * rdi.Price),--electronic,    
   0.0,--credit,    
   0.0,--discount,    
   0.0,--other,    
   0.0--payouts    
   , rdi.ProductTypeID    
   ,0.00  
   ,00    ,00
 FROM RegisterReceipt rr    
  JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
  JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
  join Staff s on rr.StaffID = s.StaffID    
  join #TempDevicePerReceiptDeviceSummary  dpr on dpr.registerreceiptID = rr.registerReceiptID 
 Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 1    
  and rr.OperatorID = @OperatorID    
  AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL     
  AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic  
  and (@StaffID = 0 or rr.StaffID = @StaffID)    
  and (dpr.deviceID in (1,2,3,4,14,17) or dpr.deviceID is null) 
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;     
    

 INSERT INTO @Sales    
  (    
   packageName,productItemName,      
   staffIdNbr, price, gamingDate, sessionNbr, staffName,      
   itemQty,    
   merchandise,    
   paper, paperSalesFloor, paperSalesTotal,    
   electronic,    
   credit,    
   discount,    
   other,    
   payouts    
   , ProductTypeId    
   ,PullTab      
   ,DeviceFee , coupons   
  )    
 SELECT rd.PackageName,rdi.ProductItemName,    
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                       
   SUM(-1 * rd.Quantity * rdi.Qty),--itemQty,    
   0.0,--merchandise,    
   0.0,0.0,0.0, --paper,    
   SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),--electronic,    
   0.0,--credit,    
   0.0,--discount,    
   0.0,--other,    
   0.0--payouts    
   , rdi.ProductTypeID    
   ,0.00  
   ,0.00    ,00
 FROM RegisterReceipt rr    
  JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
  JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
  join Staff s on rr.StaffID = s.StaffID    
   join #TempDevicePerReceiptDeviceSummary  dpr on dpr.registerreceiptID = rr.registerReceiptID 
 Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 3 -- Return    
  and rr.OperatorID = @OperatorID    
  AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL     
  AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)     
  and (@StaffID = 0 or rr.StaffID = @StaffID)     
  and (dpr.deviceID in (1,2,3,4,14,17) or dpr.deviceID is null) 
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;     
  


 --      
 -- Insert Credit Rows      
 --    
 INSERT INTO @Sales    
  (    
   packageName,productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,           
   itemQty,    
   merchandise,    
   paper, paperSalesFloor, paperSalesTotal,    
   electronic,    
   credit,    
   discount,    
   other,    
   payouts    
   , ProductTypeId         
   ,PullTab  
   ,DeviceFee , coupons  
  )    
 SELECT rd.PackageName,rdi.ProductItemName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                         
   SUM(rd.Quantity * rdi.Qty),    
   0.00,    
   0.00, 0.0, 0.0,     
   0.00,    
   SUM(rd.Quantity * rdi.Qty * rdi.Price),    
   0.00,    
   0.00,    
   0.00    
   , rdi.ProductTypeID    
 ,0.00  
 ,0.00    ,00
 FROM RegisterReceipt rr    
  JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
  JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
  join Staff s on rr.StaffID = s.StaffID    
 Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 1    
  and rr.OperatorID = @OperatorID    
  AND rdi.ProductTypeID BETWEEN 10 AND 13    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL    
  and (@StaffID = 0 or rr.StaffID = @StaffID)    
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;             
    

    
 INSERT INTO @Sales    
  (    
   packageName,productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,          
   itemQty,    
   merchandise,    
   paper, paperSalesFloor, paperSalesTotal,    
   electronic,    
   credit,    
   discount,    
   other,    
   payouts    
   , ProductTypeId     
   ,PullTab      
   ,DeviceFee , coupons  
  )    
 SELECT rd.PackageName,rdi.ProductItemName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                         
   SUM(-1 * rd.Quantity * rdi.Qty),    
   0.00,    
   0.00, 0.0, 0.0,    
   0.00,    
   SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),    
   0.00,    
   0.00,    
   0.00    
   , rdi.ProductTypeID  
   ,0.00    
   ,0.00    ,00
 FROM RegisterReceipt rr    
  JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
  JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
  join Staff s on rr.StaffID = s.StaffID    
 Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 3 -- Return    
  and rr.OperatorID = @OperatorID    
  AND rdi.ProductTypeID BETWEEN 10 AND 13    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL    
  and (@StaffID = 0 or rr.StaffID = @StaffID)    
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;            
    
    
 --      
 -- Insert Bingo Other Rows      
 --    
 INSERT INTO @Sales    
  (    
   packageName,productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,           
   itemQty,    
   merchandise,    
   paper, paperSalesFloor, paperSalesTotal,    
   electronic,    
   credit,    
   discount,    
   other,    
   payouts    
   , ProductTypeId       
   ,PullTab    
   ,DeviceFee , coupons  
  )    
 SELECT rd.PackageName,rdi.ProductItemName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                    
   SUM(rd.Quantity * rdi.Qty),    
   0.00,    
   0.00, 0.0, 0.0,     
   0.00,    
   0.00,    
   0.00,    
   SUM(rd.Quantity * rdi.Qty * rdi.Price),    
   0.00    
   , rdi.ProductTypeID    
   ,0.00  
   ,0.00    ,00
 FROM RegisterReceipt rr    
  JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
  JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
  join Staff s on rr.StaffID = s.StaffID    
 Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 1    
  and rr.OperatorID = @OperatorID    
  AND (rdi.ProductTypeID IN ( 8, 9, 15) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))     
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL    
  and (@StaffID = 0 or rr.StaffID = @StaffID)    
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;           
    
    
 INSERT INTO @Sales    
  (    
   packageName,productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731    
   itemQty,    
   merchandise,    
   paper, paperSalesFloor, paperSalesTotal,    
   electronic,    
   credit,    
   discount,    
   other,    
   payouts    
   , ProductTypeId         
  ,PullTab  
  ,DeviceFee , coupons  
  )    
 SELECT rd.PackageName,rdi.ProductItemName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731    
   SUM(-1 * rd.Quantity * rdi.Qty),    
   00.00,    
   0.00, 0.0, 0.0,     
   0.00,    
   0.00,    
   0.00,    
   SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),    
   0.00    
   , rdi.ProductTypeID    
 ,0.00  
 ,0.00    ,00
 FROM RegisterReceipt rr    
  JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
  JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
  join Staff s on rr.StaffID = s.StaffID    
 Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 3 -- Return    
  and rr.OperatorID = @OperatorID    
  AND (rdi.ProductTypeID IN (8, 9, 15, 17) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL   
  and (@StaffID = 0 or rr.StaffID = @StaffID)     
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;            
    
       

  --DISCOUNT
    
   select   
  
    isnull(rdi.ProductItemName, dt.DiscountTypeName /*'discount fix'*/)ProductItemName,   
 rr.StaffID, isnull(rdi.Price,DiscountAmount) Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName StaffName,                     
    rr.SoldFromMachineID,  
  
    case when TransactionTypeId = 1 then sum(rd.Quantity * isnull(rdi.Qty,1))  
         when TransactionTypeId = 3 then sum(-1 * rd.Quantity * isnull(rdi.Qty,1))  
    end ItemQty,  
 case when rr.TransactionTypeId = 1 then sum(rd.Quantity * isnull(rdi.Qty,1) *  isnull(rdi.Price,DiscountAmount))  
      when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * isnull(rdi.Qty,1) * isnull(rdi.Price,DiscountAmount))  
 end Discount  
 , rr.TransactionNumber,
	rdi.ProductTypeID, 
	rd.PackageName      
  into #b  
 ----DiscountAmount   
from RegisterReceipt rr  
 join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 left join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)  
 left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )  
 join Staff s on rr.StaffID = s.StaffID  
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3)  
 and rr.OperatorID = @OperatorID  
 and ((rdi.ProductTypeID = 14 and rdi.ProductItemName LIKE '%Discount%') or (dt.DiscountTypeID  is not null))  
 and (@Session = 0 or sp.GamingSession = @Session)  
    and (@StaffID = 0 or rr.StaffID = @StaffID)
 and rd.VoidedRegisterReceiptID IS NULL  
   
group by rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate  
        ,sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID  
        ,rr.TransactionTypeId, DiscountAmount, dt.DiscountTypeName,rr.TransactionNumber, rdi.ProductTypeID, rd.PackageName      
order by rr.TransactionNumber asc  
  
    
   INSERT INTO @Sales    
  (    
   packageName,productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731    
   itemQty,    
   merchandise,    
   paper, paperSalesFloor, paperSalesTotal,    
   electronic,    
   credit,    
   discount,    
   other,    
   payouts    
   , ProductTypeId         
  ,PullTab  
    ,DeviceFee , coupons  
  )  
  select   
          
        Case when ProductTypeID = 14 then PackageName	
		Else 'Discounts' End, 
        ProductItemName+' '+ cast(Price as varchar(50)) ,  
        StaffID,		
        price,/*null*/ 
        GamingDate,
        GamingSession,	
        StaffName,
        SUM(ItemQty),   
       00.00,00.00,00.00,00.00,00.00,00.00, /*COUNT(itemQty) **/  sum(Discount) ,00.00,00.00,/*null*/ ProductTypeID /*DE11712*/,00.00,00.00  
         ,00
        from #b  
        group by ProductItemName, Price, GamingDate, GamingSession, Discount, ProductTypeID, PackageName, StaffID, StaffName  
    
  drop Table #b  
     
  INSERT INTO @Sales    
  (    
   packageName,    
   productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,        
   itemQty,    
   merchandise,    
   paper, paperSalesFloor, paperSalesTotal,        
   electronic,    
   credit,    
 discount,    
   other,    
   payouts    
   , ProductTypeId    
   ,PullTab       
   ,DeviceFee , coupons  
  )    
 SELECT /*(rd.PackageName*/'Device Fees' ,    
   /*rdi.ProductItemName*/d.DeviceType+' Fee',      
   rr.StaffID, 0.00, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   
0,  
   0.00,  
   0.00, 0.00, 0.00,    
   0.00,    
   0.00,    
   0.00,    
   0.00,    
   0.00    
   ,null   
 ,0.00  
  ,rr.DeviceFee     ,00
   
 FROM RegisterReceipt rr  
 --JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 left JOIN Staff s ON (s.StaffID = rr.StaffID)  
  left join Device d on d.DeviceID = rr.DeviceID   
  left join (select distinct(RegisterReceiptID), SessionPlayedID   from RegisterDetail) rd on rd.RegisterReceiptID = rr.RegisterReceiptID    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)   
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 1  
 and rr.OperatorID = @OperatorID  
 AND rr.DeviceFee IS NOT NULL  
 AND rr.DeviceFee <> 0   
 AND EXISTS (SELECT * FROM RegisterDetail WHERE RegisterReceiptID = rr.RegisterReceiptID AND VoidedRegisterReceiptID IS NULL)  
    and (@Session = 0 or sp.GamingSession = @Session)  
    and (@StaffID = 0 or rr.StaffID = @StaffID)
  
 
       
  --*PAPER INVENTORY*
 insert @Sales    
 (    
  packageName,productItemName,    
  staffIdNbr, price, gamingDate, sessionNbr, staffName,         
  itemQty,    
  merchandise,    
  paper, paperSalesFloor, paperSalesTotal,    
  electronic,    
  credit,    
  discount,    
  other,    
  payouts    
  , ProductTypeId         
 ,PullTab  
 ,DeviceFee , coupons  
 )    
 select     
  PackageName, ItemName, fps.StaffID, Price, GamingDate, SessionNo    
  , s.LastName + ', ' + s.FirstName -- staffname    
  , Qty    
  , 0    
  , RegisterPaper, FloorPaper, RegisterPaper + FloorPaper    
  , 0, 0, 0, 0, 0    
  , ProdTypeID    
  , 0.00  
  ,0.00    ,00
 from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps    
 join Staff s on fps.StaffID = s.StaffID
    and (@StaffID = 0 or s.StaffID = @StaffID)      
  
  
  
  --**PAPER PULLTAB**   
insert @Sales    
 (    
  packageName,productItemName,    
  staffIdNbr, price, gamingDate, sessionNbr, staffName,      
  itemQty,    
  merchandise,    
  paper, paperSalesFloor, paperSalesTotal,    
  electronic,    
  credit,    
  discount,    
  other,    
  payouts    
  , ProductTypeId         
 ,PullTab  
 ,DeviceFee , coupons  
 )   
 select     
  PackageName, ItemName, fps.StaffID, Price, GamingDate, SessionNo    
  , s.LastName + ', ' + s.FirstName -- staffname    
  , Qty    
  , 0    
  ,0,0,0
  , 0, 0, 0, 0, 0    
  , ProdTypeID    
  , RegisterPulltab + FloorPulltab 
  ,0.00    ,00
 from dbo.FindPulltabSales(@OperatorID, @StartDate, @EndDate, @Session) fps    
 join Staff s on fps.StaffID = s.StaffID
    and (@StaffID = 0 or s.StaffID = @StaffID)  

       
   
  select * into #a from @Sales  where (staffIdNbr = @StaffID or @StaffID = 0)    
 order by packageName, productItemName, gamingDate, sessionNbr, staffIdNbr;    
  
  
select row_number() over (order by GamingDate asc) as ID  , * into #c from #a   
  
declare @id int declare @gamingDate datetime  declare k cursor    
for  
select min(id), gamingDate  from #c group by gamingDate   
open k fetch next from k into @id, @gamingdate   
while @@fetch_status = 0  
begin  
  

  
update #c    
set Tax = t.tax  
from (select sum(rd.SalesTaxamt * rd.Quantity)tax 
FROM RegisterReceipt rr    
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
 JOIN Staff s ON (s.StaffID = rr.StaffID)    
Where       
  rr.SaleSuccess = 1    
 and rr.TransactionTypeID IN (1, 3)    
 and rd.VoidedRegisterReceiptID IS NULL     
 and (@OperatorID = 0 or rr.OperatorID = @OperatorID )    
 And (@Session = 0 or sp.GamingSession = @Session)    
    and (@StaffID = 0 or rr.StaffID = @StaffID)   
    and rr.GamingDate = @gamingDate   
      -- Machine Mode must print activity for all staff    
  group by rr.GamingDate) t  
where id = @id and gamingDate = @gamingDate   
  
  
fetch next from k into @id, @gamingdate  
end  
close k deallocate k  
 
select   
		productItemName as Product,    
		gamingDate, 
		sessionNbr as Session, 
		Sum(itemQty) as Qty,    
		Sum(merchandise) as Merchandise,    
		Sum(paperSalesTotal) as Paper,        
		Sum(electronic) as Electronic,    
		Sum(other) as BingoOther,		
		Sum(discount) as Discount,    
		Sum(PullTab) as PullTabs,
		Sum(merchandise) + Sum(paperSalesTotal) + Sum(Electronic) + Sum(other) + Sum(Discount) + Sum(PullTab) as Sales,
		Sum (coupons)as Coupons
from #c
Group By gamingDate, sessionNbr, productItemName
Order By gamingDate, sessionNbr, productItemName  

drop table #a  
drop table #c   
drop table #TempDevicePerReceiptDeviceSummary
   


















GO


