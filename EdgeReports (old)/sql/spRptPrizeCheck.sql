USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPrizeCheck]    Script Date: 06/23/2011 10:06:01 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPrizeCheck]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPrizeCheck]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPrizeCheck]    Script Date: 06/23/2011 10:06:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE  [dbo].[spRptPrizeCheck] 
(
-- =============================================
-- Author:		Barry J. Silver
-- Description:	Lists checks written to award prizes
--
-- BJS - 05/27/2011  US1845 new report
-- LJL - 06/23/2011 - Major rewrite.  Many issues.
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Results TABLE
    (
         PayoutTransID		INT
        ,DTStamp			DATETIME
        ,GamingSession		TINYINT
        ,DisplayGame		INT
        ,DisplayPart		NVARCHAR(50)
        ,PayoutType			NVARCHAR(32)
        ,CheckAmount		MONEY
        ,CheckNumber		NVARCHAR(32)
        ,PayoutTransNumber	INT
        ,Payee				NVARCHAR(128)
        ,PlayerName			NVARCHAR(66)
        ,ISOCode			NVARCHAR(3)
    );
    
    SELECT
         PayoutTransID		
        ,DTStamp			
        ,GamingSession		
        ,DisplayGame		
        ,DisplayPart		
        ,PayoutType			
        ,CheckAmount		
        ,CheckNumber		
        ,PayoutTransNumber	
        ,Payee				
        ,PlayerName			
        ,ISOCode			
    FROM @Results;
    
    SET NOCOUNT OFF;
END
    
    
    
    
    
    
    
    
    
    
    
--    --
--    -- Payouts from Bingo Games
--    --
--    insert into @Results 
--    ( 
--      payoutId, gDate, sessionNo, game, part, payType, checkAmt, checkNo, receiptNo, payee, player, checkCode
--    )    
--    select 
--      ptb.PayoutTransId
--    , p.DTStamp [GAMING DATE]
--    , sp.GamingSession [SESSION]    
--    , sgp.DisplayGameNo [GAME]
--    , sgp.DisplayPartNo [PART NUMBER]   
--    , pt.PayoutTypeName [PAYOUT TYPE]
--    , isnull(ptdck.CheckAmount, 0) [CHECK AMOUNT]
--    , ptdck.CheckNumber [CHECK NUMBER]
--    , p.PayoutTransNumber [RECEIPT NUMBER]
--    , ptdck.Payee [PAYEE]
--    , pl.LastName + ', ' + pl.FirstName [PLAYER]
--    , ptdck.ISOCode [CheckCurrency]
    
--    from PayoutTransBingoGame ptb    -- A bingo game caused the payout, use this as the driver!
--    join SessionGamesPlayed sgp on ptb.SessionGamesPlayedID = sgp.SessionGamesPlayedID
--    join PayoutTrans p on ptb.PayoutTransID = p.PayoutTransID
--    join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
--    join SessionPayoutSettings sps on sgp.SessionPayoutSettingID = sps.SessionPayoutSettingID
--    join PayoutTypes pt on sps.PayoutTypeID = pt.PayoutTypeID
--    left join PayoutTrans vp on p.VoidTransID = vp.PayoutTransID   
--    left join PayoutTransDetailCheck ptdck on p.PayoutTransID = ptdck.PayoutTransID
--    left join Player pl on p.PlayerID = pl.PlayerID    
--    where 
--        (@OperatorID = 0 or p.OperatorID = @OperatorID)
--    and (p.GamingDate >= @StartDate and p.GamingDate <= @EndDate)
--    and p.TransTypeID in (36, 39, 40 )  -- payouts and voids
--    and ptdck.CheckAmount > 0
--    order by p.GamingDate, sp.GamingSession, sgp.GCName, sgp.DisplayGameNo, sgp.DisplayPartNo;

--    --
--    -- Payouts from Bingo Custom
--    -- 
--    -- (Only BingoGame entities have cardnumber and level)
--    insert into @Results 
--    ( 
--      payoutId, gDate, sessionNo, game, part, payType, checkAmt, checkNo, receiptNo, payee, player, checkCode
--    )    
--    select 
--      ptbc.PayoutTransId
--    , p.DTStamp [GAMING DATE]
--    , sp.GamingSession [SESSION]    
--    , sgp.DisplayGameNo [GAME]
--    , sgp.DisplayPartNo [PART NUMBER]   
--    , pt.PayoutTypeName [PAYOUT TYPE]
--    , isnull(ptdck.CheckAmount, 0) [CHECK AMOUNT]
--    , ptdck.CheckNumber [CHECK NUMBER]
--    , p.PayoutTransNumber [RECEIPT NUMBER]
--    , ptdck.Payee [PAYEE]
--    , pl.LastName + ', ' + pl.FirstName [PLAYER]
--    , ptdck.ISOCode [CheckCurrency]
    
--    from PayoutTransBingoCustom ptbc    -- A bingo game caused the payout, use this as the driver!
--    join SessionGamesPlayed sgp on ptbc.SessionGamesPlayedID = sgp.SessionGamesPlayedID
--    join PayoutTrans p on ptbc.PayoutTransID = p.PayoutTransID
--    join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
--    join SessionPayoutSettings sps on sgp.SessionPayoutSettingID = sps.SessionPayoutSettingID
--    join PayoutTypes pt on sps.PayoutTypeID = pt.PayoutTypeID
--    left join PayoutTrans vp on p.VoidTransID = vp.PayoutTransID   
--    left join PayoutTransDetailCheck ptdck on p.PayoutTransID = ptdck.PayoutTransID
--    left join Player pl on p.PlayerID = pl.PlayerID    
--    where 
--        (@OperatorID = 0 or p.OperatorID = @OperatorID)
--    and (p.GamingDate >= @StartDate and p.GamingDate <= @EndDate)
--    and p.TransTypeID in (36, 39, 40 )  -- payouts and voids
--    and ptdck.CheckAmount > 0
--    order by p.GamingDate, sp.GamingSession, sgp.GCName, sgp.DisplayGameNo, sgp.DisplayPartNo;

--    --
--    -- Payouts from Bingo Good Neighbor
--    --
--    insert into @Results 
--    ( 
--      payoutId, gDate, sessionNo, game, part, payType, checkAmt, checkNo, receiptNo, payee, player, checkCode
--    )    
--    select 
--      ptbgn.PayoutTransId
--    , p.DTStamp [GAMING DATE]
--    , sp.GamingSession [SESSION]    
--    , sgp.DisplayGameNo [GAME]
--    , sgp.DisplayPartNo [PART NUMBER]   
--    , pt.PayoutTypeName [PAYOUT TYPE]
--    , isnull(ptdck.CheckAmount, 0) [CHECK AMOUNT]
--    , ptdck.CheckNumber [CHECK NUMBER]
--    , p.PayoutTransNumber [RECEIPT NUMBER]
--    , ptdck.Payee [PAYEE]
--    , pl.LastName + ', ' + pl.FirstName [PLAYER]
--    , ptdck.ISOCode [CheckCurrency]
    
--    from PayoutTransBingoGoodNeighbor ptbgn    -- A bingo game caused the payout, use this as the driver!
--    join SessionGamesPlayed sgp on ptbgn.SessionGamesPlayedID = sgp.SessionGamesPlayedID
--    join PayoutTrans p on ptbgn.PayoutTransID = p.PayoutTransID
--    join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
--    join SessionPayoutSettings sps on sgp.SessionPayoutSettingID = sps.SessionPayoutSettingID
--    join PayoutTypes pt on sps.PayoutTypeID = pt.PayoutTypeID
--    left join PayoutTrans vp on p.VoidTransID = vp.PayoutTransID   
--    left join PayoutTransDetailCheck ptdck on p.PayoutTransID = ptdck.PayoutTransID
--    left join Player pl on p.PlayerID = pl.PlayerID    
--    where 
--        (@OperatorID = 0 or p.OperatorID = @OperatorID)
--    and (p.GamingDate >= @StartDate and p.GamingDate <= @EndDate)
--    and p.TransTypeID in (36, 39, 40 )  -- payouts and voids
--    and ptdck.CheckAmount > 0
--    order by p.GamingDate, sp.GamingSession, sgp.GCName, sgp.DisplayGameNo, sgp.DisplayPartNo;

--    --
--    -- Payouts from Bingo Royalty
--    --
--    insert into @Results 
--    ( 
--      payoutId, gDate, sessionNo, game, part, payType, checkAmt, checkNo, receiptNo, payee, player, checkCode
--    )    
--    select 
--      ptbr.PayoutTransId
--    , p.DTStamp [GAMING DATE]
--    , sp.GamingSession [SESSION]    
--    , sgp.DisplayGameNo [GAME]
--    , sgp.DisplayPartNo [PART NUMBER]   
--    , pt.PayoutTypeName [PAYOUT TYPE]
--    , isnull(ptdck.CheckAmount, 0) [CHECK AMOUNT]
--    , ptdck.CheckNumber [CHECK NUMBER]
--    , p.PayoutTransNumber [RECEIPT NUMBER]
--    , ptdck.Payee [PAYEE]
--    , pl.LastName + ', ' + pl.FirstName [PLAYER]
--    , ptdck.ISOCode [CheckCurrency]
    
--    from PayoutTransBingoRoyalty ptbr    -- A bingo game caused the payout, use this as the driver!
--    join SessionGamesPlayed sgp on ptbr.SessionGamesPlayedID = sgp.SessionGamesPlayedID
--    join PayoutTrans p on ptbr.PayoutTransID = p.PayoutTransID
--    join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
--    join SessionPayoutSettings sps on sgp.SessionPayoutSettingID = sps.SessionPayoutSettingID
--    join PayoutTypes pt on sps.PayoutTypeID = pt.PayoutTypeID
--    left join PayoutTrans vp on p.VoidTransID = vp.PayoutTransID   
--    left join PayoutTransDetailCheck ptdck on p.PayoutTransID = ptdck.PayoutTransID
--    left join Player pl on p.PlayerID = pl.PlayerID    
--    where 
--        (@OperatorID = 0 or p.OperatorID = @OperatorID)
--    and (p.GamingDate >= @StartDate and p.GamingDate <= @EndDate)
--    and p.TransTypeID in (36, 39, 40 )  -- payouts and voids
--    and ptdck.CheckAmount > 0
--    order by p.GamingDate, sp.GamingSession, sgp.GCName, sgp.DisplayGameNo, sgp.DisplayPartNo;

--    -- Return our resultset!
--    select         payoutId    int,
--        gDate       datetime,
--        sessionNo   tinyint,
--        game        int,
--        part        nvarchar(50),
--        payType     nvarchar(32),
--        checkAmt    money,
--        checkNo     nvarchar(32),
--        receiptNo   int,
--        payee       nvarchar(128),
--        player      nvarchar(66),
--        checkCode   nvarchar(3) from @Results;

--end;
--set nocount off;



GO


