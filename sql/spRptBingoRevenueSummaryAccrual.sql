USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBingoRevenueSummaryAccrual]    Script Date: 01/06/2012 08:42:31 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBingoRevenueSummaryAccrual]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBingoRevenueSummaryAccrual]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBingoRevenueSummaryAccrual]    Script Date: 01/06/2012 08:42:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Barry J. Silver
-- Description:	ACCRUAL BASED
--              Provide periodic summary of sales and payout info
--              This report is offered in 2 styles: Cash Based and Accrual Based.
--              Cash Based gross revenue=sales-prizes-payouts
--              Accrual based gross rev=sales-prizes-accrual increases
--
-- BJS - 05/31/2011  US1851 new report
-- bjs 06/16/2011:  DE8677 Allow sessionid param
-- bjs 06/21/2011:  missing bingo sales
-- LJL 06/23/2011:  Removed voided payouts from result set
-- =============================================
CREATE PROCEDURE  [dbo].[spRptBingoRevenueSummaryAccrual] 
(
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session    int
)
as
begin
    set nocount on;

    -- Temp table needed since we must track payouts AND accrual increases/payouts
    declare @Results table
    (
		PayoutTransID	INT,
        gDate       datetime,
        sessionNo   int,
        attendance  int,
        salesAmt    money,
        cashAmt     money,
        checkAmt    money,
        creditAmt   money,
        merchAmt    money,
        otherAmt    money,
        accrualInc  money
    );
    
    --
    -- Insert a blank row for each session we want on the
    -- output report (make it show no matter what on the
    -- report)
    --
    INSERT INTO @Results
    (
		 gDate
		,sessionNo
		,attendance
		,salesAmt
		,cashAmt
		,checkAmt
		,creditAmt
		,merchAmt
		,otherAmt
		,accrualInc
    )
    SELECT
		 sp.GamingDate
		,sp.GamingSession
		,0
		,0
		,0
		,0
		,0
		,0
		,0
		,0
    FROM SessionPlayed sp
	WHERE	(@OperatorID IS NULL OR @OperatorID = 0 OR @OperatorID = sp.OperatorID) AND
			(sp.GamingDate >= @StartDate) AND
			(sp.GamingDate <= @EndDate) AND
			(sp.GamingSession = @Session OR @Session IS NULL OR @Session = 0) AND
			sp.IsOverridden = 0    
    
	--
	-- Insert all payout transactions with the criteria
	-- requested
	--
	INSERT INTO @Results
	(
		 PayoutTransID
		,gDate
		,sessionNo
		,attendance
		,salesAmt
		,cashAmt
		,checkAmt
		,creditAmt
		,merchAmt
		,otherAmt
		,accrualInc
	)
	SELECT
		 p.PayoutTransID
		,p.GamingDate
		,0
		,0
		,0
		,0
		,0
		,0
		,0
		,0
		,0
	FROM PayoutTrans p
	WHERE	(@OperatorID IS NULL OR @OperatorID = 0 OR @OperatorID = p.OperatorID) AND
			(p.GamingDate >= @StartDate) AND
			(p.GamingDate <= @EndDate) AND
			 p.TransTypeID = 36 AND -- Only Payouts    
			 p.VoidTransID IS NULL -- Not Voided
    
	--
	-- Update records for Bingo Custom Session Payouts
	--
	UPDATE @Results
	SET	 sessionNo = sp.GamingSession
	FROM @Results r
		JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)
		
	--
	-- Update records for Bingo Game Session Payouts
	--
	UPDATE @Results
	SET	 sessionNo = sp.GamingSession
	FROM @Results r
		JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)		
	
	--
	-- Update records for Bingo Custom Game Payouts
	--
	UPDATE @Results
	SET	 sessionNo = sp.GamingSession
	FROM @Results r
		JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
		
	--
	-- Update records for Bingo Game Payouts
	--
	UPDATE @Results
	SET	 sessionNo = sp.GamingSession
	FROM @Results r
		JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
		
	--
	-- Update records for Bingo Good Neighbor Game Payouts
	--
	UPDATE @Results
	SET	 sessionNo = sp.GamingSession
	FROM @Results r
		JOIN PayoutTransBingoGoodNeighbor ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)		
		
	--
	-- Update records for Bingo Royalty Game Payouts
	--
	UPDATE @Results
	SET	 sessionNo = sp.GamingSession
	FROM @Results r
		JOIN PayoutTransBingoRoyalty ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)		        
    
	--
	-- Add in "Cash" information to payouts
	--
	UPDATE @Results
	SET	 cashAmt = (SELECT SUM(ISNULL(DefaultAmount, 0)) FROM PayoutTransDetailCash WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailCash ptd ON (ptd.PayoutTransID = r.PayoutTransID)	
		
	--
	-- Add in "Check" information to payouts
	--
	UPDATE @Results
	SET	 checkAmt = (SELECT SUM(ISNULL(DefaultAmount, 0)) FROM PayoutTransDetailCheck WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailCheck ptd ON (ptd.PayoutTransID = r.PayoutTransID)		
		
	--
	-- Add in "Credit" information to payouts
	--
	UPDATE @Results
	SET	 creditAmt = (SELECT SUM(ISNULL(Refundable, 0)) + SUM(ISNULL(NonRefundable, 0)) FROM PayoutTransDetailCredit WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailCredit ptd ON (ptd.PayoutTransID = r.PayoutTransID)		
		
	--
	-- Add in "Merchandise" information to payouts
	--
	UPDATE @Results
	SET	 merchAmt = (SELECT SUM(ISNULL(PayoutValue, 0)) FROM PayoutTransDetailMerchandise WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailMerchandise ptd ON (ptd.PayoutTransID = r.PayoutTransID)				

	--
	-- Add in "Other" information to payouts
	--
	UPDATE @Results
	SET	 otherAmt = (SELECT SUM(ISNULL(PayoutValue, 0)) FROM PayoutTransDetailOther WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailOther ptd ON (ptd.PayoutTransID = r.PayoutTransID)	


    -- 
    -- Verified winners, show sales $$$
    --
    insert into @Results 
    ( 
      gDate, sessionNo, attendance, salesAmt, cashAmt, checkAmt, creditAmt, merchAmt, otherAmt
      , accrualInc
    )    
    select 
      sp.GamingDate, sp.GamingSession, 0
      , (rdi.Price * rdi.Qty * rd.Quantity) [SALES AMOUNT]
      , 0,0,0,0,0,0
    from ProgramGameWinnersDetail pgwd
		join SessionGamesPlayed sgp on pgwd.pgwdSessionGamesPlayedID = sgp.SessionGamesPlayedID
		join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
		left join BingoCardHeader bch on (pgwdSessionGamesPlayedID = bch.bchSessionGamesPlayedID and pgwdMasterCardNo = bch.bchMasterCardNo)
		join RegisterDetailItems rdi on bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID
		join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
    where (@OperatorID = 0 or sp.OperatorID = @OperatorID)
		and (@Session = 0 or sp.GamingSession = @Session)
		and (sp.GamingDate >= @StartDate and sp.GamingDate <= @EndDate);

    --
    -- Accruals increases and increase voids
    --
    insert into @Results 
    ( 
      gDate, sessionNo, attendance, salesAmt, cashAmt, checkAmt, creditAmt, merchAmt, otherAmt
      , accrualInc
    )    
	select
	  at.GamingDate, sp.GamingSession
	  , 0, 0, 0, 0, 0, 0, 0				
	  , sum(atd.Value)
	from AccrualTransactionDetails atd 
	join AccrualTransactions at ON atd.AccrualTransactionID = at.AccrualTransactionID 
    join SessionPlayed sp on at.SessionPlayedId = sp.SessionPlayedId
    where
    (at.GamingDate BETWEEN @StartDate AND @EndDate)
    and (@OperatorID = 0 or sp.OperatorID = @OperatorID)
    and (@Session = 0 OR sp.GamingSession = @Session)
    group by at.GamingDate, sp.GamingSession;
    
    -- 
    -- Attendance from Session Summary (manually entered)
    --
    insert into @Results 
    ( 
      gDate, sessionNo, attendance, salesAmt, cashAmt, checkAmt, creditAmt, merchAmt, otherAmt
      , accrualInc
    )    
    select 
      sp.GamingDate, sp.GamingSession, ss.ManAttendance
      , 0, 0, 0, 0, 0, 0, 0     
    from SessionSummary ss
    left join SessionPlayed sp on ss.SessionPlayedID = sp.SessionPlayedID
    where
        (@OperatorID = 0 or sp.OperatorID = @OperatorID)
    and (@Session = 0 or sp.GamingSession = @Session)
    and (sp.GamingDate >= @StartDate and sp.GamingDate <= @EndDate);

    declare @RESULTSET table
    (
       Yr int
     , Qtr nvarchar(4)
     , MonthInt int
     , MonthName nvarchar(32)
     , gDate datetime
     , sessionNo int
     , Attendance int
     , BingoSales money
     , CashAmt money
     , CheckAmt money
     , CreditAmt money
     , MerchAmt money
     , OtherAmt money
     , AccrualInc money
     , GrossRevenueAccrualBased money
     , PlayerSpend money
    );

    -- Add datefields for the report, and return our resultset!
    with RESULTS( 
     Yr, Qtr, MonthInt, MonthName
     , gDate, sessionNo, Attendance
     , BingoSales, CashAmt, CheckAmt, CreditAmt, MerchAmt, OtherAmt
     , AccrualInc
     ) as
    (
    select 
      datepart(year, r.gDate), 'Q' + convert(nvarchar(3), datepart(quarter, r.gDate)), month(r.gDate)
    , datename(month, r.gDate)
    , r.gDate, r.sessionNo, r.attendance
    , r.salesAmt, r.cashAmt, r.checkAmt, r.creditAmt, r.merchAmt, r.otherAmt
    , r.accrualInc
    from @Results r
    )
    insert into @RESULTSET
    (
       Yr, Qtr, MonthInt, MonthName
     , gDate, sessionNo, attendance
     , BingoSales, CashAmt, CheckAmt, CreditAmt, MerchAmt, OtherAmt
     , AccrualInc
    )
    select 
      Yr, Qtr, MonthInt, MonthName
    , gDate, sessionNo
    , sum(attendance)   [Attendance]
    , sum(BingoSales)   [Bingo Sales]
    , sum(cashAmt)      [CashAmt]
    , sum(checkAmt)     [CheckAmt]
    , sum(creditAmt)    [CreditAmt]
    , sum(merchAmt)     [MerchAmt]
    , sum(otherAmt)     [OtherAmt]
    , sum(accrualInc)   [Accrual Increases]
    from RESULTS
    group by Yr, Qtr, MonthInt, MonthName, gDate, sessionNo;
    
    -- DEBUG
    --select * from @RESULTSET;
    --return;
    
    
    -- Now, update each session total sales using the new udf function
    declare @gDate datetime;
    declare @totSales money;
    declare @sessionNbr int;

    declare SALESCURSOR cursor local fast_forward for
    select gDate, sessionNo from @Results;

    open SALESCURSOR;
    fetch next from SALESCURSOR into @gdate, @sessionNbr;
    while(@@FETCH_STATUS = 0)
    begin
        
        set @totSales = 0;
        
        -- New udf encapsulates biz logic found in sales reports
        select @totSales = [Daily].[dbo].[FindSessionSalesTotal] (@OperatorID, @gDate, @sessionNbr);
        
        -- DEBUG
        --print @totSales;
        
        update @RESULTSET set 
          BingoSales = isnull(@totSales, 0)
        , GrossRevenueAccrualBased = isnull(@totSales, 0) - cashAmt - checkAmt - creditAmt - merchAmt - otherAmt - accrualInc  
        , PlayerSpend = 
            case when isnull(attendance, 0) = 0 then 0 
            else ( (isnull(@totSales, 0) - cashAmt - checkAmt - creditAmt - merchAmt - otherAmt - accrualInc) / attendance)
            end               
        where gDate = @gDate and sessionNo = @sessionNbr; 
        
        fetch next from SALESCURSOR into @gdate, @sessionNbr;
    end;
    
    -- cleanup
    close SALESCURSOR;
    deallocate SALESCURSOR;        
    

    -- Return the updated resultset containing valid sales figures
    select 
       Yr
     , Qtr 
     , MonthInt 
     , MonthName 
     , gDate
     , sessionNo 
     , Attendance 
     , BingoSales [Bingo Sales]
     , CashAmt 
     , CheckAmt
     , CreditAmt
     , MerchAmt
     , OtherAmt
     , AccrualInc [Accrual Increases]
     , GrossRevenueAccrualBased [Gross Revenue Accrual Based]
     , PlayerSpend [Player Spend]
    from @RESULTSET
    order by gDate, sessionNo;

end;
set nocount off;







GO


