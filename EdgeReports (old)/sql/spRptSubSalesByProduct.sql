USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubSalesByProduct]    Script Date: 12/26/2012 15:15:04 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSubSalesByProduct]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSubSalesByProduct]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubSalesByProduct]    Script Date: 12/26/2012 15:15:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


  
  
  
  
  
  
  
  
CREATE proc [dbo].[spRptSubSalesByProduct]   
--===================================================  
-- Author:  Karlo Camacho  
-- Date:  12/21/2012  
-- 12/21/2012:  total sum of electronic sales is not correct - FIXED  
--====================================================  
  
(  
--declare  
@OperatorID  as int,  
@StartDate  as datetime,  
@EndDate  as datetime,  
@StaffID  as int,  
@Session  as int  
)  
  
as  
  
  
----TEST START  
--declare  
--@OperatorID  as int,  
--@StartDate  as datetime,  
--@EndDate  as datetime,  
--@StaffID  as int,  
--@Session  as int  
  
  
--set @OperatorID = 1   
--set @StartDate = '01/01/2000 00:00:00'  
--set @EndDate = '12/31/2020 00:00:00'  
--set @StaffID = 0  
--set @Session = 0  
------ENDTEST  
  
set @StaffID = isnull(@StaffID, 0);  
set @Session = isnull(@Session, 0);  
  
  
  
declare @CashMethod int;  
select @CashMethod = CashMethodID from Operator  
where OperatorID = @OperatorID;  
  
  --select * from Operator 
  --select * from CashMethod where CashMethodID = 3
  
----------------------------------  
--**PAPER**--  
declare @SalesActivity table  
(  
 productItemName  nvarchar(64),  
 staffIdNbr          int,            -- DE7731  
 staffName           nvarchar(64),  
 soldFromMachineId   int,  
 itemQty       int,            -- TC822  
 issueQty   int,  
 returnQty   int,  
 skipQty    int,  
 damageQty   int,    
 pricePaid           money,  
 price               money,          -- DE7731  
 gamingDate          datetime,       -- DE7731  
 sessionNbr          int,            -- DE7731  
 paper    money,          -- original field, represents paper sales made at a register  
 paperSalesFloor  money,          -- DE7731  
 paperSalesTotal  money           -- DE7731  
);  
  
insert @SalesActivity  
(  
 productItemName  
    , staffIdNbr, staffName  
    , soldFromMachineId  
 , price, gamingDate, sessionNbr  
 , itemQty  
 , paper, paperSalesFloor, paperSalesTotal  
)  
select   
 ItemName  
 , fps.StaffID, s.LastName + ', ' + s.FirstName  
 , fps.soldFromMachineId  
 , Price, GamingDate, SessionNo  
 , Qty  
 , RegisterPaper, FloorPaper, RegisterPaper + FloorPaper  
from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps  
    join Staff s on fps.StaffID = s.StaffID  
where   
    (@CashMethod <> 2 and (@StaffID = 0 or s.StaffID = @StaffID))    -- Machine Mode must print activity for all staff  
     or ((@CashMethod = 2 /*and @MachineID =or fps.soldFromMachineId = @MachineID 0*/ )   
     or (@CashMethod = 2 and ISNULL(fps.soldFromMachineId,-1) = -1))   
select   
(sum(paper) + sum(paperSalesFloor)) Paper into #paper  
from @SalesActivity  
  
--------------------------------------------------  
--**Electronic**--  
  
  
create table #TempRptSalesByDeviceTotals  
(  
 productItemName  nvarchar(128),  
 deviceID   int,  
 deviceName   nvarchar(64),  
 staffIdNbr          int,              
 staffLastName       nvarchar(64),  
 staffFirstName      nvarchar(64),  
 soldFromMachineId   int,  
 price               money,            
 gamingDate          datetime,         
 sessionNbr          int,              
 itemQty    int,          
 electronic   money  
);  
   
-- Removed script (A) knc 12/26/2012  
-- Populate Device Lookup Table  
--  
--create table #TempDevicePerReceipt  
--(  
--     registerReceiptID int  
-- ,deviceID   int  
--);  
   
--insert into #TempDevicePerReceipt  
--    (registerReceiptID  
-- ,deviceID)  
--select  
--     rr.RegisterReceiptID  
--    ,d.DeviceID  
--from RegisterReceipt rr  
--    join RegisterDetail rd on rr.RegisterReceiptID=  rd.RegisterReceiptID   
-- left join  Device d on d.DeviceID = rr.DeviceID --12/21/2012 - knc -- change inner join to left join    
--    left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)  
--where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)  
--    and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)  
--    and rd.VoidedRegisterReceiptID IS NULL  
--    and rr.OperatorID = @OperatorID  
--    and (@StaffID = 0 or rr.StaffID = @StaffID)  
--    and (@Session = 0 or sp.GamingSession = @Session)  
--    and rr.SaleSuccess = 1 --DE10603 
--group by d.DeviceID, rr.RegisterReceiptID  
  --end removed script (A)
  
  
  --Added script (A) knc - 12/26/2012  
 create table #TempDevicePerReceipt   
  (   registerReceiptID INT,  deviceID   INT,  soldToMachineID  INT,   unitNumber   INT  )  
 
     INSERT INTO #TempDevicePerReceipt 
 (  registerReceiptID,  deviceID, soldToMachineID,   unitNumber   )  

SELECT rr.RegisterReceiptID,  
  (SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),  
  (SELECT TOP 1 ulSoldToMachineID FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),  
  (SELECT TOP 1 ulUnitNumber FROM UnLockLog WHERE ulRegisterReceiptID = rr.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL AND ulDeviceID IS NOT NULL ORDER BY ulPackLoginAssignDate DESC)  
FROM RegisterReceipt rr  
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
  --End Script (A)
   
-- Insert Electronic Rows    
--  
insert into #TempRptSalesByDeviceTotals  
(  
 productItemName,  
 deviceID,  
 deviceName,  
 staffIdNbr, price, gamingDate, sessionNbr, staffLastName ,staffFirstName,         
 soldFromMachineId,  
 itemQty,   
 electronic   
)  
select   
    rdi.ProductItemName,  
 d.DeviceID,  
 isnull(d.DeviceType, 'Pack'),  
 rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName ,s.FirstName,                     
 rr.SoldFromMachineID,  
 sum(rd.Quantity * rdi.Qty),--itemQty,   
 sum(rd.Quantity * rdi.Qty * rdi.Price) --electronic,  
from RegisterReceipt rr  
 join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)  
 join #TempDevicePerReceipt dpr on (dpr.registerReceiptID = rr.RegisterReceiptID)  
 left join Device d on (d.DeviceID = dpr.deviceID)  
 join Staff s on rr.StaffID = s.StaffID  
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 1  
 and rr.OperatorID = @OperatorID  
 and rdi.ProductTypeID in (1, 2, 3, 4, 5)  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID is null   
 and (rdi.CardMediaID = 1 or rdi.CardMediaID is null) -- Electronic  
    and (@StaffID = 0 or rr.StaffID = @StaffID) 
      and (dpr.deviceID in (1,2,3,4,14) or dpr.deviceID is null) --added 12/26/2012 knc 
    --and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )      
group by rdi.ProductItemName, d.DeviceID, d.DeviceType, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,rr.RegisterReceiptID;   
  
insert into #TempRptSalesByDeviceTotals  
(  
 productItemName,  
 deviceID,  
 deviceName,  
 staffIdNbr, price, gamingDate, sessionNbr, staffLastName ,staffFirstName,         
 soldFromMachineId,  
 itemQty,  
 electronic  
)  
select   
    rdi.ProductItemName,  
 d.DeviceID,  
 isnull(d.DeviceType, 'Pack'),  
 rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                      
 isnull(rr.SoldFromMachineID, 0) [SoldFromMachineID],  
 sum(-1 * rd.Quantity * rdi.Qty),--itemQty,  
 sum(-1 * rd.Quantity * rdi.Qty * rdi.Price)--electronic,  
from RegisterReceipt rr  
 join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)  
 join #TempDevicePerReceipt dpr on (dpr.registerReceiptID = rr.RegisterReceiptID)  
 left join Device d on (d.DeviceID = dpr.deviceID)  
 join Staff s on rr.StaffID = s.StaffID  
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 3 -- Return  
 and rr.OperatorID = @OperatorID  
 and rdi.ProductTypeID in (1, 2, 3, 4, 5)  
 and (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID is null   
 and (rdi.CardMediaID = 1 or rdi.CardMediaID is null) -- Electronic  
    and (@StaffID = 0 or rr.StaffID = @StaffID)  
      and (dpr.deviceID in (1,2,3,4,14) or dpr.deviceID is null) --added 12/26/2012 knc 
   -- and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )      
group by rdi.ProductItemName, d.DeviceID, d.DeviceType, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,rr.RegisterReceiptID;   
  
update s  
    set s.itemQty=d.ProductCount  
    from #TempRptSalesByDeviceTotals s  
    inner join (select  deviceID, count(*) as ProductCount   
                from #TempDevicePerReceipt  
                group by deviceID) d  
    on s.deviceID = d.deviceID  
  
select   
    --staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr,deviceID,deviceName, soldFromMachineId  
    --, isnull(Max(itemQty),0) itemQty  
   isnull(SUM(electronic),0) electronic into #Electronic  
 from #TempRptSalesByDeviceTotals  
 --group by staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr,deviceID,deviceName, soldFromMachineId  
 --ORDER BY staffIdNbr,GamingDate,sessionNbr;  
  
--drops  
drop table #TempRptSalesByDeviceTotals  
drop table #TempDevicePerReceipt  
  
--------------------------------  
--**Bingo Other  
declare @SalesActivity2 table  
(  
 productItemName  nvarchar(64),  
 staffIdNbr          int,            -- DE7731  
 staffName           nvarchar(64),  
 soldFromMachineId   int,  
 itemQty       int,            -- TC822  
 issueQty   int,  
 returnQty   int,  
 skipQty    int,  
 damageQty   int,    
 pricePaid           money,  
 price               money,          -- DE7731  
 gamingDate          datetime,       -- DE7731  
 sessionNbr          int,            -- DE7731  
 other    money  
);  
  
  
insert into @SalesActivity2  
(  
 productItemName,  
 staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731  
    soldFromMachineId,  
 itemQty,  
 other  
)  
select   
    rdi.ProductItemName,   
 rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,  
    rr.SoldFromMachineID,  
 case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty)  
      when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty)  
 end,  
 case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty * rdi.Price)  
      when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty * rdi.Price)  
 end  
from RegisterReceipt rr  
 join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)  
 left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)  
 join Staff s on rr.StaffID = s.StaffID  
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
 and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and (rr.TransactionTypeID = 1 or rr.TransactionTypeID = 3)  
 and rr.OperatorID = @OperatorID  
 /*and (rdi.ProductTypeID = 14 and RDI.ProductItemName not like 'Discount%')*/  
   AND (rdi.ProductTypeID IN (6, 8, 9, 15/*, 17*/) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))  
 and (@Session = 0 or sp.GamingSession = @Session)  
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff  
 and rd.VoidedRegisterReceiptID is null  
     
group by rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate  
        ,sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID  
        ,rr.TransactionTypeId;         -- DE7731  
  
  
  
  
-- PRODUCTION     
select   
    
     sum(other) as [Bingo Other] into #BingoOther  
from @SalesActivity2  
  
--------------------------------------------  
--**Pulltab**--  
  
declare @SalesActivity3 table  
(  
 productItemName  nvarchar(64),  
 staffIdNbr          int,            -- DE7731  
 staffName           nvarchar(64),  
 soldFromMachineId   int,  
 itemQty       int,            -- TC822  
 issueQty   int,  
 returnQty   int,  
 skipQty    int,  
 damageQty   int,    
 pricePaid           money,  
 price               money,          -- DE7731  
 gamingDate          datetime,       -- DE7731  
 sessionNbr          int,            -- DE7731  
 pulltabs   money       
);  
  
insert into @SalesActivity3  
(  
 productItemName,  
 staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731  
    soldFromMachineId,  
 itemQty,  
 pulltabs  
)  
select   
    rdi.ProductItemName,   
 rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731  
    rr.SoldFromMachineID,  
 case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty)  
      when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty)  
 end,  
 case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty * rdi.Price)  
      when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty * rdi.Price)  
 end  
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff  
 and rd.VoidedRegisterReceiptID IS NULL  
  --  and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )      
group by rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate  
        ,sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID  
        ,rr.TransactionTypeId;         -- DE7731  
  
-- PRODUCTION     
select sum(pulltabs) as [Pull Tabs] into #PullTabs  
from @SalesActivity3  
  
--------------------------------------------------------------  
--**Consessions and Merchandise**--  
  
declare @SalesActivity4 table  
(  
 productItemName  nvarchar(64),  
 staffIdNbr          int,            -- DE7731  
 staffName           nvarchar(64),  
 soldFromMachineId   int,  
 itemQty       int,            -- TC822  
 issueQty   int,  
 returnQty   int,  
 skipQty    int,  
 damageQty   int,    
 pricePaid           money,  
 price               money,          -- DE7731  
 gamingDate          datetime,       -- DE7731  
 sessionNbr          int,            -- DE7731  
 merchandise   money  
);  
  
  
insert into @SalesActivity4  
(  
 productItemName,  
 staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731  
 soldFromMachineId,  
 itemQty,  
 merchandise  
)  
select   
        rdi.ProductItemName,   
  rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   -- DE7731  
        rr.SoldFromMachineID,  
  case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty)  
       when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty)  
  end,  
  case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty * rdi.Price)  
       when rr.TransactionTypeId = 3 then sum (-1 * rd.Quantity * rdi.Qty * rdi.Price)  
  end  
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
 and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2) -- DE8882  
 and rd.VoidedRegisterReceiptID IS NULL  
 and (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic  
  --  and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )      
GROUP BY  rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate  
        , sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID  
        , rr.TransactionTypeId;  
  
-- PRODUCTION     
select   
        
    sum(merchandise) as [Con & Mdse] into #ConMdse  
from @SalesActivity4  
  
  
--------------------------------------------------  
--** Device Fees**------  
SELECT   
/*rr.OperatorID, rr.GamingDate,  
 (SELECT TOP 1 ISNULL(sp2.GamingSession, 0) FROM RegisterReceipt rr2  
  JOIN RegisterDetail rd2 ON (rr2.RegisterReceiptID = rd2.RegisterReceiptID)  
  LEFT JOIN SessionPlayed sp2 ON (sp2.SessionPlayedID = rd2.SessionPlayedID)  
  WHERE rr2.RegisterReceiptID = rr.RegisterReceiptID  
  ORDER BY sp2.GamingSession),  
    s.StaffID, s.LastName, s.FirstName,  
    rr.SoldFromMachineID,*/  
 sum(isnull(rr.DeviceFee, 0)) [Device Fees] into #DeviceFees  
   /* , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0*/  
      
FROM RegisterReceipt rr  
 JOIN Staff s ON (s.StaffID = rr.StaffID)
   left join Device d on d.DeviceID = rr.DeviceID   
  left join (select distinct(RegisterReceiptID), SessionPlayedID   from RegisterDetail) rd on rd.RegisterReceiptID = rr.RegisterReceiptID    
  LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID) /*--3 line added to match the main report 12/26/2012 -knc
																		  --  "spRptSalesByPackageTotals - SP" end*/
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 1  
 and rr.OperatorID = @OperatorID  
 AND rr.DeviceFee IS NOT NULL  
 AND rr.DeviceFee <> 0   
 AND EXISTS (SELECT * FROM RegisterDetail WHERE RegisterReceiptID = rr.RegisterReceiptID AND VoidedRegisterReceiptID IS NULL)  
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff  
    and (@Session = 0 or sp.GamingSession = @Session)
   -- and (/*@MachineID = 0 or rr.SoldFromMachineID = @MachineID  or*/ @CashMethod = 2);  
      
      
----------------------------------  
--**Discount**------  
  
declare @SalesActivity5 table  
(  
 productItemName  nvarchar(64),  
 staffIdNbr          int,            -- DE7731  
 staffName           nvarchar(64),  
 soldFromMachineId   int,  
 itemQty       int,            -- TC822  
 issueQty   int,  
 returnQty   int,  
 skipQty    int,  
 damageQty   int,    
 pricePaid           money,  
 price               money,          -- DE7731  
 gamingDate          datetime,       -- DE7731  
 sessionNbr          int,            -- DE7731  
 discount   money  
);  
  
-- ============================================================================  
-- Retrieve all of the discounts that were used or returned  
-- ============================================================================  
insert into @SalesActivity5  
(  
 productItemName,  
 staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731  
    soldFromMachineId,  
 itemQty,  
 discount  
)  
select --*  
    isnull(rdi.ProductItemName, dt.DiscountTypeName /*'discount fix'*/)ProductItemName,   
 rr.StaffID, isnull(rdi.Price,DiscountAmount), rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731  
    rr.SoldFromMachineID,  
   -- rd.Quantity ,rdi.Qty,isnull(rdi.Price,DiscountAmount)  
    case when TransactionTypeId = 1 then sum(rd.Quantity * isnull(rdi.Qty,1))  
         when TransactionTypeId = 3 then sum(-1 * rd.Quantity * isnull(rdi.Qty,1))  
    end,  
 case when rr.TransactionTypeId = 1 then sum(rd.Quantity * isnull(rdi.Qty,1) *  isnull(rdi.Price,DiscountAmount))  
      when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * isnull(rdi.Qty,1) * isnull(rdi.Price,DiscountAmount))  
 end  
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff  
 and rd.VoidedRegisterReceiptID IS NULL  
 --   and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )      
group by rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate  
        ,sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID  
        ,rr.TransactionTypeId, DiscountAmount, dt.DiscountTypeName ;  
  
 --PRODUCTION     
select   
        
     sum(discount) as Discount into #Discount  
from @SalesActivity5  
  
----------------------------------------------  
--**Tax Collected**-------  
  
SELECT   
 SUM(rd.SalesTaxAmt * rd.Quantity) Tax into #Tax -- DE8480  
  
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)  
 JOIN Staff s ON (s.StaffID = rr.StaffID)  
Where   
    (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID IN (1, 3)  
 and rd.VoidedRegisterReceiptID IS NULL   
 and (@OperatorID = 0 or rr.OperatorID = @OperatorID )  
 And (@Session = 0 or sp.GamingSession = @Session)  
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff  
    --and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )      
--GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, s.StaffID, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;  
  
------------------------------------------  
--** Void **--  
SELECT   
  
COUNT(rr.RegisterReceiptID) V_Qty  
,SUM(rd.Quantity * rdi.Qty * rdi.Price) -  
isnull((SELECT SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)   
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)   
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 3  
 and rr.OperatorID = @OperatorID  
 And (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NOT NULL),0) Voids into #Voids  
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)   
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 1  
 and rr.OperatorID = @OperatorID  
 And (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NOT NULL  
   
  
---------------------------------------  
--**Returns**--  
SELECT   
COUNT(rr.RegisterReceiptID) R_Qty  
,SUM(rd.Quantity * rdi.Qty * rdi.Price) [Returns] into #Returns  
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)   
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 3  
 and rr.OperatorID = @OperatorID  
 And (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL  
   
  
  
select   
(select Paper  from #paper)Paper,  
(select electronic  from #Electronic)Electronic,  
(select [Bingo Other]  from #BingoOther )[Bingo Other]   
,(select [Pull Tabs]  from #PullTabs) [Pull Tabs]   
,(select [Con & Mdse]  from #ConMdse)  [Con & Mdse]   
,(Select [Device Fees] from [#DeviceFees] )[Device Fees]  
,(select Discount from #Discount) [Less:Discount]   
,(select Tax  from #Tax ) [Tax Collected]   ,(select V_Qty  from #Voids ) V_Qty   
 ,(select Voids from #Voids) Voids   
 ,(select R_qty from #Returns) R_qty  
 ,(select [returns] from #Returns) [Returns]  
  
  
   
  
drop table #paper , #Electronic, #BingoOther ,#PullTabs, #ConMdse    
,#DeviceFees ,#Discount , #Tax , #Voids , #Returns  
    
    
  
  
  
  
  
  
  
  
GO


