USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBoydGroupedSessionSummaryRecapCashBased]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBoydGroupedSessionSummaryRecapCashBased]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
CREATE PROCEDURE [dbo].[spRptBoydGroupedSessionSummaryRecapCashBased]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime,
	@Session as int
	 
AS
-- ==============
--	2017.07.18 tmp: Version of the Session Summary Recap Cash Based
--					for Boyd.
-- ================
SET NOCOUNT ON;	

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

select	sp.GamingDate 
		, ProgramName 
		, sp.GamingSession
		, ManAttendance
		, PaperSales
		, ElectronicSales
		, BingoOtherSales - ISNULL(StarAmount,0) AS BingoOtherSales
		, PullTabSales
		, ConcessionSales
		, MerchandiseSales
		, Discounts
		, 0 as Coupon
		, CashPrizes
		, CheckPrizes
		, MerchandisePrizes
		, AccrualIncrease
		, PullTabPrizes
		, BeginningBank
		, AccrualPayouts
		, PrizeFeesWithheld
		, Coupons
		, Tax
		, ActualCash
		, DebitCredit
		, Checks
		, MoneyOrders
		, GiftCards
		, Chips
		, EndingBank
		, DeviceFees
		, sum(isnull(case when si.IsRegister = 1 then si.[value] else 0 end, 0)) as SessionCostsRegister
		, sum(isnull(case when si.IsRegister = 0 then si.[value] else 0 end, 0)) as SessionCostsNonRegister
		, OtherPrizes 
		, AccrualCashPayouts
		, ValidationSales - sum(isnull(b.BonusAmount, 0)) as ValidationSales	-- Subtract Bonus Ball since it is setup as a Bonus Validation
		, BankFill
		, StarAmount * -1 as StarAmount
		, sum(isnull(b.BonusAmount, 0)) as BonusAmount
		, RedeemFees
		, RedeemOther
from	SessionSummary SS
		join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
		left join SessionSummarySessionCosts SC on SS.SessionSummaryID = SC.SessionSummaryID
		left join SessionCostItem SI on SC.SessionCostItemID = SI.Id
--		left join (select GamingSession cpnGamingSession ,Netsales as Coupon from dbo.FindCouponSales(@OperatorID, @StartDate, @EndDate, @Session)) cpn on cpn.cpnGamingSession =  sp.GamingSession
		left join ( select	GamingDate,
							GamingSession,
							StarAmount 
					from	dbo.FindStarPoints(@OperatorID, @StartDate, @EndDate, @Session)
				   ) fsp
							on ( fsp.GamingDate = sp.GamingDate
								 and fsp.GamingSession = sp.GamingSession )
		left join @BonusBall b on ( sp.GamingDate = b.GamingDate
									and sp.GamingSession = b.GamingSession)	
		left join ( select  GamingDate,
							GamingSession,
							isnull(sum(RedeemFees), 0) as RedeemFees,
							isnull(sum(RedeemOther), 0) as RedeemOther
					from	dbo.FindPointRedemptions (@OperatorID, @StartDate, @EndDate, @Session)
					where	Voided = 0
					group by GamingDate, GamingSession
				  ) fpr on fpr.GamingDate = sp.GamingDate and fpr.GamingSession = sp.GamingSession
where   
        sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and SP.OperatorID = @OperatorID
        and (@Session = 0 or sp.GamingSession = @Session)
group by sp.GamingDate, ProgramName, sp.GamingSession, ManAttendance, PaperSales, ElectronicSales, 
BingoOtherSales,PullTabSales,ConcessionSales,MerchandiseSales,
Discounts,CashPrizes,CheckPrizes,MerchandisePrizes,AccrualIncrease,
PullTabPrizes,BeginningBank,AccrualPayouts,PrizeFeesWithheld,Coupons,
Tax,ActualCash,DebitCredit,Checks,MoneyOrders,GiftCards,Chips,EndingBank,DeviceFees
,OtherPrizes , AccrualCashPayouts, /*Coupon,*/ ValidationSales, BankFill, StarAmount
, RedeemFees , RedeemOther
order by GamingDate, GamingSession
  
Set nocount off;	








GO

