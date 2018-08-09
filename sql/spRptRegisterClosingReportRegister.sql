USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportRegister]    Script Date: 05/04/2015 15:38:57 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterClosingReportRegister]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterClosingReportRegister]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportRegister]    Script Date: 05/04/2015 15:38:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


  
CREATE Procedure [dbo].[spRptRegisterClosingReportRegister]  
(  
 @OperatorID    AS INT,    
 @StartDate     AS DATETIME,  
 @EndDate       AS DATETIME,  
 @StaffID       AS INT,  
 @Session       AS INT,  
 @MachineId     as int  
)  
AS  
BEGIN  
-- ============================================
-- Author: GameTech
-- 2012
-- 1/25/2013 (knc): US412/TA60 - All product is not showing in register/comparison section.
-- 2/28/2013 (knc): DE10839/TA11596 - Reg/Inv Comparison does not include all products sold from the register
-- 10/17/2013(tmp): DE11337/TA12032 - Removed SoldFromMachineID from the select statements so that inventory sales are reported when
--									@MachineID <> 0
-- 05/04/2015 (tmp): DE12458 - Transferred inventory is being returned for the staff that inventory was transferred from.
-- ============================================
  
  
  -- ==========================================
  --TEST
--declare   
-- @OperatorID    AS INT,    
-- @StartDate     AS DATETIME,  
-- @EndDate       AS DATETIME,  
-- @StaffID       AS INT,  
-- @Session       AS INT,  
-- @MachineId     as int  
--  set @OperatorID = 1
--  set @StartDate = '1/17/2013 00:00:00'
--  set @EndDate = '1/17/2013 00:00:00'
--  set @StaffID = 12
--  set @Session = 1
--  set @MachineId = 0
  -- END TEST
-- ================================================

-- Verfify POS sending valid values  
set @StaffID = isnull(@StaffID, 0);  
set @Session = isnull(@Session, 0);  
set @MachineID = isnull(@MachineID, 0);  
  
  
DECLARE @Inventory TABLE  
(  
 StaffID         int,  
 GamingDate      datetime,  
 GamingSession   int ,  
    ItemName        VARCHAR(100),   
    CountValue      money ,
    staffLastName varchar(100),
    staffFirstName varchar(100)
--    SoldFromMachineID int 
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
    ( CASE ivtTransactionTypeID WHEN 27 THEN ivdDelta ELSE 0 END) +
    ( CASE ivtTransactionTypeID WHEN 32 THEN ivdDelta ELSE 0 END),		--DE12458
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
and (ivtGamingDate >= @StartDate and ivtGamingDate <= @EndDate)  
and (ivtGamingSession = @Session or @Session = 0)  
and pri.OperatorID = @OperatorID  
and pt.ProductType like '%paper%'  
and (@StaffID = 0 or ilStaffID = @StaffID);  
  
-- jkn added to fix issue with issue prices v. inventory prices  
update @Tab  
set Price = (select ivtPrice  
    from InvTransaction  
    where ivtInvTransactionID = MasterTransID)  


INSERT INTO @Inventory  
(
 StaffID  ,   
 GamingDate  ,    
 GamingSession  ,   
    ItemName ,         
    CountValue  )    
SELECT StaffID,GamingDate,GamingSession,ItemName  
,SUM( Counts * Price)    
FROM @Tab   
Group By StaffID,GamingDate,GamingSession,ItemName  
Order By StaffID,GamingDate,GamingSession;  

      
----------------------------------------------------------------    
DECLARE @RegisterSales TABLE   
(  
    gamingDate          datetime,  
 sessionNbr          int,  
 staffIdNbr          int,              
 staffLastName       NVARCHAR(64),  
 staffFirstName      NVARCHAR(64),  
    ItemName            VARCHAR(100),   
-- soldFromMachineId   int,  
    CountValue1         money  
);  
     
INSERT INTO @RegisterSales  
select   
    rr.GamingDate,  
    sp.GamingSession,  rr.StaffID, s.LastName , s.FirstName,  
    rdi.ProductItemName  
 --   , rr.SoldFromMachineID  
    ,SUM(rd.Quantity * rdi.Qty * rdi.Price)   
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
 --AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)             
 AND rdi.ProductTypeID = 16      -- Exclude CBB b/c it is not TRUE inventory paper bjs 5/24/11  
 And (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL   
 AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)-- Paper  
    and (@StaffID = 0 or rr.StaffID = @StaffID)  
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )  
GROUP BY   
    rr.GamingDate, sp.GamingSession,  rr.StaffID, s.LastName , s.FirstName, rdi.ProductItemName; --rr.SoldFromMachineID;  
  
-- Deduct returns  
INSERT INTO @RegisterSales  
SELECT  
    rr.GamingDate,  
    sp.GamingSession,  rr.StaffID, s.LastName , s.FirstName,   
    rdi.ProductItemName,  
 --   rr.SoldFromMachineID,  
 SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price) --paper,    
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
 --AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)  
 AND rdi.ProductTypeID = 16      -- Exclude CBB b/c it is not TRUE inventory paper bjs 5/24/11  
 And (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL   
 AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)-- Paper  
    and (@StaffID = 0 or rr.StaffID = @StaffID)  
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )      
GROUP BY   
    rr.GamingDate, sp.GamingSession, rr.StaffID, s.LastName, s.FirstName, rdi.ProductItemName -- rr.SoldFromMachineID;  
 --rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;  
  

  
select   
  isnull(r.staffIdNbr, i.StaffID) staffIdNbr  
, isnull(r.staffLastName, s.LastName)  staffLastName
, isnull(r.staffFirstName, s.FirstName)  staffFirstName
,isnull(r.gamingDate,i.GamingDate) gamingDate
, isnull(r.sessionNbr,i.GamingSession) sessionNbr  
, isnull(r.ItemName, i.ItemName)   ItemName
--, i.soldFromMachineId
, isnull(r.CountValue1, 0) [RegisterValue]  
, isnull(i.CountValue, 0)  [InventoryValue]  
, isnull(r.CountValue1, 0) - isnull(i.CountValue, 0) [Difference]  
from @RegisterSales r  
--right join @Inventory i on r.sessionNbr = i.GamingSession and r.ItemName = i.ItemName and r.gamingDate = i.GamingDate and r.staffIdNbr = i.StaffID  
full outer join @Inventory i on r.sessionNbr = i.GamingSession and r.ItemName = i.ItemName and r.gamingDate = i.GamingDate and r.staffIdNbr = i.StaffID  -- 2/28/2013 (knc): DE10839/TA11596
left join Staff s on s.StaffID =  isnull(r.staffIdNbr, i.StaffID)
-- where (r.soldFromMachineId = @MachineId or @MachineId = 0)
order by r.staffIdNbr, r.staffLastName, r.staffFirstName, gamingDate,sessionNbr;  
  
End


















GO

