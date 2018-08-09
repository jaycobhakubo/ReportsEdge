USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByPackageTotals]    Script Date: 12/26/2012 15:13:19 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSalesByPackageTotals]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSalesByPackageTotals]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSalesByPackageTotals]    Script Date: 12/26/2012 15:13:19 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

  
  
--exec spRptSalesByPackageTotals 1,'9/23/2009 00:00:00','10/15/2009 00:00:00',0,0  
    
    
CREATE PROCEDURE  [dbo].[spRptSalesByPackageTotals]     
   
 --=============================================    
 --Author:  Louis Landerman    
 --Description: <>    
 --03/23/2011 BJS: TC822 fixes for DE7727     
 --05/19/2011 BJS: DE8075 restore original discounts    
 --06/21/2011 bjs: DE8654 missing floor workers    
 --06/28/2011 bjs: combined all paper sales logic into a udf.    
 --07/09/2012 knc: DE10591 fixed   
 --12/19/2012 knc: Date not showing on Discount transaction -tested fixed - FIXED
 --12/26/2012 knc: Electronic sales computation is wrong - FIXED
 --12/26/2012 knc: Discount calculation not matching - FIXED
 --=============================================    
  
  
 @OperatorID  AS INT,    
 @StartDate  AS DATETIME,    
 @EndDate  AS DATETIME,    
 @Session  AS INT    
,@StaffID as  int  
AS   
----------------------------  
--TEST START  
--declare  
--@OperatorID  as int,  
--@StartDate  as datetime,  
--@EndDate  as datetime,  
--@StaffID  as int,  
--@Session  as int  
  
  
--set @OperatorID = 1   
--set @StartDate = '01/01/2000 00:00:00'  
--set @EndDate = '01/01/2013 00:00:00'  
--set @StaffID = 0  
--set @Session = 0  
--TEST END  
-------------------------------   
  
--set @StaffID = isnull(@StaffID, 0);??  
--set @Session = isnull(@Session, 0);??  
  
  
  
  
     
SET NOCOUNT ON    
    
--begin    
 -- Results table: use table var for performance    
  declare @Sales table    
 (    
  packageName         NVARCHAR(64),    
  productItemName  NVARCHAR(64),    
  staffIdNbr          int,            -- DE7731    
  staffName           NVARCHAR(64),    
  itemQty       INT,            -- TC822    
  price               money,          -- DE7731    
  gamingDate          datetime,       -- DE7731    
  sessionNbr          int,            -- DE7731    
  merchandise   MONEY,    
  paper    MONEY,          -- original field, represents paper sales made at a register    
  paperSalesFloor  MONEY,          -- DE7731    
  paperSalesTotal  MONEY,          -- DE7731    
  electronic   MONEY,    
  credit    MONEY,    
  discount   MONEY,    
  other    MONEY,    
  payouts    MONEY         
  , ProductTypeId     int             -- bjs 5/25/11 Crystal Ball Bingo paper products are non-inventory paper!    
 ,PullTab money  
 ,DeviceFee money  
 ,Tax money  
 );    
    
      
      
 --      
 -- Insert merchandise Rows      
 --    
 INSERT INTO @Sales    
  (    
   packageName,    
   productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731    
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
   ,DeviceFee       
  )    
 SELECT rd.PackageName,    
   rdi.ProductItemName,     
   --NULL,    
   --'',    
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   -- DE7731    
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
 and (@StaffID = 0 or rr.StaffID = @StaffID /*or @CashMethod = 2*/) -- DE8882  
 and rd.VoidedRegisterReceiptID IS NULL  
 and (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic  
  --  and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )      
GROUP BY  rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate  
        , sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID  
        , rr.TransactionTypeId, rd.PackageName,rdi.ProductTypeID   
          
--ELECTRONIC SALES
--Added script (A) knc - 12/26/2012  
  
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
  --End Added Script (A)
  
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
   ,DeviceFee   
  )    
 SELECT rd.PackageName,rdi.ProductItemName,    
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731    
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
   ,00  
 FROM RegisterReceipt rr    
  JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
  JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
  join Staff s on rr.StaffID = s.StaffID    
   join #TempDevicePerReceiptDeviceSummary  dpr on dpr.registerreceiptID = rr.registerReceiptID --added 12/26/2012 knc
 Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 1    
  and rr.OperatorID = @OperatorID    
  AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL     
  AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic  
   and (@StaffID = 0 or rr.StaffID = @StaffID)    --Added 12/26/2012 knc 
      and (dpr.deviceID in (1,2,3,4,14) or dpr.deviceID is null) --added 12/26/2012 knc
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;     
    

    
 INSERT INTO @Sales    
  (    
   packageName,productItemName,    
   --deviceID,    
   --deviceName,    
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
   ,DeviceFee    
  )    
 SELECT rd.PackageName,rdi.ProductItemName,    
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731    
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
   ,0.00  
 FROM RegisterReceipt rr    
  JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
  JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
  join Staff s on rr.StaffID = s.StaffID    
   join #TempDevicePerReceiptDeviceSummary  dpr on dpr.registerreceiptID = rr.registerReceiptID --added 12/26/2012 knc
 Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 3 -- Return    
  and rr.OperatorID = @OperatorID    
  AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL     
  AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic    
     and (@StaffID = 0 or rr.StaffID = @StaffID)    --Added 12/26/2012 knc 
           and (dpr.deviceID in (1,2,3,4,14) or dpr.deviceID is null) --added 12/26/2012 knc
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;     
  

 --      
 -- Insert Credit Rows      
 --    
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
   ,DeviceFee   
  )    
 SELECT rd.PackageName,rdi.ProductItemName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731    
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
 ,0.00  
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
     and (@StaffID = 0 or rr.StaffID = @StaffID)    --Added 12/26/2012 knc 
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731    
    
    
    
    
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
   ,DeviceFee   
  )    
 SELECT rd.PackageName,rdi.ProductItemName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731    
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
   ,0.00  
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
     and (@StaffID = 0 or rr.StaffID = @StaffID)    --Added 12/26/2012 knc 
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731    
    
    
    
 -------------------------------------------------------------------------------------------------     
 -- Insert Discount Rows      
 --    
 -- DE7731: treat discounts like sales    
 /*  
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
  ,DeviceFee   
  )    
 SELECT rd.PackageName, rdi.ProductItemName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731    
   SUM(rd.Quantity * rdi.Qty),    
   0.00,    
   0.00, 0.0, 0.0,     
   0.00,    
   0.00,    
   SUM(rd.Quantity * rdi.Qty * rdi.Price),    
   0.00,    
   0.00    
   , rdi.ProductTypeID  
   ,00    
   ,0.00  
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
  AND (rdi.ProductTypeID = 14 and RDI.ProductItemName LIKE 'Discount%')    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL    
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731    
    
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
  ,DeviceFee   
  )    
 SELECT rd.PackageName, rdi.ProductItemName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731    
   SUM(-1 * rd.Quantity * rdi.Qty),    
   0.00,    
   0.00, 0.0, 0.0,     
   0.00,    
   0.00,    
   SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),    
   0.00,    
   0.00    
   , rdi.ProductTypeID    
 ,0.00  
 ,0.00  
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
  AND (rdi.ProductTypeID = 14 and rdi.ProductItemName like 'Discount%')    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL    
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731    
    
 -- FIX DE8075: Restore original discounts as well as new product-name discounts    
 --      
 -- Insert Discount Rows      
 --    
 INSERT INTO @Sales    
  (    
   packageName,     
   productItemName,    
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
  ,DeviceFee )    
 SELECT 'Discounts',    
   dt.DiscountTypeName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                         
   SUM(rd.Quantity),    
   0.00,    
   0.00, 0.0, 0.0,     
   0.00,    
   0.00,    
   SUM(rd.Quantity * rd.DiscountAmount),    
   0.00,    
   0.00    
   , 14  -- this is an original discount so make the type identical to the new discounts    
 ,0.00  
 ,0.00  
 FROM RegisterReceipt rr    
  left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )    
  left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )    
  LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )    
  left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )    
  join Staff s on rr.StaffID = s.StaffID    
 WHERE rd.DiscountTypeID IS NOT NULL     
  AND rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 1    
  and rr.OperatorID = @OperatorID    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL    
 GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;    
    
 INSERT INTO @Sales    
  (    
   packageName,    
   productItemName,    
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
  ,DeviceFee   
  )    
 SELECT 'Discounts',    
   dt.DiscountTypeName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                         
   SUM(-1 * rd.Quantity),    
   0.00,    
   0.00, 0.0, 0.0,     
   0.00,    
   0.00,    
   SUM(rd.Quantity * rd.DiscountAmount),       -- TODO should this be multiplied by -1?    
   0.00,    
   0.00    
   , 14  -- this is an original discount so make the type identical to the new discounts    
 ,0.00  
 ,0.00  
 FROM RegisterReceipt rr    
  left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )    
  left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )    
  LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )    
  left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID)    
  left join Staff s on rr.StaffID = s.StaffID    
 WHERE rd.DiscountTypeID IS NOT NULL     
  AND rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
  And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  and rr.SaleSuccess = 1    
  and rr.TransactionTypeID = 3 -- Return    
  and rr.OperatorID = @OperatorID    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL    
 GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;     
 -- END FIX DE8075  */  
    
 --      
 -- Insert Other Rows      
 --    
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
   ,DeviceFee   
  )    
 SELECT rd.PackageName,rdi.ProductItemName,     
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731    
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
   ,0.00  
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
  AND (rdi.ProductTypeID IN (6, 8, 9, 15/*, 17*/) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))    
  /*there will be a problem on bingo other calculations* - knc:9.6.2012 Please see Register closing report(SP) for fix*/  
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL    
     and (@StaffID = 0 or rr.StaffID = @StaffID)    --Added 12/26/2012 knc 
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731    
    
     

    
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
  ,DeviceFee   
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
 ,0.00  
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
  AND (rdi.ProductTypeID IN (6, 8, 9, 15, 17) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))    
  And (@Session = 0 or sp.GamingSession = @Session)    
  and rd.VoidedRegisterReceiptID IS NULL   
     and (@StaffID = 0 or rr.StaffID = @StaffID)    --Added 12/26/2012 knc  
 GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731    
    
    
    
  --DISCOUNT
    
   select --*  
  
    isnull(rdi.ProductItemName, dt.DiscountTypeName /*'discount fix'*/)ProductItemName,   
 rr.StaffID, isnull(rdi.Price,DiscountAmount) Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName StaffName,                     -- DE7731  
    rr.SoldFromMachineID,  
   -- rd.Quantity ,rdi.Qty,isnull(rdi.Price,DiscountAmount)  
    case when TransactionTypeId = 1 then sum(rd.Quantity * isnull(rdi.Qty,1))  
         when TransactionTypeId = 3 then sum(-1 * rd.Quantity * isnull(rdi.Qty,1))  
    end ItemQty,  
 case when rr.TransactionTypeId = 1 then sum(rd.Quantity * isnull(rdi.Qty,1) *  isnull(rdi.Price,DiscountAmount))  
      when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * isnull(rdi.Qty,1) * isnull(rdi.Price,DiscountAmount))  
 end Discount  
 , rr.TransactionNumber   
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
    and (@StaffID = 0 or rr.StaffID = @StaffID /*or @CashMethod = 2*/)  -- Machine Mode must print activity for all staff  
 and rd.VoidedRegisterReceiptID IS NULL  
 --   and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )      
group by rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate  
        ,sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID  
        ,rr.TransactionTypeId, DiscountAmount, dt.DiscountTypeName,rr.TransactionNumber      
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
    ,DeviceFee   
  )  
  select   
          /*ProductItemName+' '+ cast(Price as varchar(50)) ,*/  
           'Discounts',  
        ProductItemName+' '+ cast(Price as varchar(50)) ,  
        @StaffID ,price,/*null*/ GamingDate,null,null,COUNT(price),  
       -- 00.00,00.00,00.00,00.00,00.00,00.00, COUNT(price) *  Price ,00.00,00.00,null,00.00,00.00  
       00.00,00.00,00.00,00.00,00.00,00.00, /*COUNT(itemQty) **/  sum(Discount) ,00.00,00.00,null,00.00,00.00  
       --comment on line on top removed /*COUNT(itemQty) **/ and replaced with sum(Discount)--12/26/2012 knc
        from #b  
        group by ProductItemName, Price, GamingDate ,Discount 
         

  
  drop Table #b  
  
 -----------------------------------------------------------------------------------------------------    
 -- Paper sales: both register sales and inventory (floor sales)    
 --     
 --**PULLTABS**---  
 INSERT INTO @Sales    
  (    
   packageName,    
   productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731    
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
   ,DeviceFee   
  )    
 SELECT rd.PackageName,    
   rdi.ProductItemName,     
   --NULL,    
   --'',    
   rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   -- DE7731    
 case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty)  
       when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty)  
  end,  
 0.00,  
   0.00, 0.00, 0.00,    
   0.00,    
   0.00,    
   0.00,    
   0.00,    
   0.00    
   , rdi.ProductTypeID    
 ,case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty * rdi.Price)  
       when rr.TransactionTypeId = 3 then sum (-1 * rd.Quantity * rdi.Qty * rdi.Price)  
  end  ,  
  0.00  
from RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)  
 join Staff s on rr.StaffID = s.StaffID  
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sales or Returns  
 and rr.OperatorID = @OperatorID  
 and rdi.ProductTypeID = 17  
 and (@Session = 0 or sp.GamingSession = @Session)  
    and (@StaffID = 0 or rr.StaffID = @StaffID /*or @CashMethod = 2*/)  -- Machine Mode must print activity for all staff  
 and rd.VoidedRegisterReceiptID IS NULL   
GROUP BY  rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate  
        , sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID  
        , rr.TransactionTypeId, rd.PackageName,rdi.ProductTypeID   
          
           
  
   
  INSERT INTO @Sales    
  (    
   packageName,    
   productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731    
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
   ,DeviceFee   
  )    
 SELECT /*(rd.PackageName*/'Device Fees' ,    
   /*rdi.ProductItemName*/d.DeviceType+' Fee',      
   rr.StaffID, 0.00, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   -- DE7731    
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
  ,rr.DeviceFee   
   
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
    and (@StaffID = 0 or rr.StaffID = @StaffID /*or @CashMethod = 2*/)  -- Machine Mode must print activity for all staff  
 --  and (@StaffID = 0 or rr.StaffID = @StaffID /*or @CashMethod = 2*/)Removed 12/26/2012 "Duplicate" - knc   
  
 insert @Sales    
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
 ,DeviceFee   
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
  ,0.00  
 from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps    
 join Staff s on fps.StaffID = s.StaffID
    and (@StaffID = 0 or s.StaffID = @StaffID)    --Added 12/26/2012 knc ;    
    
   
  select * into #a from @Sales  where (staffIdNbr = @StaffID or @StaffID = 0)    
 order by packageName, productItemName, gamingDate, sessionNbr, staffIdNbr;    
  
  
select row_number() over (order by GamingDate asc) as ID  , * into #c from #a   
  
declare @id int declare @gamingDate datetime  declare k cursor    
for  
select min(id), gamingDate  from #c group by gamingDate   
open k fetch next from k into @id, @gamingdate   
while @@fetch_status = 0  
begin  
  
--print @gamingdate  
  
update #c    
set Tax = t.tax  
from (select sum(rd.SalesTaxamt * rd.Quantity)tax --,rr.GamingDate   
FROM RegisterReceipt rr    
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)    
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)    
 JOIN Staff s ON (s.StaffID = rr.StaffID)    
Where     
 --   (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)    
 --And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))    
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
  
 if exists (select staffidNbr from #c where staffidNbr = @StaffID)   
 --/select *   from #a order by ProductTypeId desc/  
 begin  
 select /***/  
  packageName,    
   productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731    
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
   ,DeviceFee      
,isnull(Tax, 0.00) tax  
    from #c order by   
  case when  productItemName  like '%Fee%' /*OR productItemName like '%iscoun%'*/  then productItemName  end asc    
 --/when  productItemName not like '%iscoun%' /*OR productItemName like '%iscoun%'*/  then productItemName end  asc/  
 print 'A' 
 

 
 end  
 else   
 begin  
 insert into #c (staffIdNbr, staffName, sessionNbr )  
 select StaffID,LastName+', '+FirstName, @Session from Staff WHERE StaffID = @StaffID     
 select  packageName,    
   productItemName,    
   staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731    
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
   ,DeviceFee      
,isnull(Tax, 0.00) tax   from #c order by   
 /*ProductTypeId desc*/  
  case when  productItemName  like '%Fee%' OR productItemName like '%iscoun%' then productItemName end asc  
 --/when  productItemName not like '%iscoun%' /*OR productItemName like '%iscoun%'*/  then productItemName end  asc/  
 --/SELECT * FROM #a order by ProductTypeId desc/  
 print 'B'  
  
 end  
 drop table #a  
 drop table #c   
  drop table #TempDevicePerReceiptDeviceSummary
   
  --end  
    
        
   
  
  
    
    
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
GO


