USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptTotalSalesInvNRegister]    Script Date: 03/01/2013 09:02:30 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptTotalSalesInvNRegister]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptTotalSalesInvNRegister]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptTotalSalesInvNRegister]    Script Date: 03/01/2013 09:02:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




  
 
 -->>>>>>>>>>>>>>>COMMENT<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  --This Subreport is based on another Subreport name spRptRegisterClosingReportRegister
  --This will be a new subreport that will join the session summary report
  --were going to change @startDate and EndDate to @GamingDate
  --were going to removed @MachineID
  --also @staffID will be removed
  --we will see if were getting a value
  --And yes we have a value
  --we have to test this with new database from testing/QA
  -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  
CREATE proc [dbo].[spRptTotalSalesInvNRegister]
  (

@OperatorID    AS INT,    
@GamingDate as datetime,
@Session       AS INT  
)as begin
-- ==================================================
--5/16/2012|US2156|knc: Show the total Inventory sale and Register Sale
--2/28/2013|DE10840/TA11597|knc - Register / Inventory section of the session summary does not return all of the products sold from register and inventory.
-- =================================================



-->>>>>>>>>>>>>>TEST<<<<<<<<<<<<<<<<<<<<<<<<
--declare 

--@OperatorID    AS INT,    
--@GamingDate as datetime,
--@Session       AS INT  

--set @OperatorID = 1
--set @GamingDate = '2/7/2013 00:00:00'
--set @Session = 6
--begin
-->>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<


 set @Session = isnull(@Session, 0) 
 set @OperatorID = ISNULL(@OperatorID, 0)
  
DECLARE @Inventory TABLE  
(  
 StaffID         int,  
 GamingDate      datetime,  
 GamingSession   int ,  
 ItemName        VARCHAR(100),   
 CountValue      money  
);  
  
DECLARE @Tab TABLE  
(  
 StaffID         int,  
 GamingDate      datetime,  
 GamingSession   int ,  
    Price           money,  
    Counts          INT,  
    ItemName        VARCHAR(100),  
 MasterTransID int  
 );  
  
INSERT INTO @Tab  
select  
    ilStaffID,   
    ivtGamingDate,   
    ivtGamingSession,   
    iiPricePerItem,       
    ( CASE ivtTransactionTypeID WHEN 23 THEN ivdDelta ELSE 0 END) +  
    ( CASE ivtTransactionTypeID WHEN 25 THEN ivdDelta ELSE 0 END) +  
    ( CASE ivtTransactionTypeID WHEN 3 THEN ivdDelta ELSE 0 END) +  
    ( CASE ivtTransactionTypeID WHEN 27 THEN ivdDelta ELSE 0 END),  
    pri.ItemName,   
 case when ivtMasterTransactionID is null then ivtInvTransactionID else ivtMasterTransactionID end -- jkn added to fix issue with issue prices v. inventory prices  
from InventoryItem   
join InvTransaction on iiInventoryItemID = ivtInventoryItemID  
join InvTransactionDetail on ivtInvTransactionID = ivdInvTransactionID  
join InvLocations on ivdInvLocationID = ilInvLocationID  
left join IssueNames on ivtIssueNameID = inIssueNameID  
left join ProductItem pri on pri.ProductItemID = iiProductItemID  
left join ProductType pt on pri.ProductTypeID = pt.ProductTypeID          
where  
(ilMachineID <> 0 or ilStaffID <> 0)  
and (cast(CONVERT(VARCHAR(10),ivtGamingDate,10) as smalldatetime) =  cast(CONVERT(VARCHAR(10),@GamingDate,10) as smalldatetime))
 and (ivtGamingSession = @Session or @Session = 0)  
and (pri.OperatorID = @OperatorID or @OperatorID = 0)  
and pt.ProductType like '%paper%'  


  
update @Tab  
set Price = (select ivtPrice  
from InvTransaction  
where ivtInvTransactionID = MasterTransID)  
  
--  select * from @Tab 
  
INSERT INTO @Inventory  
SELECT StaffID,GamingDate,GamingSession,ItemName  
,SUM( Counts * Price)    
FROM @Tab   
Group By StaffID,GamingDate,GamingSession,ItemName  
Order By StaffID,GamingDate,GamingSession;  

-- select * from  @Inventory 
 
DECLARE @RegisterSales TABLE   
(  
    gamingDate          datetime,  
 sessionNbr          int,  
 staffIdNbr          int,              
 staffLastName       NVARCHAR(64),  
 staffFirstName      NVARCHAR(64),  
    ItemName            VARCHAR(100),   
 soldFromMachineId   int,  
    CountValue1         money  
);  
     
INSERT INTO @RegisterSales  
select   
    rr.GamingDate,  
    sp.GamingSession,  rr.StaffID, s.LastName , s.FirstName,  
    rdi.ProductItemName  
    , rr.SoldFromMachineID  
    ,SUM(rd.Quantity * rdi.Qty * rdi.Price)   
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)  
join Staff s on rr.StaffID = s.StaffID  
Where 
(cast(CONVERT(VARCHAR(10),rr.GamingDate,10) as smalldatetime) =  cast(CONVERT(VARCHAR(10),@GamingDate,10) as smalldatetime))
and rr.SaleSuccess = 1  
and rr.TransactionTypeID = 1  
AND rdi.ProductTypeID = 16      
And (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL   
 AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)
 and (rr.OperatorID = @OperatorID or @OperatorID = 0) 
GROUP BY   
    rr.GamingDate, sp.GamingSession,  rr.StaffID, s.LastName , s.FirstName, rdi.ProductItemName, rr.SoldFromMachineID, rr.OperatorID ;  

--select * from @RegisterSales
  
-- Deduct returns  ????? "this is adding a record not deducting - will proceed if error occur then well fix
INSERT INTO @RegisterSales  
SELECT  
    rr.GamingDate,  
    sp.GamingSession,  rr.StaffID, s.LastName , s.FirstName,   
    rdi.ProductItemName,  
 rr.SoldFromMachineID,  
 SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price) --paper,    
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)  
 join Staff s on rr.StaffID = s.StaffID  
Where 
(cast(CONVERT(VARCHAR(10),rr.GamingDate,10) as smalldatetime) =  cast(CONVERT(VARCHAR(10),@GamingDate,10) as smalldatetime))
and rr.SaleSuccess = 1  
and rr.TransactionTypeID = 3 
And (@Session = 0 or sp.GamingSession = @Session)  
AND rdi.ProductTypeID = 16     
and rd.VoidedRegisterReceiptID IS NULL   
and (rr.OperatorID = @OperatorID or @OperatorID = 0) 
AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)      
GROUP BY   
 rr.GamingDate, sp.GamingSession, rr.StaffID, s.LastName, s.FirstName, rdi.ProductItemName, rr.SoldFromMachineID;  
 
 

  --select * from @RegisterSales
--select * from @Inventory 
  
select   
  r.staffIdNbr  
, r.staffLastName  
, r.staffFirstName  
, r.gamingDate  
, r.sessionNbr  
, isnull(r.ItemName, i.ItemName) ItemName  
, r.soldFromMachineId  
, isnull(r.CountValue1, 0) [RegisterValue]  
, isnull(i.CountValue, 0)  [InventoryValue]  
, isnull(r.CountValue1, 0) - isnull(i.CountValue, 0) [Difference]  into #a
from @RegisterSales r  
--join @Inventory i on r.sessionNbr = i.GamingSession and r.ItemName = i.ItemName and r.gamingDate = i.GamingDate and r.staffIdNbr = i.StaffID  
Full outer join @Inventory i on r.sessionNbr = i.GamingSession and r.ItemName = i.ItemName and r.gamingDate = i.GamingDate and r.staffIdNbr = i.StaffID  --2/28/2013|DE10840/TA11597|knc
order by r.staffIdNbr, r.staffLastName, r.staffFirstName, gamingDate,sessionNbr;  
  
  -- Why theres a null column? Will skip for now if customer complaint then I will fix. knc
  
  select ItemName , 
  sum(registerValue)[RegisterValue] , 
  Sum(InventoryValue)[InventoryValue]   , 
  SUM([Difference])  [Difference] 
  from #a group by ItemName
  
  drop table #a 
  
End  
  
  
  
  




GO


