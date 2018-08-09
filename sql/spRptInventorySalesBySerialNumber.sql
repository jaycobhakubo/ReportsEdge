USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventorySalesBySerialNumber]    Script Date: 02/04/2014 08:33:19 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventorySalesBySerialNumber]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventorySalesBySerialNumber]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventorySalesBySerialNumber]    Script Date: 02/04/2014 08:33:19 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptInventorySalesBySerialNumber] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Reports sales based on inventory usage.
--               Logic was copied from FindPaperSales>
-- =============================================
	@OperatorID	AS INT,
	@StartDate		AS DATETIME,
	@EndDate		AS DATETIME
AS
	
SET NOCOUNT ON

-- Testing
--Declare @OperatorID		AS INT,
--		@StartDate		AS DATETIME,
--		@EndDate		AS DATETIME

--Set @OperatorID = 1
--Set @StartDate = '1/01/2014'
--Set @EndDate = '1/01/2014'

Declare @Results TABLE 
(
	ProductType		nvarchar(50),
	GroupName		nvarchar(64),
	ItemName		nvarchar(64),
	SerialNumber	nvarchar(30),
	Qty             int,
	Price			money,
	Amount		    money
)

	-- Temp table to include inventory counts also...
	declare @Sales TABLE 
	(
		GamingDate      datetime,
		SessionNo       int,
		StaffID         int,
		ProdTypeID      int,
		SerialNo		nvarchar(30),
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
		SerialNo,
		GroupName,
		PackageName,
		ItemName,
		Price,
		ReturnCount, 
		SkipCount, 
		BonanzaCount, 
		IssueCount, 
		PlaybackCount, 
		DamageCount, 
		TransferCount
	) as 
	(select 
		ivtGamingDate
		, ivtGamingSession
		, ilStaffID
		, pi.ProductTypeID
		, iiSerialNo
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
	and (ilMachineID <> 0 or ilStaffID <> 0)
	)
	insert into @Sales
	(
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, SerialNo
		, GroupName, PackageName, ItemName, Price
		, Qty
		, RegisterPaper
		, FloorPaper
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount,TransferCount, IsQuickPick
	)
	select 
			GamingDate, SessionNo, StaffID
		, ProdTypeID
		, SerialNo
		, GroupName, PackageName, ItemName, Price
		, (IssueCount + ReturnCount + DamageCount + SkipCount + TransferCount)  [Qty]
		, 0  [Register Sales]
		, Price * (IssueCount + ReturnCount + DamageCount + SkipCount +TransferCount) [Floor Sales]    -- ADD since these qtys are negative
		, ReturnCount, SkipCount, BonanzaCount, IssueCount, PlaybackCount, DamageCount, TransferCount, 0
	from FloorSales
	
	-- Now for our resultset
	insert into @Results
	select	ProductType,  
			ISNULL(GroupName, 'N/A'), 
			ItemName,
			SerialNo, 
			sum(Qty),
			Price,
			sum(FloorPaper)
	from @Sales s join ProductType pt on s.ProdTypeID = pt.ProductTypeID
	group by ItemName, SerialNo, Price, GroupName, ProductType

	Select * From @Results
	
	Set NOCOUNT OFF
	

GO

