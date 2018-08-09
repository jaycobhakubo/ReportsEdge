USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindPaperSales]    Script Date: 01/24/2012 15:56:04 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FindPaperSales]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FindPaperSales]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindPaperSales]    Script Date: 01/24/2012 15:56:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		GameTech
-- Create date: 6/27/2011
-- 12/7/2011 BSB: DE9724 added paper tranfer count
-- Description:	Find paper sales at the register and on the floor.
-- Returns: table variable containing data ready for Crystal Reports (no null's in the money fields!).
-- 2012.1.24  SA : DE9937: missing machineId for papersales 
-- =============================================
CREATE FUNCTION [dbo].[FindPaperSales] 
(
	@OperatorID		AS INT,
	@StartDate		AS DATETIME,
	@EndDate		AS DATETIME,
	@Session		AS INT
)
RETURNS 
@PaperSales TABLE 
(
	GamingDate      datetime,
	SessionNo       int,
	StaffID         int,
	ProdTypeID      int,
	soldFromMachineId   int,
	GroupName       nvarchar(64),
	PackageName     nvarchar(64),
	ItemName        nvarchar(64),
	Price           money,
	Qty             int,
	RegisterPaper   money,
	FloorPaper      money
)
AS
BEGIN
	-- Temp table to include inventory counts also...
	declare @Sales TABLE 
	(
		GamingDate      datetime,
		SessionNo       int,
		StaffID         int,
		ProdTypeID      int,
		soldFromMachineId   int,
		GroupName       nvarchar(64),
		PackageName     nvarchar(64),
		ItemName        nvarchar(64),
		Price           money,
		Qty             int,            
		RegisterPaper   money,
		FloorPaper      money,
		ReturnCount     int,            -- order determined by tran type
		SkipCount       int,
		BonanzaCount    int,            -- reserved for future
		IssueCount      int,
		PlaybackCount   int,            -- reserved for future
		DamageCount     int,
		TransferCount   int
	);

	--		
	-- Insert Paper Sales at the Register	
	--
	INSERT INTO @Sales
	(
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, soldFromMachineId
		, GroupName
		, PackageName
		, ItemName
		, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount,TransferCount
	)
	SELECT	
			rr.GamingDate, sp.GamingSession, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName, rdi.ProductItemName
		, rdi.Price
		, SUM(rd.Quantity * rdi.Qty)                [Qty]
		, SUM(rd.Quantity * rdi.Qty * rdi.Price)    [RegisterPaper]
		, 0                                         [FloorPaper]
		, 0, 0, 0, 0, 0, 0,0
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		(rr.GamingDate between @StartDate and @EndDate)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 1
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)
		And (@Session = 0 or sp.GamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;


	-- Account for returns
	INSERT INTO @Sales
	(
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, soldFromMachineId
		, GroupName
		, PackageName
		, ItemName
		, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount
	)
	SELECT	
			rr.GamingDate, sp.GamingSession, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName, rdi.ProductItemName
		, rdi.Price
		, SUM( -1 * rd.Quantity * rdi.Qty)                  [Qty]
		, SUM( -1 * rd.Quantity * rdi.Qty * rdi.Price)      [RegisterPaper]
		, 0                                                 [FloorPaper]
		, 0, 0, 0, 0, 0, 0 ,0                                  -- counts
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		(rr.GamingDate between @StartDate and @EndDate)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 3        -- returns
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)
		And (@Session = 0 or sp.GamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;


	---------------------------------------------------------------------------------------------------------------
	--		
	-- Insert Paper Sales on the Floor		
	--
	with FloorSales
	(
		GamingDate,
		SessionNo,
		StaffID,
		ProdTypeID,
		GroupName,
		PackageName,
		ItemName,
		Price,
		ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount
	) as 
	(select 
			ivtGamingDate
		, ivtGamingSession
		, ilStaffID
		, pi.ProductTypeID
		, pg.GroupName
		, 'Floor Sales' [PackageName]  -- req'd b/c no direct link between inventory transaction and packages
		, pi.ItemName
		, ivtPrice
		, CASE ivtTransactionTypeID WHEN 3 THEN ivdDelta ELSE 0 END     [ReturnsCount]
		, CASE ivtTransactionTypeID WHEN 23 THEN ivdDelta ELSE 0 END    [SkipCount]
		, CASE ivtTransactionTypeID WHEN 24 THEN ivdDelta ELSE 0 END    [BonanzaCount]
		, CASE ivtTransactionTypeID WHEN 25 THEN ivdDelta ELSE 0 END    [IssuedCount]
		, CASE ivtTransactionTypeID WHEN 26 THEN ivdDelta ELSE 0 END    [PlayBackCount]
		, CASE ivtTransactionTypeID WHEN 27 THEN ivdDelta ELSE 0 END    [DamagedCount]
    	, CASE ivtTransactionTypeID WHEN 32 THEN ivdDelta ELSE 0 END    [TransferCount]
	from InventoryItem 
	join InvTransaction on iiInventoryItemID = ivtInventoryItemID
	join InvTransactionDetail on ivtInvTransactionID = ivdInvTransactionID
	join InvLocations on ivdInvLocationID = ilInvLocationID
	left join IssueNames on ivtIssueNameID = inIssueNameID
	left join ProductItem pi on pi.ProductItemID = iiProductItemID
	left join ProductGroup pg on pi.ProductGroupID = pg.ProductGroupID
	where 
	(pi.OperatorID = @OperatorID)
	and (ivtGamingDate between @StartDate and @EndDate)
	and (ivtGamingSession = @Session or @Session = 0)
	and (ilMachineID <> 0 or ilStaffID <> 0)
	and pi.ProductTypeID in (1,2,3,4, 16)
	and pi.SalesSourceID = 1    -- Inventory source sale
	)
	insert into @Sales
	(
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, GroupName, PackageName, ItemName, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount,TransferCount
	)
	select 
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, GroupName, PackageName, ItemName, Price
		, (IssueCount + ReturnCount + DamageCount + SkipCount + TransferCount)  [Qty]
		, 0  [Register Sales]
		, Price * (IssueCount + ReturnCount + DamageCount + SkipCount +TransferCount) [Floor Sales]    -- ADD since these qtys are negative
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount
	from FloorSales
	
	-- Now for our resultset
	insert into @PaperSales
	select  
	GamingDate, SessionNo, StaffID, ProdTypeID, soldFromMachineId, GroupName, PackageName, ItemName, Price
	, sum(Qty)
	, sum(RegisterPaper)
	, sum(FloorPaper)
	from @Sales
	group by 
	GamingDate, SessionNo, StaffID, ProdTypeID, soldFromMachineId, GroupName, PackageName, ItemName, Price;

	-- This statement will return the table variable to the caller
	RETURN 
END





GO


