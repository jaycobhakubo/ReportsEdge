USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPayoutDetailPrizes]    Script Date: 03/29/2012 15:52:05 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPayoutDetailPrizes]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPayoutDetailPrizes]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPayoutDetailPrizes]    Script Date: 03/29/2012 15:52:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptPayoutDetailPrizes] 
(
-- =============================================
-- Author:		Barry J. Silver
-- Description:	Subreport detailing prize summaries
--
-- BJS - 05/25/2011: US1844 new report
-- BDH - 06/29/2011: Changed accrual increases to appear by operator
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session	AS INT
)
as
begin
    set nocount on;
    
    SET @OperatorID = NULLIF(@OperatorID, 0)
    SET @Session = NULLIF(@Session, 0)

    -- Temp table needed since we must track payouts AND accrual increases/payouts
    declare @Results table
    (
		 PayoutTransID			INT
		,GamingSession			TINYINT
		,GamingDate				SMALLDATETIME
        ,SessionGamesPlayedID	INT
        ,SessionPlayedID		INT
        ,CashAmount				MONEY
        ,CheckAmount			MONEY
        ,CreditAmount			MONEY
        ,MerchandiseAmount		MONEY
        ,OtherAmount			MONEY
        ,accrualInc				MONEY
        ,accrualPay				MONEY
        ,PrizeFees				MONEY
    );
    
	--
	-- Insert all payout transactions with the criteria
	-- requested
	--
	INSERT INTO @Results
	(
		 PayoutTransID
		,GamingDate
		,PrizeFees
	)
	SELECT
		 p.PayoutTransID
		,p.GamingDate
		,p.PrizeFee
	FROM PayoutTrans p
	WHERE	(@OperatorID IS NULL OR @OperatorID = p.OperatorID) AND
			(p.GamingDate >= @StartDate) AND
			(p.GamingDate <= @EndDate) AND
			p.VoidTransID IS NULL AND
			p.TransTypeID = 36 -- Only Payouts
	
	--
	-- Update records for Bingo Custom Session Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,SessionPlayedID = sp.SessionPlayedID
	FROM @Results r
		JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)
		
	--
	-- Update records for Bingo Game Session Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,SessionPlayedID = sp.SessionPlayedID
	FROM @Results r
		JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)		
	
	--
	-- Update records for Bingo Custom Game Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,SessionPlayedID = sp.SessionPlayedID
		,SessionGamesPlayedID = sgp.SessionGamesPlayedID
	FROM @Results r
		JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
		
	--
	-- Update records for Bingo Game Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,SessionPlayedID = sp.SessionPlayedID
		,SessionGamesPlayedID = sgp.SessionGamesPlayedID
	FROM @Results r
		JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
		
	--
	-- Update records for Bingo Good Neighbor Game Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,SessionPlayedID = sp.SessionPlayedID
		,SessionGamesPlayedID = sgp.SessionGamesPlayedID
	FROM @Results r
		JOIN PayoutTransBingoGoodNeighbor ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)		
		
	--
	-- Update records for Bingo Royalty Game Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,SessionPlayedID = sp.SessionPlayedID
		,SessionGamesPlayedID = sgp.SessionGamesPlayedID
	FROM @Results r
		JOIN PayoutTransBingoRoyalty ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)				
	
	--
	-- Add in "Cash" information to payouts
	--
	UPDATE @Results
	SET	 CashAmount = (SELECT SUM(ISNULL(DefaultAmount, 0)) FROM PayoutTransDetailCash WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailCash ptd ON (ptd.PayoutTransID = r.PayoutTransID)	
		
	--
	-- Add in "Check" information to payouts
	--
	UPDATE @Results
	SET	 CheckAmount = (SELECT SUM(ISNULL(DefaultAmount, 0)) FROM PayoutTransDetailCheck WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailCheck ptd ON (ptd.PayoutTransID = r.PayoutTransID)		
		
	--
	-- Add in "Credit" information to payouts
	--
	UPDATE @Results
	SET	 CreditAmount = (SELECT SUM(ISNULL(Refundable, 0)) + SUM(ISNULL(NonRefundable, 0)) FROM PayoutTransDetailCredit WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailCredit ptd ON (ptd.PayoutTransID = r.PayoutTransID)		
		
	--
	-- Add in "Merchandise" information to payouts
	--
	UPDATE @Results
	SET	 MerchandiseAmount = (SELECT SUM(ISNULL(PayoutValue, 0)) FROM PayoutTransDetailMerchandise WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailMerchandise ptd ON (ptd.PayoutTransID = r.PayoutTransID)				

	--
	-- Add in "Other" information to payouts
	--
	UPDATE @Results
	SET	 OtherAmount = (SELECT SUM(ISNULL(PayoutValue, 0)) FROM PayoutTransDetailOther WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailOther ptd ON (ptd.PayoutTransID = r.PayoutTransID)	    
    
    --
    -- Accruals increases and increase voids
    --
    INSERT INTO @Results 
    ( 
      GamingDate, CashAmount, CheckAmount, CreditAmount, MerchandiseAmount, OtherAmount, accrualPay, PrizeFees, accrualInc
    )    
    SELECT
      at.GamingDate
      , 0, 0, 0, 0, 0, 0, 0
      , ISNULL(atd.OverrideValue, atd.Value)
    FROM AccrualTransactions at
		JOIN AccrualTransactionDetails atd ON (at.AccrualTransactionID = atd.AccrualTransactionID)
		JOIN Accrual a ON (at.AccrualID = a.aAccrualID)
    WHERE at.TransactionTypeID in (4, 5, 37)  -- auto and manual accrual increases and voids
		AND (a.aOperatorID = @OperatorID OR @OperatorID IS NULL) -- DE8696 - Select by operator;
		AND (at.GamingDate >= @StartDate and at.GamingDate <= @EndDate)

    -- 
    -- Accrual Payouts and payout voids
    --
    insert into @Results 
    ( 
      GamingDate, CashAmount, CheckAmount, CreditAmount, MerchandiseAmount, OtherAmount, PrizeFees, accrualInc, accrualPay
    )    
    select 
      at.GamingDate
      , 0, 0, 0, 0, 0, 0, 0
      , case when atd.OverrideValue is null then atd.Value else atd.OverrideValue end
    from AccrualTransactions at
    join AccrualTransactionDetails atd on at.AccrualTransactionID = atd.AccrualTransactionID
    join SessionPlayed sp on at.SessionPlayedID = sp.SessionPlayedID
     left join PayoutTrans pt on pt.AccrualTransID = at.AccrualTransactionID --Added:(DE10268) Karlo Camacho 3.29.12
    where 
        (@OperatorID IS NULL or sp.OperatorID = @OperatorID)
    and (at.GamingDate >= @StartDate and at.GamingDate <= @EndDate)
    and (@Session IS NULL or sp.GamingSession = @Session)    
    and at.TransactionTypeID in (7, 36, 40 )  -- payouts and voids
    and pt.VoidTransID is not null -- Added:(DE10268) Karlo Camacho 3.29.12


    -- Return our resultset!
    select 
      sum(ISNULL(CashAmount, 0))			[Cash]
    , sum(ISNULL(CheckAmount, 0))			[Checks]
    , sum(ISNULL(CreditAmount, 0))			[Credit]
    , sum(ISNULL(MerchandiseAmount, 0))	[Merchandise]   
    , sum(ISNULL(OtherAmount, 0))			[Other]
    , sum(ISNULL(accrualPay, 0))			[AccrualPayouts]
    , sum(ISNULL(accrualInc, 0))			[AccrualIncreases]
    , sum(ISNULL(PrizeFees, 0))			[PrizeFees]    
    from @Results
    WHERE (@Session IS NULL OR GamingSession IS NULL OR @Session = GamingSession);

end;
set nocount off;




GO


