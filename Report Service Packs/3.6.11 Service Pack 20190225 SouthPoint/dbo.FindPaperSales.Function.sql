USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindPaperSales]    Script Date: 2/25/2019 10:38:40 AM ******/
DROP FUNCTION [dbo].[FindPaperSales]
GO

/****** Object:  UserDefinedFunction [dbo].[FindPaperSales]    Script Date: 2/25/2019 10:38:40 AM ******/
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
-- 2013.4.18 TMP: Separated CBB sales so that CBB sales can be identified by (QP) and (HP)
-- 2014.2.13 TMP: Only CBB prompt product types were being separated. Modified to seperate all CBB sales.
-- 2014.04.03 TMP: CBB sales were being doubled when the CBB game was replayed for a session. 
-- 2015.03.10 TMP: DE12325 CBB sales were doubled if a CBB HP and CBB QP were purchased in the same transaction. 
-- 2016.04.01 TMP: DE12925 CBB sales are off when the card count or quantity sold in a single product is greater than 1.
-- Changed the CBB calculation based on the jurisdiction so that it does not separate QP and HP unless in Nevada. 
-- This corrects an issue with calculating the CBB sales when the card count is greater than 1.  
-- 20190225 tmp: For SouthPoint updated to only get inventory sales after 2/21/2019.
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
		TransferCount   int,
		IsQuickPick		int
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
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount,TransferCount, IsQuickPick
	)
	SELECT	
			--rr.GamingDate
			--, sp.GamingSession
			rd.PlayGamingDate
			, rd.PlayGamingSession
			, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName, rdi.ProductItemName
		, rdi.Price
		, SUM(rd.Quantity * rdi.Qty)                [Qty]
		, SUM(rd.Quantity * rdi.Qty * rdi.Price)    [RegisterPaper]
		, 0                                         [FloorPaper]
		, 0, 0, 0, 0, 0, 0, 0, 0
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
--		(rr.GamingDate between @StartDate and @EndDate)
		rd.PlayGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and rd.PlayGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 1
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID = 16					-- 04/18/2014 tmp seperated CBB sales
--		And (@Session = 0 or sp.GamingSession = @Session)
		and (@Session = 0 or rd.PlayGamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID
		--, rr.GamingDate
		--, sp.GamingSession
		, rd.PlayGamingDate
		, rd.PlayGamingSession
		, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

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
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount, IsQuickPick
	)
	SELECT	
			--rr.GamingDate
			--, sp.GamingSession
			rd.PlayGamingDate
			, rd.PlayGamingSession
			, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName, rdi.ProductItemName
		, rdi.Price
		, SUM( -1 * rd.Quantity * rdi.Qty)                  [Qty]
		, SUM( -1 * rd.Quantity * rdi.Qty * rdi.Price)      [RegisterPaper]
		, 0                                                 [FloorPaper]
		, 0, 0, 0, 0, 0, 0 , 0, 0                                  -- counts
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		--(rr.GamingDate between @StartDate and @EndDate)
		rd.PlayGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and rd.PlayGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 3        -- returns
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID = 16			-- 04/18/2013 tmp separated CBB sales
		--And (@Session = 0 or sp.GamingSession = @Session)
		and (@Session = 0 or rd.PlayGamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID
		--, rr.GamingDate
		--, sp.GamingSession
		, rd.PlayGamingDate
		, rd.PlayGamingSession
		, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

	--------------------------------------------------------------------------------------------------------------
	-- Insert Paper CBB Sales from the register
	--	
declare @OperatorState nvarchar(32) = 0
select	@OperatorState = a.State
from	Address a join Operator o on o.AddressID = a.AddressID
where	o.OperatorID = @OperatorID;

if @OperatorState = 'NV'
begin
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
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount,TransferCount, IsQuickPick
	)
	SELECT	
		  --rr.GamingDate
		  --, sp.GamingSession
		  rd.PlayGamingDate
		  , rd.PlayGamingSession
		  , rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName, rdi.ProductItemName
		, rdi.Price
		, COUNT(bch.bchIsQuickPick)					[Qty]				--DE12925 Start
		, sum(rdi.Price)							[RegisterPaper]
--		, SUM(rdi.Qty)								[Qty]				
--		, SUM(rdi.Qty * rdi.Price)					[RegisterPaper]		--DE12925 End
		, 0                                         [FloorPaper]
		, 0, 0, 0, 0, 0, 0,0,
		bch.bchIsQuickPick
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--		JOIN (Select Distinct(bchRegisterDetailItemID), bchIsQuickPick From BingoCardHeader) as bch on bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID	--DE12325
		JOIN BingoCardHeader bch on (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID)																	--DE12325
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		Join (select Max(SessionGamesPlayedID) as SessionGamesPlayedID, SessionPlayedID, GameName, GameSeqNo, DisplayGameNo, DisplaypartNo	-- Account for a game being replayed. 
			from SessionGamesPlayed		
			Group By SessionPlayedID, GameSeqNo, DisplayGameNo, DisplayPartNo, GameName
			) As SGP on RD.SessionPlayedID = SGP.SessionPlayedID and bchSessionGamesPlayedID = SGP.SessionGamesPlayedID
	Where 
		--(rr.GamingDate between @StartDate and @EndDate)
		rd.PlayGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and rd.PlayGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 1
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID in (1, 2, 3, 4)								-- CBB Product Type's
		--And (@Session = 0 or sp.GamingSession = @Session)
		And (@Session = 0 or rd.PlayGamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY bch.bchIsQuickPick, rr.OperatorID
		--, rr.GamingDate
		--, sp.GamingSession
		, rd.PlayGamingDate
		, rd.PlayGamingSession
		, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

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
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount, IsQuickPick
	)
	SELECT	
			--rr.GamingDate
			--, sp.GamingSession
			rd.PlayGamingDate
			, rd.PlayGamingSession
			, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName, rdi.ProductItemName
		, rdi.Price
		, COUNT(bch.bchIsQuickPick)	* -1				[Qty]				--DE12925 Start
		, sum(rdi.Price) * -1							[RegisterPaper]
--		, SUM( -1 * rdi.Qty)							[Qty]
--		, SUM( -1 * rdi.Qty * rdi.Price)				[RegisterPaper]		--DE12925 End
		, 0                                             [FloorPaper]
		, 0, 0, 0, 0, 0, 0 ,0,                                  -- counts
		bch.bchIsQuickPick
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--		JOIN (Select Distinct(bchRegisterDetailItemID), bchIsQuickPick From BingoCardHeader) as bch on bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID	--DE12325
		JOIN BingoCardHeader bch on (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID)																	--DE12325
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		Join (select Max(SessionGamesPlayedID) as SessionGamesPlayedID, SessionPlayedID, GameName, GameSeqNo, DisplayGameNo, DisplaypartNo	-- Account for a game being replayed.
			from SessionGamesPlayed		
			Group By SessionPlayedID, GameSeqNo, DisplayGameNo, DisplayPartNo, GameName
			) As SGP on RD.SessionPlayedID = SGP.SessionPlayedID and bchSessionGamesPlayedID = SGP.SessionGamesPlayedID
	Where 
--		(rr.GamingDate between @StartDate and @EndDate)
		rd.PlayGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and rd.PlayGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 3        -- returns
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID in (1, 2, 3, 4) 					-- 04/18/2013 tmp separated CBB sales
		--And (@Session = 0 or sp.GamingSession = @Session)
		and (@Session = 0 or rd.PlayGamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY bch.bchIsQuickPick, rr.OperatorID
		--, rr.GamingDate
		--, sp.GamingSession
		, rd.PlayGamingDate
		, rd.PlayGamingSession
		, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

	Update @Sales
	Set ItemName = ItemName + ' ' + '(QP)'
	Where ProdTypeID in (1, 2, 3, 4)
	And IsQuickPick = 1;
	
	Update @Sales
	Set ItemName = ItemName + ' ' + '(HP)'
	Where ProdTypeID in (1, 2, 3, 4)
	And IsQuickPick = 0;
end	
else
begin
INSERT INTO @Sales
	(
		GamingDate
		, SessionNo
		, StaffID
		, ProdTypeID
		, soldFromMachineId
		, GroupName
		, PackageName
		, ItemName
		, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount
		, SkipCount
		, BonanzaCount
		, IssueCount
		, PlaybackCount
		, DamageCount
		, TransferCount
		, IsQuickPick
	)
	SELECT	
			--rr.GamingDate
			--, sp.GamingSession
			rd.PlayGamingDate
			, rd.PlayGamingSession
			, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName, rdi.ProductItemName
		, rdi.Price
		, SUM(rd.Quantity * rdi.Qty)                [Qty]
		, SUM(rd.Quantity * rdi.Qty * rdi.Price)    [RegisterPaper]
		, 0                                         [FloorPaper]
		, 0, 0, 0, 0, 0, 0, 0, 0
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		--(rr.GamingDate between @StartDate and @EndDate)
		rd.PlayGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and rd.PlayGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 1
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID in (1,2,3,4)				
--		And (@Session = 0 or sp.GamingSession = @Session)
		and (@Session = 0 or rd.PlayGamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID
		--, rr.GamingDate
		--, sp.GamingSession
		, rd.PlayGamingDate
		, rd.PlayGamingSession
		, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

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
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount, IsQuickPick
	)
	SELECT	
			--rr.GamingDate
			--, sp.GamingSession
			rd.PlayGamingDate
			, rd.PlayGamingSession
			, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName, rdi.ProductItemName
		, rdi.Price
		, SUM( -1 * rd.Quantity * rdi.Qty)                  [Qty]
		, SUM( -1 * rd.Quantity * rdi.Qty * rdi.Price)      [RegisterPaper]
		, 0                                                 [FloorPaper]
		, 0, 0, 0, 0, 0, 0 , 0, 0                                  -- counts
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		--LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		--(rr.GamingDate between @StartDate and @EndDate)
		rd.PlayGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and rd.PlayGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 3        -- returns
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID in (1,2,3,4)
		--And (@Session = 0 or sp.GamingSession = @Session)
		and (@Session = 0 or rd.PlayGamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID
		--, rr.GamingDate
		--, sp.GamingSession
		, rd.PlayGamingDate
		, rd.PlayGamingSession
		, rr.StaffID, rdi.ProductTypeID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;
end;
	

	
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
	and (ivtGamingDate > '02/21/2019')
	and (ivtGamingSession = @Session or @Session = 0)
	and (ilMachineID <> 0 or ilStaffID <> 0)
	and pi.ProductTypeID = 16
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
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount,TransferCount, IsQuickPick
	)
	select 
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, GroupName, PackageName, ItemName, Price
		, (IssueCount + ReturnCount + DamageCount + SkipCount + TransferCount + BonanzaCount)  [Qty]
		, 0  [Register Sales]
		, Price * (IssueCount + ReturnCount + DamageCount + SkipCount + TransferCount + BonanzaCount) [Floor Sales]    -- ADD since these qtys are negative
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount, 0
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

