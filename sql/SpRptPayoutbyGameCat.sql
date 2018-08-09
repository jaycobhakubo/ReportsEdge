USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[SpRptPayoutbyGameCat]    Script Date: 03/09/2012 13:56:33 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SpRptPayoutbyGameCat]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[SpRptPayoutbyGameCat]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[SpRptPayoutbyGameCat]    Script Date: 03/09/2012 13:56:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create proc [dbo].[SpRptPayoutbyGameCat]
(
-- =============================================
-- Author:		Barry J. Silver
-- Description:	Lists payouts made in a session
--
-- BJS - 05/25/2011  US1844 new report
-- DJR - 06/21/2011  DE8696 Non-bingo payouts not
--					 being returned.
-- =============================================
@OperatorID	AS INT,
@GamingDate	AS DATETIME,
@Session	AS INT)

AS
BEGIN




    SET NOCOUNT ON;
    
    -- Allow NULL (or zero as input) for requesting all
    SET @Session	= NULLIF(@Session, 0)
    SET @OperatorID = NULLIF(@OperatorID, 0)

    -- Temp table needed since we must track payouts AND accrual increases/payouts
    declare @Results table
    (
         PayoutTransID		INT
        ,GamingDate			SMALLDATETIME
        ,GamingSession		TINYINT
        ,DisplayGameNo		INT
        ,DisplayPartNo		NVARCHAR(50)
        ,GCName				NVARCHAR(64)
        ,StaffID			INT
        ,MasterCardNumber	INT
        ,CardLevelName		NVARCHAR(32)
        ,PayoutTypeName		NVARCHAR(32)
        ,CashAmount			MONEY
        ,CheckAmount		MONEY
        ,CreditAmount		MONEY
        ,MerchandiseAmount	MONEY
        ,OtherAmount		MONEY
        ,CheckNumber		NVARCHAR(32)
        ,PayoutTransNumber	INT
        ,VoidTransNumber	INT
        ,Payee				NVARCHAR(128)
        ,PlayerName			NVARCHAR(66)
        ,TransactionTypeID	INT
        ,TransactionType	NVARCHAR(64)
		,DTStamp			DATETIME
    );

	--
	-- Insert all payout transactions with the criteria
	-- requested
	--
	INSERT INTO @Results
	(
		 PayoutTransID
		,GamingDate
		,StaffID
		,PayoutTransNumber
		,VoidTransNumber
		,PlayerName
		,TransactionTypeID
		,TransactionType
		,DTStamp
	)
	SELECT
		 p.PayoutTransID
		,p.GamingDate
		,p.StaffID
		,p.PayoutTransNumber
		,vp.PayoutTransNumber
		,CASE 
			WHEN (p.PlayerID IS NULL) THEN NULL
			ELSE pl.LastName + ', ' + pl.FirstName
		 END
		,p.TransTypeID
		,tt.TransactionType
		,p.DTStamp
	FROM PayoutTrans p
		LEFT JOIN PayoutTrans vp ON (p.VoidTransID = vp.PayoutTransID)
		LEFT JOIN Player pl ON (p.PlayerID = pl.PlayerID)
		LEFT JOIN TransactionType tt ON (tt.TransactionTypeID = p.TransTypeID)
	WHERE	(@OperatorID IS NULL OR @OperatorID = p.OperatorID) AND
			(p.GamingDate = @GamingDate )
			and p.TransTypeID = 36 -- Only Payouts
	
	--,
	-- Update records for Bingo Custom Session Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Custom' ELSE 'Accrual' END
	FROM @Results r
		JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)
		JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)
	--
	-- Update records for Bingo Game Session Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,MasterCardNumber = ptg.MasterCardNumber
		,CardLevelName = ptg.CardLevelName
		,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Regular' ELSE 'Accrual' END
	FROM @Results r
		JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionPlayed sp ON (ptg.SessionPlayedID = sp.SessionPlayedID)
		JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)		
	
	--
	-- Update records for Bingo Custom Game Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,DisplayGameNo = sgp.DisplayGameNo
		,DisplayPartNo = sgp.DisplayPartNo
		,GCName = sgp.GCName
		,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Custom' ELSE 'Accrual' END
	FROM @Results r
		JOIN PayoutTransBingoCustom ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
		JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)
	--
	-- Update records for Bingo Game Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,DisplayGameNo = sgp.DisplayGameNo
		,DisplayPartNo = sgp.DisplayPartNo
		,GCName = sgp.GCName	
		,MasterCardNumber = ptg.MasterCardNumber
		,CardLevelName = ptg.CardLevelName
		,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Regular' ELSE 'Accrual' END
	FROM @Results r
		JOIN PayoutTransBingoGame ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)
		JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)
	--
	-- Update records for Bingo Good Neighbor Game Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,DisplayGameNo = sgp.DisplayGameNo
		,DisplayPartNo = sgp.DisplayPartNo
		,GCName = sgp.GCName	
		,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Good Neighbor' ELSE 'Accrual' END
	FROM @Results r
		JOIN PayoutTransBingoGoodNeighbor ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)		
		JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)
	--
	-- Update records for Bingo Royalty Game Payouts
	--
	UPDATE @Results
	SET	 GamingSession = sp.GamingSession
		,DisplayGameNo = sgp.DisplayGameNo
		,DisplayPartNo = sgp.DisplayPartNo
		,GCName = sgp.GCName	
		,PayoutTypeName = CASE WHEN pt.AccrualTransID IS NULL THEN 'Royalty' ELSE 'Accrual' END
	FROM @Results r
		JOIN PayoutTransBingoRoyalty ptg ON (r.PayoutTransID = ptg.PayoutTransID)
		JOIN SessionGamesPlayed sgp ON (sgp.SessionGamesPlayedID = ptg.SessionGamesPlayedID)
		JOIN SessionPlayed sp ON (sgp.SessionPlayedID = sp.SessionPlayedID)				
	    JOIN PayoutTrans pt ON (r.PayoutTransID = pt.PayoutTransID)
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
		,CheckNumber = ptd.CheckNumber
		,Payee = ptd.Payee
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
         ,PayoutTypeName = CASE WHEN IsPrimary = 1 THEN 'Inventory' ELSE r.PayoutTypeName END
	FROM @Results r
		JOIN PayoutTransDetailMerchandise ptd ON (ptd.PayoutTransID = r.PayoutTransID)				

	--
	-- Add in "Other" information to payouts
	--
	UPDATE @Results
	SET	 OtherAmount = (SELECT SUM(ISNULL(PayoutValue, 0)) FROM PayoutTransDetailOther WHERE PayoutTransID = r.PayoutTransID)
	FROM @Results r
		JOIN PayoutTransDetailOther ptd ON (ptd.PayoutTransID = r.PayoutTransID)				

    -- Return our resultset!
    SELECT          
		 PayoutTransID		
        ,GamingDate			
        ,GamingSession		
        ,DisplayGameNo		
        ,DisplayPartNo		
        ,GCName				
        ,StaffID			
        ,MasterCardNumber	
        ,CardLevelName		
        ,PayoutTypeName		
        ,ISNULL(CashAmount, 0) AS CashAmount
        ,ISNULL(CheckAmount, 0) AS CheckAmount
        ,ISNULL(CreditAmount, 0) AS CreditAmount
        ,ISNULL(MerchandiseAmount, 0) AS MerchandiseAmount
        ,ISNULL(OtherAmount, 0) AS OtherAmount
        ,CheckNumber		
        ,PayoutTransNumber	
        ,VoidTransNumber	
        ,Payee				
        ,PlayerName				
        ,TransactionTypeID	
        ,TransactionType	
		,DTStamp			
	FROM @Results
	WHERE (@Session IS NULL OR @Session = GamingSession)
	order by GamingDate, GamingSession, DisplayGameNo, DisplayPartNo, DTStamp;

SET NOCOUNT OFF;

end








GO


