USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubVoidsTxs]    Script Date: 12/06/2012 15:53:56 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSubVoidsTxs]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSubVoidsTxs]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubVoidsTxs]    Script Date: 12/06/2012 15:53:56 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


  
CREATE PROCEDURE  [dbo].[spRptSubVoidsTxs]   

 @OperatorID AS INT,  
 @StartDate AS DATETIME,  
 @Session AS INT  

  
AS  

--declare 

--@OperatorID int,  
--@StartDate datetime,  
----@EndDate datetime,  
--@Session int  
  
--as  
--begin  


--set @OperatorID = 1
--set @StartDate = '1/1/2000 00:00:00'
----set @EndDate = '1/1/2013 00:00:00'
--set @Session = 1
   
SET NOCOUNT ON  
  
  
declare @EndDate datetime  
set @EndDate = @StartDate  
--set @EndDate = '1/1/2013 00:00:00'
  
-- FIX US1902  
-- Tricky bits here; the transaction saves the group name at the time of the transaction instead of a FK to the product group...  
--declare @groupName nvarchar(64); set @groupName = '';  
--select @groupName = GroupName from ProductGroup where ProductGroupID = @ProductGroupID;  
  
-- FIX: DE7330 - Transfers not listed and void data is wrong.  
DECLARE @ResultsTable TABLE  
(  
 RegisterReceiptID1 INT,  
 ReceiptNumber1 INT,  
 TimeStamp1 DATETIME,  
 PackNumber INT,  
 UnitNumber1 INT,  
 ReceiptTotal1 MONEY,  
 RegisterReceiptID2 INT,  
 ReceiptNumber2 INT,  
 TimeStamp2 DATETIME,  
 TransactionType NVARCHAR(64),  
 UnitNumber2 INT,  
 ReceiptTotal2 MONEY,  
 GroupName nvarchar(64),  
 DiscountAmt money,  
 SalesTaxAmt money,  
 DeviceFeeAmnt money  
);  
  
-- Gather all of the receipts that were voided  
INSERT INTO @ResultsTable  
(  
 RegisterReceiptID1,  
 ReceiptNumber1,  
 TimeStamp1,  
 PackNumber,  
 UnitNumber1,  
 ReceiptTotal1  
)  
SELECT rr.RegisterReceiptID,  
  rr.TransactionNumber,  
  rr.DTStamp,  
  rr.PackNumber,  
  rr.UnitNumber,  
  sum(rd.Quantity * rdi.Qty * rdi.Price ) + isnull(rr.DeviceFee, 0) -- DE8879  
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)  
WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 AND rr.SaleSuccess = 1  
 AND rr.TransactionTypeID IN (1, 3)   
 AND rr.OperatorID = @OperatorID  
 AND (@Session = 0 or sp.GamingSession = @Session)  
 AND EXISTS (SELECT 1 FROM RegisterDetail WHERE RegisterReceiptID = rr.RegisterReceiptID AND VoidedRegisterReceiptID IS NOT NULL)  
GROUP BY rr.RegisterReceiptID, rr.TransactionNumber, rr.DTStamp, rr.PackNumber, rr.UnitNumber, rr.DeviceFee;  
  
-- Update the voided receipts with the void times and transaction numbers  
UPDATE @ResultsTable   
SET RegisterReceiptID2 = rr.RegisterReceiptID,  
 ReceiptNumber2 = rr.TransactionNumber,  
 TimeStamp2 = rr.DTStamp,  
 TransactionType = 'Void',  
 UnitNumber2 = UnitNumber1,  
 ReceiptTotal2 = -1 * ReceiptTotal1  
FROM @ResultsTable rt  
 JOIN RegisterReceipt rr ON (rt.RegisterReceiptID1 = rr.OriginalReceiptID)  
where rr.TransactionTypeId = 2 --DE9800 make sure to only include voided transactions  
  
-- Gather all of the receipts that were transferred.  
INSERT INTO @ResultsTable  
(  
    RegisterReceiptID1  
   ,ReceiptNumber1  
   ,TimeStamp1  
   ,PackNumber  
   ,UnitNumber1  
   ,ReceiptTotal1  
   ,TransactionType  
)  
SELECT rr.RegisterReceiptID  
       ,rr.TransactionNumber  
       ,rr.DTStamp  
       ,rr.PackNumber  
       ,rr.UnitNumber  
       ,sum(rd.Quantity * rdi.Qty * rdi.Price) + isnull(rr.DeviceFee, 0)-- DE9800/ DE10025  
       ,'Transfer'  
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)  
WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 AND rr.SaleSuccess = 1  
 AND rr.TransactionTypeID IN (1, 3)  
 AND rr.OperatorID = @OperatorID  
 AND (@Session = 0 or sp.GamingSession = @Session)  
 AND EXISTS (SELECT 1 FROM RegisterReceipt WHERE OriginalReceiptID = rr.RegisterReceiptID AND TransactionTypeID = 14)  
GROUP BY rr.RegisterReceiptID, rr.TransactionNumber, rr.DTStamp, rr.PackNumber, rr.UnitNumber, rr.DeviceFee;  
  
-- Update transfers with transfer details.  
UPDATE @ResultsTable   
SET RegisterReceiptID2 = rr.RegisterReceiptID,  
 ReceiptNumber2 = rr.TransactionNumber,  
 TimeStamp2 = rr.DTStamp,  
 UnitNumber2 = rr.UnitNumber,  
    ReceiptTotal2 = 0 -- DE9800 Transfers are a 0 dollar transaction  
FROM @ResultsTable rt  
 JOIN RegisterReceipt rr ON (rt.RegisterReceiptID1 = rr.OriginalReceiptID)  
WHERE rt.TransactionType = 'Transfer'  
  
-- Find all subsequent transfers.  
DECLARE @CurrentTransferID INT  
DECLARE @OriginalPackNumber INT  
DECLARE @OriginalTotal MONEY  
  
DECLARE TransferCursor CURSOR FOR  
SELECT RegisterReceiptID2, PackNumber, ReceiptTotal1  
FROM @ResultsTable  
WHERE TransactionType = 'Transfer'  
  
-- The algorithm below depends on fact that, after a cursor is opened, any rows  
-- inserted will not be read by the cursor.  
OPEN TransferCursor  
  
FETCH NEXT FROM TransferCursor INTO @CurrentTransferID, @OriginalPackNumber, @OriginalTotal  
WHILE @@FETCH_STATUS = 0  
BEGIN  
 -- Does the current transfer have another transfer after it?  
 WHILE EXISTS(SELECT 1 FROM RegisterReceipt WHERE OriginalReceiptID = @CurrentTransferID AND TransactionTypeID = 14)  
 BEGIN  
  -- We did find another transfer, so add it to the results.  
  INSERT INTO @ResultsTable  
  (  
   RegisterReceiptID1,  
   ReceiptNumber1,  
   TimeStamp1,  
   PackNumber,  
   UnitNumber1,  
   ReceiptTotal1,  
   RegisterReceiptID2,  
   ReceiptNumber2,  
   TimeStamp2,  
   TransactionType,  
   UnitNumber2,  
   ReceiptTotal2  
  )  
  SELECT  
   @CurrentTransferID,  
   rr.TransactionNumber,  
   rr.DTStamp,  
   @OriginalPackNumber,  
   rr.UnitNumber,  
   @OriginalTotal,  
   transrr.RegisterReceiptID,  
   transrr.TransactionNumber,  
   transrr.DTStamp,  
   'Transfer',  
   transrr.UnitNumber,  
            0 --DE9800 transfers are 0 dollar transactions  
  FROM RegisterReceipt rr  
   JOIN RegisterReceipt transrr ON (rr.RegisterReceiptID = transrr.OriginalReceiptID)  
   left join RegisterDetail rd on rd.RegisterReceiptID = transrr.RegisterReceiptID  
   left join RegisterDetailItems rdi on rdi.RegisterDetailID = rd.RegisterDetailID  
  WHERE rr.RegisterReceiptID = @CurrentTransferID  
   AND rr.TransactionTypeID = 14  
   AND transrr.TransactionTypeID = 14  
  SELECT @CurrentTransferID = RegisterReceiptID   
  FROM RegisterReceipt   
  WHERE OriginalReceiptID = @CurrentTransferID AND TransactionTypeID = 14;  
 END  
  
 FETCH NEXT FROM TransferCursor INTO @CurrentTransferID, @OriginalPackNumber, @OriginalTotal  
END  
  
CLOSE TransferCursor  
DEALLOCATE TransferCursor  
-- END: DE7330  

  
--------------------------------------------------  
--DE9766  
--DE9800 Adjust for the discounts and sales tax values  
update  t1   
 set t1.DiscountAmt = t2.TotalDiscount,  
     t1.SalesTaxAmt = t2.TotalSalesTaxAmount,  
        t1.ReceiptTotal1 = isnull(t1.ReceiptTotal1,0) - isnull(t2.TotalDiscount,0) + isnull(t2.TotalSalesTaxAmount,0),  
        t1.ReceiptTotal2 = case when t1.TransactionType = 'Transfer'  
                                then 0   
                                else isnull(t1.ReceiptTotal2,0) + isnull(t2.TotalDiscount,0) - isnull(t2.TotalSalesTaxAmount,0) end  
from @ResultsTable t1 inner join  
 (  
  select  RegisterReceiptID, sum(DiscountAmount * Quantity *(-1)) as TotalDiscount,  
          SUM(SalesTaxAmt * Quantity) as TotalSalesTaxAmount  
  from RegisterDetail  
  group by RegisterReceiptID  
 ) as t2  
 on t1.RegisterReceiptID1 = t2.RegisterReceiptID  
---------------------------------------------------  
  
SELECT    
 RegisterReceiptID1,  
 ReceiptNumber1,  
 TimeStamp1,  
 PackNumber,  
 UnitNumber1,  
 ReceiptTotal1,  
 ReceiptNumber2,  
 TimeStamp2,  
 TransactionType,  
 UnitNumber2,  
 ReceiptTotal2  
 into #a
FROM @ResultsTable  
group by   
 RegisterReceiptID1,  
 ReceiptNumber1,  
 TimeStamp1,  
 PackNumber,  
 UnitNumber1,  
 ReceiptNumber2,  
 TimeStamp2,  
 TransactionType,  
 UnitNumber2,  
    ReceiptTotal1,  
    ReceiptTotal2;  
    --199 rows
 
 --------------------------------------------------------
 --------------------------------------------------------:)(:---------
 declare @ElectronicSales table  
(  
  RegisterReceiptID int  
 ,OriginalRegisterReceiptID int  
 ,VoidedRegisterReceiptID int  
 ,StaffID int  
 ,GamingSession int  
 ,TransactionNumber int  
 ,DTStamp datetime  
 ,SerialNumber nvarchar(64)  
 ,PackNumber int  
 ,NoOfCards int  
 ,Price money  
)  
declare @CardCount table  
(  
 totalCards int,  
 registerRecieptId int  
);    
 declare @AllCardNumbers table  
(          
 cardNo int,  
 sessionGamesPlayedID int,  
 registerReceiptID int  
   
)  
   
insert into @AllCardNumbers  
select  bcd.bcdCardNo,bcd.bcdSessionGamesPlayedID, rr.RegisterReceiptID from RegisterReceipt rr  
 join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID  
 join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID  
 join BingoCardHeader bch on rdi.RegisterDetailItemID = bch.bchRegisterDetailItemID  
 join BingoCardDetail bcd on bch.bchMasterCardNo = bcd.bcdMasterCardNo and   
                             bch.bchSessionGamesPlayedID = bcd.bcdSessionGamesPlayedID  
 join SessionGamesPlayed sgp on bcd.bcdSessionGamesPlayedId = sgp.SessionGamesPlayedId  
 where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)   
    and rr.GamingDate <= cast(convert(varchar(12),@EndDate, 101) as smalldatetime)   
    and rr.OperatorID = @OperatorID  
    and (rdi.CardMediaId = 1 or rdi.CardMediaId is null)  
    and sgp.IsContinued = 0  
     
insert @CardCount  
 select COUNT(cardno), RegisterReceiptID   
 from @AllCardNumbers t  
 group by t.registerReceiptID;  
  
insert into @ElectronicSales  
(  
  RegisterReceiptID  
 ,OriginalRegisterReceiptID  
 ,VoidedRegisterReceiptID  
 ,StaffID  
 ,GamingSession  
 ,TransactionNumber  
 ,DTStamp  
 ,SerialNumber  
 ,PackNumber  
 ,NoOfCards  
 ,Price  
)         
select rr.RegisterReceiptID  
 ,rr.OriginalReceiptID  
 ,rd.VoidedRegisterReceiptID  
 ,rr.StaffID  
 ,sp.GamingSession  
 ,rr.TransactionNumber  
 ,rr.DTStamp  
 ,case when ulSoldToMachineId is null then ulUnitSerialNumber else(case when m.SerialNumber is null then m.ClientIdentifier else m.SerialNumber end) end  
 ,rr.PackNumber  
 ,0.0 as CardCount --DE10084  
 ,sum(rdi.Price * rdi.Qty * rd.Quantity) as Price  
from RegisterReceipt rr  
join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID  
join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID  
join SessionPlayed sp on rd.SessionPlayedId = sp.SessionPlayedId  
left join UnlockLog ul on (ulID = (select top 1 ulID  
   from UnlockLog where ulRegisterReceiptID = rr.RegisterReceiptID  
    and ulPackLoginAssignDate is not null  
   order by ulPackLoginAssignDate desc))  
left join Machine m on m.MachineID = ulSoldToMachineID  
  
where RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
and RR.SaleSuccess = 1  
and RDI.CardMediaID = 1  
and RR.OperatorID = @OperatorID  
and (@Session = 0 or sp.GamingSession = @Session)  
group by   
  rr.RegisterReceiptID  
 ,rr.OriginalReceiptID  
 ,sp.GamingSession  
 ,RR.TransactionNumber  
 ,RR.DTStamp  
 ,RR.PackNumber  
 ,m.SerialNumber  
 ,m.ClientIdentifier  
 ,ulSoldToMachineId  
 ,RR.StaffID  
 ,RD.VoidedRegisterReceiptID  
 ,ulRegisterReceiptID  
 ,ulUnitSerialNumber  
  
---Voids  
insert into @ElectronicSales  
(  
  RegisterReceiptID  
 ,OriginalRegisterReceiptID  
 ,VoidedRegisterReceiptID  
 ,StaffID  
 ,GamingSession  
 ,TransactionNumber  
 ,DTStamp  
 ,SerialNumber  
 ,PackNumber  
 ,NoOfCards  
 ,Price  
)         
select  rr.RegisterReceiptID  
 ,rr.OriginalReceiptID  
 ,rd.VoidedRegisterReceiptID  
 ,rr.StaffID  
 ,es.GamingSession  
 ,rr.TransactionNumber  
 ,rr.DTStamp  
 ,rr.UnitSerialNumber  
 ,es.PackNumber  
 ,es.NoOfCards  
 ,es.Price  
from   RegisterReceipt rr  
       left join RegisterDetail rd ON rr.RegisterReceiptID = rd.RegisterReceiptID  
       left join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID  
    join @ElectronicSales es on rr.OriginalReceiptID = es.RegisterReceiptID  
where   rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)   
     and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)   
     and(rdi.CardMediaID = 1 or rdi.CardMediaID is null)  
     and rr.TransactionTypeID = 2  
     and rr.OperatorID = @OperatorID  
  
update @ElectronicSales  
set NoOfCards = Card_Count from (select totalCards as Card_Count, registerRecieptId as r_r from @CardCount) as [A]  
                where RegisterReceiptID = r_r  
                and OriginalRegisterReceiptID is null  
  
declare @rrID int;  
declare @orrID int;  
declare void_cursor cursor for  
select RegisterReceiptID, OriginalRegisterReceiptID    
        from @ElectronicSales  
        where OriginalRegisterReceiptID is not null;  
open  void_cursor;  
fetch next from void_cursor into @rrID, @orrID;                   
while @@FETCH_STATUS = 0  
begin  
    
 update @ElectronicSales  
 set NoOfCards = (select totalcards from @CardCount where registerRecieptId= @orrID)  
 where RegisterReceiptID = @rrID;   
 fetch next from void_cursor into @rrID, @orrID;  
end  
close void_cursor;  
deallocate void_cursor;  
  
select a.RegisterReceiptID  
 ,a.OriginalRegisterReceiptID  
 ,a.VoidedRegisterReceiptID  
 ,a.StaffID  
 ,a.GamingSession  
 ,a.TransactionNumber  
 ,a.DTStamp,  
 case   
 when a.OriginalRegisterReceiptID IS null then a.SerialNumber  
 when a.OriginalRegisterReceiptID IS not null  then b.SerialNumber   
 end as [SerialNumber]  
 ,a.PackNumber  
 ,a.NoOfCards  
 ,a.Price  
 into #b
from @ElectronicSales a left join @ElectronicSales b   
on a.OriginalRegisterReceiptID = b.RegisterReceiptID  
--where a.NoOfCards <> 0
order by a.TransactionNumber  
--added for testing
  --4007
SET NOCOUNT OFF  

select 
 RegisterReceiptID1,  
 ReceiptNumber1,  
 TimeStamp1,  
 a.PackNumber,  
 UnitNumber1,  
 ReceiptTotal1,  
 ReceiptNumber2,  
 TimeStamp2,  
 TransactionType,  
 UnitNumber2,  
 ReceiptTotal2 ,
 b.NoOfCards 
from #a a left join #b b on b.RegisterReceiptID = a.RegisterReceiptID1


drop table #a , #b
  
  
  
  
  
  
  
  
  
  

GO


