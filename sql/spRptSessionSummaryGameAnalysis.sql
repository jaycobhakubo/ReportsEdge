USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryGameAnalysis]    Script Date: 09/29/2015 10:45:29 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionSummaryGameAnalysis]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionSummaryGameAnalysis]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionSummaryGameAnalysis]    Script Date: 09/29/2015 10:45:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[spRptSessionSummaryGameAnalysis]
(
----------------------------------------------------------------------------
-- 20150929 tmp: US4259 - Add support for multiple game categories
----------------------------------------------------------------------------

	@OperatorID		AS INT,
	@StartDate		AS DATETIME,
	@Session		AS INT
)	

As begin
	Set nocount on;
--Set @OperatorID = 1
--Set @StartDate = '12/01/2013'
--Set @EndDate = '12/01/2013'
--Set @Session = 1

Declare @EndDate as DateTime

Set @EndDate = @StartDate 	

Declare @GameCategoryResults table
(	GameCategoryID int,
	GCName nvarchar(64),
	Payouts money,
	ElectronicSales money,
	PaperSales money,
	TotalSales money,
	Profit money
)

------ Insert Electronic Sales -------------------------------------------------
Insert into @GameCategoryResults
(
	GameCategoryID,
	GCName,
	ElectronicSales
)
SELECT  rdi.GameCategoryID,
		rdi.GameCategoryName,
		SUM(rd.Quantity * rdi.Qty * rdi.Price) 
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
    And rd.VoidedRegisterReceiptID IS NULL  
	AND rdi.CardMediaID = 1 
Group By rdi.GameCategoryID, rdi.GameCategoryName


------------------- Insert Paper Sales -------------------------------------------------
Declare 
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
	FloorPaper      money,
	GameCategoryID	int
)

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
		GameCategoryID	int,
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
		, GameCategoryID
		, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount,TransferCount, IsQuickPick
	)
	SELECT	
			rr.GamingDate, sp.GamingSession, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName
		, rdi.ProductItemName
		, rdi.GameCategoryID
		, rdi.Price
		, SUM(rd.Quantity * rdi.Qty)                [Qty]
		, SUM(rd.Quantity * rdi.Qty * rdi.Price)    [RegisterPaper]
		, 0                                         [FloorPaper]
		, 0, 0, 0, 0, 0, 0, 0, 0
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		(rr.GamingDate between @StartDate and @EndDate)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 1
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID = 16					-- 04/18/2014 tmp seperated CBB sales
		And (@Session = 0 or sp.GamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rdi.GameCategoryID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

	-- Account for returns
	INSERT INTO @Sales
	(
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, soldFromMachineId
		, GroupName
		, PackageName
		, ItemName
		, GameCategoryID
		, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount, IsQuickPick
	)
	SELECT	
			rr.GamingDate, sp.GamingSession, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName
		, rdi.ProductItemName
		, rdi.GameCategoryID
		, rdi.Price
		, SUM( -1 * rd.Quantity * rdi.Qty)                  [Qty]
		, SUM( -1 * rd.Quantity * rdi.Qty * rdi.Price)      [RegisterPaper]
		, 0                                                 [FloorPaper]
		, 0, 0, 0, 0, 0, 0 , 0, 0                                  -- counts
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		(rr.GamingDate between @StartDate and @EndDate)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 3        -- returns
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID = 16			-- 04/18/2013 tmp separated CBB sales
		And (@Session = 0 or sp.GamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rdi.GameCategoryID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

	
	-- Insert Paper CBB Sales from the register
	--
	INSERT INTO @Sales
	(
		  GamingDate, SessionNo, StaffID
		, ProdTypeID
		, soldFromMachineId
		, GroupName
		, PackageName
		, ItemName
		, GameCategoryID
		, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount,TransferCount, IsQuickPick
	)
	SELECT	
		  rr.GamingDate, sp.GamingSession, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName
		, rdi.ProductItemName
		, rdi.GameCategoryID
		, rdi.Price
		, SUM(rdi.Qty)								[Qty]
		, SUM(rdi.Qty * rdi.Price)					[RegisterPaper]
		, 0                                         [FloorPaper]
		, 0, 0, 0, 0, 0, 0,0,
		bch.bchIsQuickPick
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN BingoCardHeader bch on (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID)
		JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		(rr.GamingDate between @StartDate and @EndDate)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 1
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID in (1, 2, 3, 4)								-- CBB Product Type's
		And (@Session = 0 or sp.GamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY bch.bchIsQuickPick, rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rdi.GameCategoryID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

	-- Account for returns
	INSERT INTO @Sales
	(
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, soldFromMachineId
		, GroupName
		, PackageName
		, ItemName
		, GameCategoryID
		, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount, IsQuickPick
	)
	SELECT	
			rr.GamingDate, sp.GamingSession, rr.StaffID
		, rdi.ProductTypeID 
		, rr.SoldFromMachineID 
		, isnull(groupName, 'Paper')
		, rd.PackageName
		, rdi.ProductItemName
		, rdi.GameCategoryID
		, rdi.Price
		, SUM( -1 * rdi.Qty)								[Qty]
		, SUM( -1 * rdi.Qty * rdi.Price)					[RegisterPaper]
		, 0                                                 [FloorPaper]
		, 0, 0, 0, 0, 0, 0 ,0,                                  -- counts
		bch.bchIsQuickPick
	FROM RegisterReceipt rr
		JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
		JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
		JOIN BingoCardHeader bch on (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID)
		LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	Where 
		(rr.GamingDate between @StartDate and @EndDate)
		and rr.SaleSuccess = 1
		and rr.TransactionTypeID = 3        -- returns
		and rr.OperatorID = @OperatorID
		AND rdi.ProductTypeID in (1, 2, 3, 4) 					-- 04/18/2013 tmp separated CBB sales
		And (@Session = 0 or sp.GamingSession = @Session)
		and rd.VoidedRegisterReceiptID IS NULL	
		AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
		and (rdi.SalesSourceID = 2)                             -- Register source sales only
	GROUP BY bch.bchIsQuickPick, rr.OperatorID, rr.GamingDate, sp.GamingSession, rr.StaffID, rdi.ProductTypeID, rdi.GameCategoryID, rr.SoldFromMachineID, groupName, rd.PackageName, rdi.ProductItemName, rdi.Price;

	Update @Sales
	Set ItemName = ItemName + ' ' + '(QP)'
	Where ProdTypeID in (1, 2, 3, 4)
	And IsQuickPick = 1;
	
	Update @Sales
	Set ItemName = ItemName + ' ' + '(HP)'
	Where ProdTypeID in (1, 2, 3, 4)
	And IsQuickPick = 0;

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
		GameCategoryID,
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
		, ivtGameCategoryId
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
	and pi.ProductTypeID = 16
	and pi.SalesSourceID = 1    -- Inventory source sale
	)
	insert into @Sales
	(
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, GroupName
		, PackageName
		, ItemName
		, GameCategoryID
		, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount,TransferCount, IsQuickPick
	)
	select 
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, GroupName, PackageName
		, ItemName
		, GameCategoryID
		, Price
		, (IssueCount + ReturnCount + DamageCount + SkipCount + TransferCount)  [Qty]
		, 0  [Register Sales]
		, Price * (IssueCount + ReturnCount + DamageCount + SkipCount +TransferCount) [Floor Sales]    -- ADD since these qtys are negative
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount, 0
	from FloorSales
	
	-- Now for our resultset
	insert into @PaperSales
	select  
	GamingDate, SessionNo, StaffID, ProdTypeID, soldFromMachineId, GroupName, PackageName, ItemName, Price
	, sum(Qty)
	, sum(RegisterPaper)
	, sum(FloorPaper)
	, GameCategoryID
	from @Sales
	group by 
	GamingDate, SessionNo, StaffID, ProdTypeID, soldFromMachineId, GroupName, PackageName, ItemName, Price, GameCategoryID;
	
Insert into @GameCategoryResults
(
	GameCategoryID,
	GCName,
	PaperSales
)	
Select	p.GameCategoryID,
		GCName, 
		SUM(RegisterPaper) + SUM(FloorPaper)
From @PaperSales p left join GameCategory gc on p.GameCategoryID = gc.GameCategoryID
Group By p.GameCategoryID, GCName

--Select * From @PaperSales

------------------------ Insert Payouts ----------------------------------------------------------------------------------
Declare @Payouts table
(
	GameCategoryID int,
	GCName nvarchar(64),
	CashAmount money,
	CheckAmount money,
	CreditAmount money,
	MerchAmount money,
	OtherAmount money
)
--------------- Insert Bingo Game Payouts ---------------------------------------------------------
---- Insert Cash Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CashAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(Amount, 0)) 
From PayoutTrans p 
join PayoutTransBingoGame pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCash pCash on p.PayoutTransID = pCash.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Check Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CheckAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(CheckAmount, 0))
From PayoutTrans p 
join PayoutTransBingoGame pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCheck pCheck on p.PayoutTransID = pCheck.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Credit Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CreditAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(Refundable, 0)) + SUM(isnull(NonRefundable, 0))
From PayoutTrans p 
join PayoutTransBingoGame pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCredit pCredit on p.PayoutTransID = pCredit.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Merchandise Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	MerchAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(PayoutValue, 0))
From PayoutTrans p 
join PayoutTransBingoGame pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailMerchandise pm on p.PayoutTransID = pm.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Other Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	OtherAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(PayoutValue, 0))
From PayoutTrans p 
join PayoutTransBingoGame pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailOther po on p.PayoutTransID = po.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

------------------ Insert Bingo Custom Payouts --------------------------------------------------------
---- Insert Cash Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CashAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(Amount, 0)) 
From PayoutTrans p 
join PayoutTransBingoCustom pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCash pCash on p.PayoutTransID = pCash.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Check Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CheckAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(CheckAmount, 0))
From PayoutTrans p 
join PayoutTransBingoCustom pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCheck pCheck on p.PayoutTransID = pCheck.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Credit Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CreditAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(Refundable, 0)) + SUM(isnull(NonRefundable, 0))
From PayoutTrans p 
join PayoutTransBingoCustom pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCredit pCredit on p.PayoutTransID = pCredit.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Merchandise Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	MerchAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(PayoutValue, 0))
From PayoutTrans p 
join PayoutTransBingoCustom pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailMerchandise pm on p.PayoutTransID = pm.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Other Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	OtherAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(PayoutValue, 0))
From PayoutTrans p 
join PayoutTransBingoCustom pbg on p.PayoutTransID = pbg.PayoutTransID
Join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailOther po on p.PayoutTransID = po.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--------------------------- Insert Bingo Good Neighbor Payouts ------------------------------------------
---- Insert Cash Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CashAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(Amount, 0)) 
From PayoutTrans p 
join PayoutTransBingoGoodNeighbor pbgn on p.PayoutTransID = pbgn.PayoutTransID
Join SessionGamesPlayed sgp on pbgn.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCash pCash on p.PayoutTransID = pCash.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Check Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CheckAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(CheckAmount, 0))
From PayoutTrans p 
join PayoutTransBingoGoodNeighbor pbgn on p.PayoutTransID = pbgn.PayoutTransID
Join SessionGamesPlayed sgp on pbgn.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCheck pCheck on p.PayoutTransID = pCheck.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Credit Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CreditAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(Refundable, 0)) + SUM(isnull(NonRefundable, 0))
From PayoutTrans p 
join PayoutTransBingoGoodNeighbor pbgn on p.PayoutTransID = pbgn.PayoutTransID
Join SessionGamesPlayed sgp on pbgn.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCredit pCredit on p.PayoutTransID = pCredit.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Merchandise Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	MerchAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(PayoutValue, 0))
From PayoutTrans p 
join PayoutTransBingoGoodNeighbor pbgn on p.PayoutTransID = pbgn.PayoutTransID
Join SessionGamesPlayed sgp on pbgn.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailMerchandise pm on p.PayoutTransID = pm.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Other Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	OtherAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(PayoutValue, 0))
From PayoutTrans p 
join PayoutTransBingoGoodNeighbor pbgn on p.PayoutTransID = pbgn.PayoutTransID
Join SessionGamesPlayed sgp on pbgn.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailOther po on p.PayoutTransID = po.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--------------------- Insert Bingo Royalty Payouts ---------------------------------------
-- Insert Cash Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CashAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(Amount, 0)) 
From PayoutTrans p 
join PayoutTransBingoRoyalty pbr on p.PayoutTransID = pbr.PayoutTransID
Join SessionGamesPlayed sgp on pbr.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCash pCash on p.PayoutTransID = pCash.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Check Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CheckAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(CheckAmount, 0))
From PayoutTrans p 
join PayoutTransBingoRoyalty pbr on p.PayoutTransID = pbr.PayoutTransID
Join SessionGamesPlayed sgp on pbr.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCheck pCheck on p.PayoutTransID = pCheck.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Credit Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	CreditAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(Refundable, 0)) + SUM(isnull(NonRefundable, 0))
From PayoutTrans p 
join PayoutTransBingoRoyalty pbr on p.PayoutTransID = pbr.PayoutTransID
Join SessionGamesPlayed sgp on pbr.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailCredit pCredit on p.PayoutTransID = pCredit.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Merchandise Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	MerchAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(PayoutValue, 0))
From PayoutTrans p 
join PayoutTransBingoRoyalty pbr on p.PayoutTransID = pbr.PayoutTransID
Join SessionGamesPlayed sgp on pbr.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailMerchandise pm on p.PayoutTransID = pm.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

--- Insert Other Payouts
Insert into @Payouts
(
	GameCategoryID,
	GCName,
	OtherAmount
)
Select	sgc.GameCategoryId,		--US4259
		sgc.GameCategoryName,
		--sgp.GameCategoryID,
		--sgp.GCName,			--US4259
		Sum(isnull(PayoutValue, 0))
From PayoutTrans p 
join PayoutTransBingoRoyalty pbr on p.PayoutTransID = pbr.PayoutTransID
Join SessionGamesPlayed sgp on pbr.SessionGamesPlayedID = sgp.SessionGamesPlayedID
Join SessionGameCategory sgc on sgp.SessionGamesPlayedID = sgc.SessionGamesPlayedId    --US4259
Join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
Join PayoutTransDetailOther po on p.PayoutTransID = po.PayoutTransID
Where  p.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And p.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And (@Session = 0 or sp.GamingSession = @Session)
And p.VoidTransID is null
--Group By sgp.GameCategoryID, sgp.GCName --US4259 
Group By sgc.GameCategoryID, sgc.GameCategoryName

Insert into @GameCategoryResults
(
	GameCategoryID,
	GCName,
	Payouts
)
Select	GameCategoryID,
		GCName,
		SUM(isnull(CashAmount, 0)) + SUM(isnull(CheckAmount, 0)) + SUM(isnull(CreditAmount, 0)) + Sum(isnull(MerchAmount, 0)) + Sum(Isnull(OtherAmount, 0)) 
From @Payouts
Group By GameCategoryID, GCName

---- Now for the resultset 

Select isnull(GCName, 'None')as GameCategory,
	   SUM(isnull(Payouts, 0)) as Payouts,
	   SUM(isnull(ElectronicSales, 0)) + SUM(isnull(PaperSales, 0)) as SalesAmount,
	   (SUM(isnull(ElectronicSales, 0)) + SUM(isnull(PaperSales, 0))) - SUM(isnull(Payouts, 0)) as NetSales
From @GameCategoryResults
Group By GCName

Set nocount off

End




GO

