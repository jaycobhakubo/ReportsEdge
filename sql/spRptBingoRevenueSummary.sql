USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBingoRevenueSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBingoRevenueSummary]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






-- =============================================
-- Author:		Barry J. Silver
-- Description:	CASH BASED
--              Provide periodic summary of sales and payout info
--              This report is offered in 2 styles: Cash Based and Accrual Based.
--              Cash Based gross revenue=sales-prizes-payouts
--              Accrual based gross rev=sales-prizes-accrual increases
-- Note: sp named differently than its twin (spRptBingoRevenueSummaryAccrual) to retain biz logic in Crystal.
--
-- BJS 05/31/2011: US1851 new report
-- BJS 06/17/2011: DE8676 session number
-- bjs 06/21/2011: missing bingo sales
-- LJL 06/23/2011: Removed voided payouts from result set
-- BDH 02/22/2012: Fixed discount calculation
-- 2012.04.05 jkn: Adding support for returning data based on a fiscal date
--		not only the date range
-- TMP 01/19/2013: Removed the concession and merchandise product types.
-- jkn 03/14/2013: Changed the size of the session numbers from TINYINT to INT.  
--	This caused an issue during the NV audit when paper was issued to session 
--	number 8877 and this overflowed the session number buffer, the size was
--	then increased to and INT and all is well now.
-- TMP 07/16/2013: US2702 Changed the payout calculations to use different joins.
--  Before NULL values in Results.SessionNumber were being joined to the SessionPlayed
--  table where it did not find a match. As the SessionPlayed table grows so did the time it
--  took to run the stored procedure.
-- TMP 01/03/2014: Removed the Fiscal Date setting so that the report uses the calendar year Jan 1 to Dec 31.
--                 The fiscal date global setting is not supported.
-- TMP 01/03/2014: Changed the report to use the Session Summary table to improve the speed of the report.
--                 Requires the data to be generated in the Session Summary module in order to populate the report. 
-- 20150925(knc): Coupon sale added.
-- 2015.10.02: DE12771 Fixed issue with when there are no coupon sales no data would be returned
-- =============================================
CREATE PROCEDURE  [dbo].[spRptBingoRevenueSummary] 
(
--declare
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session    int
	
	--set @OperatorID	= 1
	--set @StartDate = '9/18/2015 00:00:00'	
	--set @EndDate	= '9/18/2015 00:00:00'	
	--set @Session    = 0

)
AS
BEGIN
    SET NOCOUNT ON;
    
SET @OperatorID = NULLIF(@OperatorID, 0);
SET @Session = NULL;--NULLIF(@Session, 0);
   
Declare @ReportStart datetime,
		@ReportEnd datetime,
		@FiscalYearStart datetime
		

set @StartDate = cast ('01' + '/' + '01'  + '/' +
						   cast ((datepart(year, @EndDate) - 1) as nvarchar) as datetime)

set @FiscalYearStart = dateadd(year, 1, @StartDate)


DECLARE @Results TABLE
(
	 Yr					INT
	,FiscalYearStart	SMALLDATETIME
	,MonthInt			INT
	,MonthNm			NVARCHAR(32)	
	,SessionPlayedID	INT
	,GamingDate			SMALLDATETIME	
	,SessionNumber		INT
	,Attendance			INT
	,BingoSales			MONEY
	,BingoPrizes		MONEY
	,AccrualPayouts		MONEY
	,AccrualIncreases	MONEY
);
INSERT INTO @Results
(
	SessionPlayedID,
	GamingDate,
	SessionNumber,
	Attendance,
	BingoSales,
	BingoPrizes,
	AccrualPayouts,
	AccrualIncreases
)

Select	sp.SessionPlayedID,
		sp.GamingDate,
		sp.GamingSession,
		ss.ManAttendance,
		ISNULL(((SUM(ss.PaperSales) + SUM(ss.ElectronicSales) + SUM(ss.BingoOtherSales) - SUM(ss.Discounts)) + isnull(cpn.Coupon, 0)) ,   0) as BingoSales,
		ISNULL((SUM(ss.CashPrizes) + SUM(ss.CheckPrizes) + SUM(ss.MerchandisePrizes)), 0) as BingoPrizes,
		ss.AccrualPayouts,
		ss.AccrualIncrease
From SessionSummary ss join SessionPlayed sp on ss.SessionPlayedID = sp.SessionPlayedID
    left join (select Sum(NetSales) as Coupon, GamingSession
               from dbo.FindCouponSales(@OperatorID, @StartDate,@EndDate, ISNULL(@Session, 0))
			   group by GamingSession) cpn on cpn.GamingSession = sp.GamingSession
Where sp.OperatorID = @OperatorID
    And sp.GamingDate >= @StartDate
    And sp.GamingDate <= @EndDate
    And sp.GamingSession = @Session or @Session is null
Group BY sp.GamingDate, sp.SessionPlayedID, sp.GamingSession, ss.ManAttendance, ss.AccrualPayouts, ss.AccrualIncrease, cpn.Coupon

UPDATE @Results
SET  Yr = DATEPART(year, r.GamingDate)
	,FiscalYearStart = @FiscalYearStart
	,MonthInt = MONTH(r.GamingDate)
	,MonthNm = DATENAME(MONTH, r.GamingDate)
FROM @Results r

SELECT 
	 Yr
	,FiscalYearStart
	,MonthInt
	,MonthNm
	,GamingDate
	,SessionNumber
	,Attendance
	,BingoSales
	,BingoPrizes
	,AccrualPayouts
	,AccrualIncreases
FROM @Results;
    
    SET NOCOUNT OFF;
END;














GO


