USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionSummary]    Script Date: 10/03/2014 09:12:28 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptOccasionSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptOccasionSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionSummary]    Script Date: 10/03/2014 09:12:28 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		<Travis Pollock>
-- Create date: <11/19/2012>
-- Description:	<Occasion Summary Report - Texas specific report that reports Gaming Sales and Gaming Payouts>
-- 08.09.2013 tmp: US2715 - Added the ability to filter by Charity.
-- 10.01.2014 tmp: DE12069 - Payouts did not check if the occasion schedule was deleted. 
-- =============================================

CREATE PROCEDURE [dbo].[spRptOccasionSummary]
(
@OperatorID as Int,
@StartDate as DateTime,
@EndDate as DateTime,
@CharityID as Int
)
AS
BEGIN
	
SET NOCOUNT ON;

Set ANSI_WARNINGS OFF;


-- For testing
--Set @OperatorID = 1
--Set @StartDate = '04/04/2012'
--Set @EndDate = '12/01/2012'
--Set @CharityID = 0

Declare @Results Table
	(
		gamingDate			SMALLDATETIME,
		gamingSession		Int,
		paper				MONEY,
		electronic			MONEY,
		pulltabs			MONEY,
		bingoPayouts		MONEY,
		pulltabPayouts		Money,
		bingoPrizeFees		Money,
		pulltabPrizeFees	Money,
		voidedSales			Money,
		charityName			Nvarchar(255),
		charityLicNum		Nvarchar(64),
		charityTaxID		Nvarchar(20),
		charityID			Int		
	)
	
-- Insert Paper Sales

Insert INTO @Results
(
		gamingDate,
		gamingSession,
		paper
)		
Select	fps.GamingDate,
		fps.SessionNo,
		SUM(fps.RegisterPaper + fps.FloorPaper)
From FindPaperSales(@OperatorID, @StartDate, @EndDate, 0) fps  
Group By fps.GamingDate, fps.SessionNo

-- Insert Electronic Sales		

Insert Into @Results
	(
		gamingDate,
		gamingSession,
		electronic
	)	
SELECT	rr.GamingDate,
		sp.GamingSession,
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
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	and rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
GROUP BY rr.GamingDate, sp.GamingSession

INSERT INTO @Results
	(
		gamingDate,
		gamingSession,
		electronic
	)
SELECT	rr.GamingDate,
		sp.GamingSession,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	and rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
GROUP BY rr.GamingDate, sp.GamingSession

-- Insert Pull Tab Rows	

Insert INTO @Results
(
		gamingDate,
		gamingSession,
		pulltabs
)		
Select	fpt.GamingDate,
		fpt.SessionNo,
		SUM(fpt.RegisterPulltab + fpt.FloorPulltab)
From FindPulltabSales(@OperatorID, @StartDate, @EndDate, 0) fpt  
Group By fpt.GamingDate, fpt.SessionNo	

--Insert Void Rows

INSERT INTO @Results
	(
		gamingDate,
		gamingSession,
		voidedSales
	)
SELECT	rr.GamingDate,
		sp.GamingSession,
		SUM(rd.Quantity * rdi.Qty * rdi.Price)		
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.OriginalReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	And rr.SaleSuccess = 1
	And rr.TransactionTypeID = 2
	And rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID in (1, 2, 3, 4, 5, 16, 17)
GROUP BY rr.GamingDate, sp.GamingSession

-- Insert Bingo Payouts
Insert into @Results
(
	gamingDate,
	gamingSession,
	bingoPayouts,
	bingoPrizeFees
)
Select os.Date as Date,
	os.Occasion as Session, 
	IsNull(SUM(osb.PrizePerFullWinner * osb.FullWinners), 0) + IsNull(SUM(osb.PrizePerHalfWinner * osb.HalfWinners), 0) + IsNull(SUM(osb.NonCashPrize), 0) as TotalBingoPrizeAwarded,
	SUM(osb.PrizeFee) as BingoPrizeFee
From OccasionScheduleBingo osb join OccasionSchedule os on osb.OccasionScheduleID = os.OccasionScheduleID
Where os.Date >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And	os.Date <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And os.OperatorID = @OperatorID
And os.IsDeleted is null		-- DE12069
Group By os.Date, os.Occasion

-- Insert PullTab Payouts
Insert into @Results
(
	gamingDate,
	gamingSession,
	pulltabPayouts,
	pulltabPrizeFees
)
Select os.Date as Date,
	os.Occasion as Session, 
	IsNull(SUM(osp.LargePrizes), 0) + IsNull(SUM(osp.SmallPrizes), 0) as TotalPullTabPrizeAwarded,
	IsNull(SUM(osp.LargePrizeFee), 0) + IsNull(SUM(osp.SmallPrizeFee), 0) as PullTabPrizeFee
From OccasionSchedulePullTab osp join OccasionSchedule os on osp.OccasionScheduleID = os.OccasionScheduleID
Where os.Date >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And	os.Date <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And os.OperatorID = @OperatorID
And os.IsDeleted is null		-- DE12069
Group By os.Date, os.Occasion

UPDATE @Results
SET paper = 0 WHERE paper IS NULL

UPDATE @Results
SET electronic = 0 WHERE electronic IS NULL

UPDATE @Results
SET pulltabs = 0 WHERE pulltabs IS NULL

UPDATE @Results
SET voidedSales = 0 WHERE voidedSales IS NULL

UPDATE @Results
Set bingoPayouts = 0 WHERE bingoPayouts IS NULL

UPDATE @Results
Set bingoPrizeFees = 0 WHERE bingoPrizeFees IS NULL

Update @Results
Set pulltabPayouts = 0 Where pulltabPayouts IS NULL

Update @Results
Set pulltabPrizeFees = 0 Where pulltabPrizeFees IS NULL


-- Update the results table with the charity assigned to the session.
Update @Results
Set charityName = Name,
	charityLicNum = LicenseNumber,
	charityTaxID = TaxPayerId,
	charityID = sp.CharityId From @Results rs, Charity c join SessionPlayed sp on sp.CharityId = c.CharityId
Where sp.OperatorID = @OperatorID
And rs.gamingDate = sp.GamingDate
And rs.gamingSession = sp.GamingSession
And sp.IsOverridden = 0

select gamingDate,
	gamingSession,
	sum(paper)as Paper,
	sum(electronic) as Electronic,
	Sum(pulltabs) as PullTabs,
	Sum(rs.paper + rs.electronic + rs.pulltabs) as TotalSales,
	SUM(bingoPayouts) as BingoPayouts,
	SUM(pulltabPayouts) as PullTabPayouts,
	SUM(rs.bingoPayouts + rs.pulltabPayouts) as TotalPayouts,
	Sum(rs.paper + rs.electronic + rs.pulltabs) - SUM(rs.bingoPayouts + rs.pulltabPayouts) as NetSales,
	SUM(rs.bingoPrizeFees + rs.pulltabPrizeFees) as PrizeFeesCollected,
	Sum(voidedSales) as VoidedSales,
	charityName,
	charityLicNum,
	charityTaxID
From @Results rs
Where rs.charityID = @CharityID or @CharityID = 0
Group BY gamingDate, gamingSession, charityName, charityLicNum, charityTaxID
Order By gamingDate, gamingSession

Set Nocount off

End


















GO

