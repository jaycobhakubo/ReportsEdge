USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStationsGroupedSessionSummaryDaily]    Script Date: 04/10/2019 14:36:53 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptStationsGroupedSessionSummaryDaily]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptStationsGroupedSessionSummaryDaily]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStationsGroupedSessionSummaryDaily]    Script Date: 04/10/2019 14:36:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO







-- =============================================
-- Author:		Travis Pollock
-- Create date: 12/16/2016
-- Description:	Stations Casino version of the spRptGroupedSessionSummaryReport
--              to include station bucks. Returns the daily totals.
-- 20190410 tmp: Do not include backup progressive increases.
-- =============================================


CREATE PROCEDURE [dbo].[spRptStationsGroupedSessionSummaryDaily]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime	 
AS

SET NOCOUNT ON;	

declare @Session int = 0;

select	sp.GamingDate,
		isnull(sum(ManAttendance), 0) as ManAttendance, 
		isnull(sum(ElectronicSales), 0) as ElectronicSales,
		isnull(sum(PaperSales), 0) as PaperSales, 
		isnull(sum(ValidationSales), 0) as ValidationSales,
		isnull(	sum(PaperSales) 
				+ sum(ElectronicSales) 
				+ sum(ValidationSales), 0
			   ) as TotalSales, 
		isnull(sum(StationBucksAmount), 0) as StationBucksAmount,
		isnull(sum(StationGiftCertAmount), 0) as StationGiftCertAmount,
		isnull(sum(BingoOtherSales) 
				+ (sum(Discounts) * -1) -- Stored as a positive number
				- isnull(sum(StationBucksAmount), 0) 
				- isnull(sum(StationGiftCertAmount), 0) , 0
			   ) as Coupons,
		isnull(sum(DeviceFees), 0) as DeviceFees,
		isnull( sum(ActualCash) 
				+ sum(DebitCredit) 
				+ sum(Checks) 
				+ sum(MoneyOrders) 
				+ sum(GiftCards) 
				+ sum(Coupons)
				+ sum(Chips), 0
			   ) as ActualCash,
		isnull( sum(CashPrizes) 
				+ sum(CheckPrizes) 
				+ sum(MerchandisePrizes) 
				+ sum(OtherPrizes), 0
			   ) as PrizesPaid,
		isnull(sum(CashPrizes), 0) as CashPrizes,
		isnull(sum(AccrualPayouts), 0) as AccrualPayouts ,
		isnull(sum(AccrualIncrease), 0)
			- isnull(sum(IncreaseAmount), 0) as AccrualIncrease,
		isnull(sum(BeginningBank), 0) as BeginningBank,
		isnull(sum(EndingBank), 0) as EndingBank,
		isnull(sum(BankFill), 0) as BankFill,
		isnull(sum(AccrualCashPayouts), 0) as AccrualCashPayouts
from	SessionSummary ss
		join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
		left join (	select	GamingDate,
							GamingSession,
							sum(StationBucksAmount) as StationBucksAmount  
					from	dbo.FindStationBucks(@OperatorID, @StartDate, @EndDate, @Session)
					group by GamingDate, 
							GamingSession
				   ) fsb 
							on ( fsb.GamingDate = sp.GamingDate
							     and fsb.GamingSession = sp.GamingSession
							    )
		left join (	select	GamingDate,
							GamingSession,
							sum(StationGiftCertAmount) as StationGiftCertAmount  
					from	dbo.FindStationGiftCert(@OperatorID, @StartDate, @EndDate, @Session)
					group by GamingDate,
							GamingSession
				   ) fsgc 
							on ( fsgc.GamingDate = sp.GamingDate	
								 and fsgc.GamingSession = sp.GamingSession
								)
		left join ( select	GamingDate,
							GamingSession,
							IncreaseAmount  
					from	dbo.FindStationsAccrualBackups(@OperatorID, @StartDate, @EndDate, @Session)
				   ) fsab 
							on ( fsab.GamingDate = sp.GamingDate
								 and fsab.GamingSession = sp.GamingSession )
where   sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and sp.OperatorID = @OperatorID
group by sp.GamingDate
order by GamingDate;
  
Set nocount off;	







GO

