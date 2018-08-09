USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptProgressiveJackpotCalendar]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptProgressiveJackpotCalendar]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-----------------------------------------------------------
--	Created By: FortuNet
--  Description: Returns the Progressive Accounts Starting Balance, transfers, payouts,
--				sales, total accrued amount and ending balance for a gaming date. 
--	20160607 tmp: US4420 - Add Progressive Jackpot Report.
--	20160824 tmp: US4844 - Added support for voiding progressive increaes.
--	20161212 tmp: DE13360 - Returns all accounts when inactive status is selected.
-----------------------------------------------------------


CREATE PROCEDURE [dbo].[spRptProgressiveJackpotCalendar] 
    @OperatorID as int,
	@StartDate as datetime,
	@AccrualStatus AS int
AS
BEGIN

	SET NOCOUNT ON;
   
-- declare	@OperatorID int,
--		@IsActive bit,
--		@GamingDate datetime
		
--set	@OperatorID = 1
--set	@IsActive = 1
--set	@GamingDate = '06/07/2016';
DECLARE @dateHourOffset INT = 5;
DECLARE @rptDate DATE = CAST(@StartDate AS DATE);
DECLARE @rptDateStart smalldatetime = DATEADD(HOUR, @dateHourOffset, CAST(@rptDate AS smalldatetime));
DECLARE @rptDateEnd smalldatetime = DATEADD(DAY, 1, @rptDateStart);

declare @Results table
(
	accountID				int
	, accountName			nvarchar(32)
	, transactionTypeID		int
	, accountTransID		int
	, accountTransfers		money
	, totalPaid				money
	, calculatedSales		money
	, accruedTotal			money
	, previousBalance		money
	, actualBalanceChange	money
	, postBalance			money
	, ballCount				int
)

-- insert transfers and adjustments
insert into @Results
(
	accountID
	, accountName
	, transactionTypeID
	, accountTransID
	, accountTransfers
	, previousBalance
	, actualBalanceChange
	, postBalance
)
select	atd.accountID
		, a.accountName
		, t.TransactionTypeID
		, atd.acc2TransAccountDetailID
		, atd.actualBalanceChange
		, atd.previousBalance
		, atd.actualBalanceChange
		, atd.postBalance
from	Acc2Transactions at join Acc2TransactionAccountDetails atd on at.acc2TransactionID = atd.acc2TransactionID
		join Acc2Account a on atd.accountID = a.accountID
		join TransactionType t on at.transactionTypeID = t.TransactionTypeID
where	((at.SessionPlayedId IS NOT NULL AND at.GamingDate = @rptDate) 
		  OR (at.SessionPlayedId IS NULL AND at.DTStamp >= @rptDateStart AND at.DTStamp < @rptDateEnd))
		and a.operatorID = @OperatorID
		and ((@AccrualStatus = -1) or (@AccrualStatus = a.IsActive))
--		and a.isActive = @IsActive
		and at.transactionTypeID in (6, 8, 38, 41) -- Reseed (6, 38), Transfers (8), Adjustments (41)
		and at.voidedByTransID is null
order by a.accountID, atd.acc2TransAccountDetailID;

-- insert increases
insert into @Results
(
	accountID
	, accountName
	, transactionTypeID
	, accountTransID
	, accruedTotal
	, previousBalance
	, actualBalanceChange
	, postBalance
)
select	atd.accountID
		, a.accountName
		, t.TransactionTypeID
		, atd.acc2TransAccountDetailID
		, atd.actualBalanceChange
		, atd.previousBalance
		, atd.actualBalanceChange
		, atd.postBalance
from	Acc2Transactions at join Acc2TransactionAccountDetails atd on at.acc2TransactionID = atd.acc2TransactionID
		join Acc2Account a on atd.accountID = a.accountID
		join TransactionType t on at.transactionTypeID = t.TransactionTypeID
where ((at.SessionPlayedId IS NOT NULL AND at.GamingDate = @rptDate) 
		  OR (at.SessionPlayedId IS NULL AND at.DTStamp >= @rptDateStart AND at.DTStamp < @rptDateEnd))
		and a.operatorID = @OperatorID
		and ((@AccrualStatus = -1) or (@AccrualStatus = a.IsActive))
		and at.transactionTypeID in (5, 37) -- Automatic progressive increases (5), manual progressive increases (37)
		and at.voidedByTransID is null
order by a.accountID, atd.acc2TransAccountDetailID;

-- insert payouts
insert into @Results
(
	accountID
	, accountName
	, transactionTypeID
	, accountTransID
	, totalPaid
	, previousBalance
	, actualBalanceChange
	, postBalance
)
select	atd.accountID
		, a.accountName
		, t.TransactionTypeID
		, atd.acc2TransAccountDetailID
		, atd.actualBalanceChange
		, atd.previousBalance
		, atd.actualBalanceChange
		, atd.postBalance
from	Acc2Transactions at join Acc2TransactionAccountDetails atd on at.acc2TransactionID = atd.acc2TransactionID
		join Acc2Account a on atd.accountID = a.accountID
		left join TransactionType t on at.transactionTypeID = t.TransactionTypeID
where	((at.SessionPlayedId IS NOT NULL AND at.GamingDate = @rptDate) 
		  OR (at.SessionPlayedId IS NULL AND at.DTStamp >= @rptDateStart AND at.DTStamp < @rptDateEnd))
		and a.operatorID = @OperatorID
		and ((@AccrualStatus = -1) or (@AccrualStatus = a.IsActive))
		and at.transactionTypeID = 7 -- Progressive Payouts
		and at.voidedByTransID is null
order by a.accountID, atd.acc2TransAccountDetailID;

-- insert calculated sales
insert into @Results
(
	accountID
	, accountName
	, transactionTypeID
	, accountTransID
	, calculatedSales
	, previousBalance
	, actualBalanceChange
	, postBalance
)
select	atd.accountID
		, a.accountName
		, t.TransactionTypeID
		, atd.acc2TransAccountDetailID
		, aad.sourceAmount
		, atd.previousBalance
		, atd.actualBalanceChange
		, atd.postBalance
from	Acc2Transactions at join Acc2TransactionAccountDetails atd on at.acc2TransactionID = atd.acc2TransactionID
		join Acc2Account a on atd.accountID = a.accountID
		join TransactionType t on at.transactionTypeID = t.TransactionTypeID
		join Acc2TransactionAccrualDetails aad on atd.acc2TransactionID = aad.acc2TransactionID
where	--at.GamingDate = cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
		((at.SessionPlayedId IS NOT NULL AND at.GamingDate = @rptDate) 
		  OR (at.SessionPlayedId IS NULL AND at.DTStamp >= @rptDateStart AND at.DTStamp < @rptDateEnd))
		and a.operatorID = @OperatorID
		and ((@AccrualStatus = -1) or (@AccrualStatus = a.IsActive))
		and at.transactionTypeID in (5, 37)
		and at.voidedByTransID is null
order by a.accountID, atd.acc2TransAccountDetailID;

-- insert all accounts without activity
insert into @Results
(
		accountID
		, accountName
		, previousBalance
		, postBalance
)
select	aa.accountID
		, aa.accountName
		--, aa.currentBalance
		--, aa.currentBalance
		, previousBalance = ( select top 1 isnull(atd.postBalance, 0)
							  from Acc2TransactionAccountDetails atd join Acc2Transactions at on atd.acc2TransactionID = at.acc2TransactionID
							  where atd.accountID = aa.accountID
									and ((at.SessionPlayedId IS NOT NULL AND at.GamingDate < @rptDate) 
											OR (at.SessionPlayedId IS NULL AND at.DTStamp < @rptDateStart))
							  order by atd.acc2TransactionID desc
							)
		, postBalance =    (  select top 1 isnull(atd.postBalance, 0)
							  from Acc2TransactionAccountDetails atd join Acc2Transactions at on atd.acc2TransactionID = at.acc2TransactionID
							  where atd.accountID = aa.accountID
									and ((at.SessionPlayedId IS NOT NULL AND at.GamingDate < @rptDate) 
											OR (at.SessionPlayedId IS NULL AND at.DTStamp < @rptDateStart))
							  order by atd.acc2TransactionID desc
							)
from	Acc2Account	aa left join @Results r on r.accountID = aa.accountID
where	r.accountName is null
		and ((@AccrualStatus = -1) or (@AccrualStatus = aa.IsActive));	-- DE13360
		
-- Get Ball Count Limit
declare @stats TABLE 
(
	accountID int,
	transCount int,
	starting_balance money,
	total_change money,
	ending_balance money,
	payouts money,
	reseeds money,
	increases money,
	other money,
	has_payout_balance bit,
	payout_balance money,
	last_paid_gaming_date date,
	first_trans_gaming_date date,
	payable_ballcall_limit int
);
	
insert into @stats
exec spGetAcc2AccountGamingDateStats @OperatorID, @StartDate, 0, @AccrualStatus;
		
-- Return our results
select	r.accountID
		, r.accountName 
		, sum(isnull(accountTransfers, 0)) as AccountTransfers
		, sum(isnull(totalPaid, 0)) as TotalPaid
		, sum(isnull(calculatedSales, 0)) as CalculatedSales
		, sum(isnull(accruedTotal, 0)) as AccruedTotal
		-- , previousBalance = ( select	top 1 isnull(r2.previousBalance, 0)
		-- 					  from		@Results r2 
		-- 					  where		r2.accountID = r.accountID
		-- 					  order by	r2.accountTransID asc
		-- 					 )	
		, previousBalance = ISNULL(( select SUM(tacct.actualBalanceChange) AS startingBalance
							  from Acc2Transactions AS t
							  inner join Acc2TransactionAccountDetails AS tacct ON t.acc2TransactionID = tacct.acc2TransactionID
							  where tacct.accountID = r.accountID
								and ((t.SessionPlayedId IS NOT NULL AND t.GamingDate < @rptDate) 
									  OR (t.SessionPlayedId IS NULL AND t.DTStamp < @rptDateStart))
							 ), 0.00)	
		-- , postBalance =		( select	top 1 isnull(r2.postBalance, 0)
		-- 					  from		@Results r2 
		-- 					  where		r2.accountID = r.accountID
		-- 					  order by	r2.accountTransID desc
		-- 					 )			 			 
		, postBalance = ISNULL(( select SUM(tacct.actualBalanceChange) AS endingBalance
							  from Acc2Transactions AS t
							  inner join Acc2TransactionAccountDetails AS tacct ON t.acc2TransactionID = tacct.acc2TransactionID
							  where tacct.accountID = r.accountID
								and ((t.SessionPlayedId IS NOT NULL AND t.GamingDate <= @rptDate) 
									  OR (t.SessionPlayedId IS NULL AND t.DTStamp < @rptDateEnd))
							 ), 0.00)
		, s.payable_ballcall_limit			 					
from	@Results r
		left join @stats s on r.accountID = s.accountID
group by r.accountID, r.accountName, s.payable_ballcall_limit
order by r.accountName;
	
END;
GO

