USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBoydGroupedSessionSummaryDaily]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBoydGroupedSessionSummaryDaily]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Travis Pollock
-- Create date: 07/27/2018
-- Description:	Boyd version of the spRptGroupedSessionSummaryReport
--              to include Star POints. Returns the daily totals.
-- =============================================


CREATE PROCEDURE [dbo].[spRptBoydGroupedSessionSummaryDaily]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime	 
AS

SET NOCOUNT ON;	

declare @Session int = 0;

-- Get the Bonus Validation amount to subtract the amount from Validations
-- Get the Bonus Validation amount to subtract the amount from Validations
declare @BonusBall table
(
	GamingDate			datetime
	, GamingSession		int
	, BonusAmount		money
)
insert into @BonusBall
(
	GamingDate
	, GamingSession
	, BonusAmount
)
select	rr.GamingDate
		, sp.GamingSession
		, case	when rr.TransactionTypeId = 1 then sum((rd.Quantity * rdi.Qty) * rdi.Price)  
				when rr.TransactionTypeId = 3 then sum((-1 * rd.Quantity * rdi.Qty) * rdi.Price)  
		end
from	RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
		join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
where	rr.OperatorID = @OperatorID
		and rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
        and (@Session = 0 or sp.GamingSession = @Session)
        and rr.SaleSuccess = 1
        and rd.VoidedRegisterReceiptID is null
        and rr.TransactionTypeID in (1, 3)
        and rdi.ProductTypeID = 19
group by rr.GamingDate
	, sp.GamingSession
	, rr.TransactionTypeID; 

select	sp.GamingDate,
		isnull(sum(ManAttendance), 0) as ManAttendance, 
		isnull(sum(ElectronicSales), 0) as ElectronicSales,
		isnull(sum(PaperSales), 0) as PaperSales, 
		isnull(sum(BonusAmount), 0) as BonusBall,
		isnull(sum(ValidationSales), 0) as Validations,
		isnull(sum(ValidationSales), 0) 
			- isnull(sum(BonusAmount), 0)
				as ValidationSales,
		isnull(	sum(PaperSales) 
				+ sum(ElectronicSales) 
				+ sum(ValidationSales), 0
			   ) as TotalSales, 
		isnull(sum(StarAmount), 0) as StarAmount,
		isnull(sum(BingoOtherSales) 
				+ (sum(Discounts) * -1) -- Stored as a positive number
				+ (sum(Coupons) * -1)	-- Stored as a positive number 
				- isnull(sum(StarAmount), 0) 
				, 0
			   ) as Coupons,
		isnull(sum(DeviceFees), 0) as DeviceFees,
		isnull( sum(ActualCash) 
				+ sum(DebitCredit) 
				+ sum(Checks) 
				+ sum(MoneyOrders) 
				+ sum(GiftCards) 
				+ sum(Chips), 0
			   ) as ActualCash,
		isnull( sum(CashPrizes) 
				+ sum(CheckPrizes) 
				+ sum(MerchandisePrizes) 
				+ sum(OtherPrizes), 0
			   ) as PrizesPaid,
		isnull(sum(CashPrizes), 0) as CashPrizes,
		isnull(sum(AccrualPayouts), 0) as AccrualPayouts ,
		isnull(sum(AccrualIncrease), 0) as AccrualIncrease,
		isnull(sum(BeginningBank), 0) as BeginningBank,
		isnull(sum(EndingBank), 0) as EndingBank,
		isnull(sum(BankFill), 0) as BankFill,
		isnull(sum(AccrualCashPayouts), 0) as AccrualCashPayouts,
		isnull(sum(RedeemFees), 0) as RedeemFees,
		isnull(sum(RedeemOther), 0) as RedeemOther
from	SessionSummary ss
		join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
		left join (	select	GamingDate,
							GamingSession,
							sum(StarAmount) as StarAmount  
					from	dbo.FindStarPoints(@OperatorID, @StartDate, @EndDate, @Session)
					group by GamingDate, 
							GamingSession
				   ) fsp 
							on ( fsp.GamingDate = sp.GamingDate
							     and fsp.GamingSession = sp.GamingSession
							    )
		left join @BonusBall bb on (sp.GamingDate = bb.GamingDate and sp.GamingSession = bb.GamingSession)
		left join ( select  GamingDate,
							GamingSession,
							isnull(sum(RedeemFees), 0) as RedeemFees,
							isnull(sum(RedeemOther), 0) as RedeemOther
					from	dbo.FindPointRedemptions (@OperatorID, @StartDate, @EndDate, @Session)
					where	Voided = 0
					group by GamingDate, GamingSession
				  ) fpr on fpr.GamingDate = sp.GamingDate and fpr.GamingSession = sp.GamingSession		
where   sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and sp.OperatorID = @OperatorID
group by sp.GamingDate
order by GamingDate;
  
Set nocount off;	








GO

