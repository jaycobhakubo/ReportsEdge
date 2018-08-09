USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Electronics]    Script Date: 06/10/2015 16:35:20 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDoorSales_Electronics]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDoorSales_Electronics]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Electronics]    Script Date: 06/10/2015 16:35:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptDoorSales_Electronics] 
-- ============================================================================
-- Author:		Travis Pollock
-- Description:	<>
-- 2011.07.18 bjs: DE8882 invalid rate fee after transfer
-- 2011.08.05 bjs: US1902 add prod group param
-- 2011.09.01 bjs: cards sold/played too high
-- 2011.11.30 bjs: DE9706 invalid cards played when specifying ALL groups
-- 2012.02.09 jkn: DE9706/TA10839 Remove the product group data
--	this was causing problems when attempting to calculate totals
-- 2012.02.21 jkn: DE10136 pack sales were being counted improperly
-- 2012.08.02 jkn: DE10580 count all of the cards that are returned since
--  the same card number can be used for a different game and the distinct
--  would miss these cards creating an invalid card count.
-- 2013.05.10 tmp: Complete re-write of the sp to improve card count calculation speed.
-- 2014.04.11 tmp: US3340 Added Crystal Ball Bingo Billing Information
-- 2015.06.10 tmp: US3997 Added support for multiple game categories. 
-- ============================================================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session	AS INT,
	@ProductGroupID as int
AS
	
SET NOCOUNT ON


declare @taxRate money;
select @taxRate = (SalesTax / 100.0) from Hall where HallID = (select top 1 HallID from Hall);
print @taxRate;

Declare @NbrGamesPlayed table
(
	SessionPlayedID Int,
	NbrGames Int,
	GameCategoryID Int
)
Insert @NbrGamesPlayed
Select sgp.SessionPlayedID,
	Count(Distinct sgp.DisplayGameNo) as NbrGames,
	sgc.GameCategoryID as GameCategory	--US3997
From SessionGamesPlayed sgp
Join SessionPlayed sp on (sgp.SessionPlayedID = sp.SessionPlayedID)
join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId  --US3997
Where sgp.IsContinued = 0 -- False
And sp.OperatorID = @OperatorID
And sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
AND sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
AND (@Session = 0 or sp.GamingSession = @Session)
Group By sgc.GameCategoryID, sgp.SessionPlayedID;  --US3997

Declare @CardCount table
(
	RegisterReceiptID int,
	TransactionNumber int,
	PackageName varchar(64),
	PackagePrice money,
	PkgQty int,
	ProductItemName varchar(64),
	PrdQty int,
	PrdPrice money,
	CardCount int,
	GameCategoryID int,
	SessionPlayedID int,
	PrdCards int,
	DeviceID int,
	MachineID int
)
Insert @CardCount
Select	rd.RegisterReceiptID,
		rr.TransactionNumber,
		rd.PackageName,
		rd.PackagePrice,
		rd.Quantity as PkgQty,
		rdi.ProductItemName,
		rdi.Qty as PrdQty,
		rdi.Price as PrdPrice,
		sum(rdi.CardCount),
		rdi.GameCategoryID,
		sp.SessionPlayedID,
		0,
		(SELECT TOP 1 ulDeviceID FROM UnLockLog WHERE ulRegisterReceiptID = rd.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL ORDER BY ulPackLoginAssignDate DESC),
		(SELECT TOP 1 isnull(ulSoldToMachineID, ulUnitNumber) FROM UnLockLog WHERE ulRegisterReceiptID = rd.RegisterReceiptID AND ulPackLoginAssignDate IS NOT NULL ORDER BY ulPackLoginAssignDate DESC)
From RegisterDetail rd
Join RegisterReceipt rr on (rd.RegisterReceiptID = rr.RegisterReceiptID)
Join RegisterDetailItems rdi on (rd.RegisterDetailID = rdi.RegisterDetailID)
Join SessionPlayed sp on (rd.SessionPlayedID = sp.SessionPlayedID)
Where rr.OperatorID = @OperatorID
And rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And rr.SaleSuccess = 1
And rdi.CardMediaID = 1 -- Electronic
And rd.VoidedRegisterReceiptID is null
AND (@Session = 0 or sp.GamingSession = @Session)
Group By rd.RegisterReceiptID, rr.TransactionNumber, rd.PackageName, rd.PackagePrice, rd.Quantity, rdi.ProductItemName, rdi.Qty, rdi.Price, rdi.GameCategoryID, rdi.CardCount, sp.SessionPlayedID; 


DECLARE @Results TABLE
(
	DeviceName NVARCHAR(32),
	CardsSold INT,
	UnitsSold INT,
	UnitSales MONEY,	
	UnitFee MONEY,
	TotFee Money,
	TaxRate Money            
);
Insert into @Results
(
	DeviceName,
	CardsSold,
	UnitsSold,
	UnitSales,	
	UnitFee,
	TotFee,
	TaxRate
)     
Select 	isnull(d.DeviceType, 'Pack') as DeviceName,
		Sum((ngp.NbrGames * cc.CardCount * cc.PrdQty) * cc.PkgQty) as CardsSold,
		Count(Distinct cc.MachineID)as UnitsSold,	
		Sum(PrdPrice * PrdQty * PkgQty)as UnitSales,
		0,
		0,
		@taxRate
From @CardCount cc
Join @NbrGamesPlayed ngp on (cc.GameCategoryID = ngp.GameCategoryID)
Left Join Device d on (cc.DeviceID = d.DeviceID)
Where cc.SessionPlayedID = ngp.SessionPlayedID
Group By cc.SessionPlayedID, d.DeviceType;


---- Start US3340 --- Insert Crystal Ball Bingo cards sold ----------------

With cteCBBFees (Name, Fee)
As
(
Select Case when ddf.ddfDistDeviceFeeTypeID = 5 
				then 'Electronic'
			Else 'Paper' End,
		ddf.ddfDeviceFee
From DistributorDeviceFees ddf
Where ddf.ddfOperatorID = @OperatorID
And ddf.ddfDistDeviceFeeTypeID in (5, 6)
And ddf.ddfDeviceFee <> 0
)
	Insert into @Results
	(
		DeviceName,
		CardsSold,
		TaxRate,
		UnitFee
	)	
	Select	cm.CardMediaName,
			Sum(rd.Quantity * (rdi.Qty * rdi.CardCount)) as CardCount,
			@taxRate,
			cbf.Fee
	From RegisterReceipt rr
				Join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
				Join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
				Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
				Join CardMedia cm on cm.CardMediaID = rdi.CardMediaID
				Join cteCBBFees cbf on cm.CardMediaName = cbf.Name
	Where	rr.OperatorID = @OperatorID
	And		rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And		rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	And		rr.SaleSuccess = 1
	And		rd.VoidedRegisterReceiptID is null
	And		rdi.GameTypeID = 4
	And		(@Session = 0 or sp.GamingSession = @Session)
	Group By cm.CardMediaName, cbf.Fee
	Order By cm.CardMediaName

---- End US3340 ------------------------------------------------------------

UPDATE @Results
SET UnitFee = ddf.ddfDeviceFee
FROM @Results r
	JOIN Device d ON (d.DeviceType = r.DeviceName)
	JOIN DistributorDeviceFees ddf ON (ddf.ddfDeviceID = d.DeviceID)
WHERE ddf.ddfOperatorID = @OperatorID
	AND ddf.ddfDeviceID = d.DeviceID
	AND ddf.ddfDistDeviceFeeTypeID = 1
	AND r.UnitsSold >= ddf.ddfMinRange
	AND r.UnitsSold <= ddf.ddfMaxRange;


UPDATE @Results SET UnitFee = 0
WHERE UnitFee IS NULL;

update @Results set totFee = (UnitFee * UnitsSold)
Where DeviceName <> 'Electronic' or -- US3340
		DeviceName <> 'Paper';  -- US3340

--- US3340 Calculate the total fee for CBB ---------------------------------
update @Results set totFee = (UnitFee * CardsSold)
Where DeviceName = 'Electronic' or 
		DeviceName = 'Paper';

Select	DeviceName,
		SUM(CardsSold) as CardsSold,
		SUM(UnitsSold) as UnitsSold,
		SUM(UnitSales) as UnitSales,
		UnitFee,
		SUM(TotFee) as TotFee,
		TaxRate
		From @Results
Group By DeviceName, UnitFee, TaxRate
Order By DeviceName;


SET NOCOUNT OFF




























GO

