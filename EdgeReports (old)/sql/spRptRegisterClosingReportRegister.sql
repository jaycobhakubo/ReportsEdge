USE [Daily]
GO
/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportRegister]    Script Date: 06/19/2012 08:33:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER Procedure [dbo].[spRptRegisterClosingReportRegister]
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
	MasterTransID	int
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

-- debug
--select * from @Tab;
--return;

INSERT INTO @Inventory
SELECT StaffID,GamingDate,GamingSession,ItemName
,SUM( Counts * Price)  
FROM @Tab 
Group By StaffID,GamingDate,GamingSession,ItemName
Order By StaffID,GamingDate,GamingSession;
   
  
-- DEBUG
--select * from @Inventory 
--Order By StaffID,GamingDate,GamingSession;
--return;
   
----------------------------------------------------------------  
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
    rr.GamingDate, sp.GamingSession,  rr.StaffID, s.LastName , s.FirstName, rdi.ProductItemName, rr.SoldFromMachineID;

-- Deduct returns
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
    rr.GamingDate, sp.GamingSession, rr.StaffID, s.LastName, s.FirstName, rdi.ProductItemName, rr.SoldFromMachineID;
	--rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID;

-- DEBUG
--select * from @RegisterSales
--order By staffIdNbr, GamingDate, sessionNbr;
--return;

select 
  r.staffIdNbr
, r.staffLastName
, r.staffFirstName
, r.gamingDate
, r.sessionNbr
, r.ItemName
, r.soldFromMachineId
, isnull(r.CountValue1, 0) [RegisterValue]
, isnull(i.CountValue, 0)  [InventoryValue]
, isnull(r.CountValue1, 0) - isnull(i.CountValue, 0) [Difference]
from @RegisterSales r
join @Inventory i on r.sessionNbr = i.GamingSession and r.ItemName = i.ItemName and r.gamingDate = i.GamingDate and r.staffIdNbr = i.StaffID
order by r.staffIdNbr, r.staffLastName, r.staffFirstName, gamingDate,sessionNbr;

End




