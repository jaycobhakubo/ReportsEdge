USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStationsProgressiveJackpotCalendar]    Script Date: 04/10/2019 14:38:11 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptStationsProgressiveJackpotCalendar]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptStationsProgressiveJackpotCalendar]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStationsProgressiveJackpotCalendar]    Script Date: 04/10/2019 14:38:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-----------------------------------------------------------
--	Created By: FortuNet
--  Description: Returns the Progressive Accounts Starting Balance, transfers, payouts,
--				sales, total accrued amount and ending balance for a gaming date. 
--	20160607 tmp: US4420 - Add Progressive Jackpot Report.
--  20161212 tmp: DE13360 - Returns all accounts when inactive status is selected.
--	20161216 tmp: Add the head count for the session to the cash ball for the session.
--  20170203 tmp: Changed the head count from where accountID <> 10 to accountID > 10.
--                Head count was being returned for an account that was included in an 
--                accrual that was not set to use All programs.
--	20190410 tmp: Removed backup accounts from being included in the progressive increase. 
-----------------------------------------------------------

CREATE PROCEDURE [dbo].[spRptStationsProgressiveJackpotCalendar] 
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
		
--- Get the head count for the program played
Declare @headcount table
(
	GamingSession	int,
	ProgramName		nvarchar(128),
	AccountID		int,
	AccountName		nvarchar(128),
	HeadCount		int
); 
with cteAccountPrograms (ProgramName, AccountID, AccountName, GamingSession)
	 as 
	 (	
		select	p.ProgramName,
				aaa.accountID,
				aa.accountName,
				case when p.ProgramName = '9am' then 1
					when p.ProgramName = '11am' then 2
					when p.ProgramName = '1pm' then 3
					when p.ProgramName = '3pm' then 4
					when p.ProgramName = '5pm' then 5
					when p.ProgramName = '7pm' then 6
					when p.ProgramName = '9pm' then 7
					when p.ProgramName = '11pm' then 8
				end as GamingSession
		from	AccrualPrograms ap
				join Program p on ap.ProgramID = p.ProgramID
				join Acc2AccrualAccounts aaa on ap.AccrualID = aaa.accrualID
				join Acc2Account aa on aaa.accountID = aa.accountID
		where	aaa.sequenceInAccrual = 1
				and aaa.accountID > 10
				and aa.operatorID = @OperatorID
	)
	insert into @headcount
	(
		GamingSession,
		ProgramName,
		AccountID,
		AccountName,
		HeadCount
	)
	select	sp.GamingSession,
			sp.ProgramName,
			ap.AccountID,
			ap.AccountName,
			count(Distinct rr.TransactionNumber) as HeadCount
	from	SessionPlayed sp
			join RegisterDetail rd on sp.SessionPlayedID = rd.SessionPlayedID
			join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
			join cteAccountPrograms ap on sp.ProgramName = ap.ProgramName and sp.GamingSession = ap.GamingSession
	where	sp.OperatorID = @OperatorID
			and sp.GamingDate = @StartDate
			and IsOverridden = 0
			and rr.SaleSuccess = 1
			and rr.TransactionTypeID = 1
			and rd.VoidedRegisterReceiptID is null
			and rr.OriginalReceiptID is null
	group by sp.GamingSession,
			sp.ProgramName,
			ap.AccountID,
			ap.AccountName;		

-- Return our results
select	r.accountID
		, r.accountName 
		, hc.HeadCount
		, sum(isnull(accountTransfers, 0)) as AccountTransfers
		, sum(isnull(totalPaid, 0)) as TotalPaid
		, sum(isnull(calculatedSales, 0)) as CalculatedSales
		, case when r.accountName like '%BU' then 0 --Ends with BU
				else sum(isnull(accruedTotal, 0))
				end as AccruedTotal
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
from	@Results r
		left join @headcount hc on r.accountID = hc.AccountID
group by r.accountID, r.accountName, hc.HeadCount
order by r.accountName;
	
END;








GO

