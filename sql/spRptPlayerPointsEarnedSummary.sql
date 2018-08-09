USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerPointsEarnedSummary]    Script Date: 09/18/2015 16:36:45 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerPointsEarnedSummary]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerPointsEarnedSummary]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerPointsEarnedSummary]    Script Date: 09/18/2015 16:36:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<FortuNet>
-- Create date: <12/13/2012>
-- Description:	<The accumulated player points by date and session>
-- 20150918 tmp: DE12571 Does not return players that do not have a mag. card.
-- =============================================

CREATE PROCEDURE [dbo].[spRptPlayerPointsEarnedSummary]
(
	@OperatorID Int,
	@StartDate	DateTime,
	@EndDate	DateTime
)
AS
BEGIN
	
	SET NOCOUNT ON;
		

--Set @OperatorID = 1
--Set @StartDate = 
--Set @EndDate = 

    
    declare @RESULTS table
    ( lastName      nvarchar(32)
    , firstName     nvarchar(32)
    , playerId      int
    , gamingDate    datetime
    , pointsEffect  money
	, magCard		nvarchar(64)
	, gamingSession	int
	);
    
    -- Transactions which generally increase player points.  
    -- (Returns are stored as neg amts so we include them here for proper arithmetrick!)
    -- Sales, Returns, Cashouts, Credit wagers, Credit Game Win (SRCC)
    with INCREASES 
    (lastName, firstName, playerId, gamingDate, 
		transDate, transNbr, transSubNbr, transType, transTypeId, voidRRId, qty, price, discAmt, ptsEarned, ptsRedeemed, discPerDollar, prevBal, magCard, gamingSession)
    as
    (        
    select
      p.LastName, p.FirstName, p.PlayerID
    , rr.GamingDate
    , rr.DTStamp
    , rr.TransactionNumber
	, rd.RegisterDetailID
    , tt.TransactionType
    , rr.TransactionTypeID
    , isnull(rd.VoidedRegisterReceiptID, 0)
    , isnull(rd.Quantity, 0)
    , isnull(rd.PackagePrice, 0)
    , isnull(rd.DiscountAmount, 0) 
    , isnull(rd.TotalPtsEarned, 0)
    , isnull(rd.TotalPtsRedeemed, 0)
    , isnull(rd.DiscountPtsPerDollar, 0)
    , isnull(rr.PreSalePoints, 0)
    , pmc.MagneticCardNo
    , sp.GamingSession
    from Player p 
    join RegisterReceipt rr on p.PlayerID = rr.PlayerID
    Left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID    -- DE12751 Changed to Left join
    join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
    left join TransactionType tt on rr.TransactiontypeID = tt.TransactiontypeID
    LEFT JOIN SessionPlayed sp on sp.SessionPlayedID = rd.SessionPlayedID  
    where
    rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime) 
    and rr.GamingDate <= cast(convert(varchar(12),@EndDate, 101) as smalldatetime) 
    and rr.OperatorID = @OperatorID 
    and rr.TransactiontypeID in (1, 3, 12, 13, 15)
    and rr.SaleSuccess = 1
    )
    insert @RESULTS
    ( lastName, firstName, playerId, gamingDate, 
    pointsEffect, magCard, gamingSession)
    select 
      lastName, 
      firstName, 
      playerId,
	  gamingDate, 
     (qty * ptsEarned) - (qty * ptsRedeemed) + (qty * discAmt) * discPerDollar,
     magCard,
     gamingSession  
    from INCREASES;
    
    -- DEBUG
    --select * From @RESULTS
	
    
    -- Voids decrease points
    with VOIDS 
    (lastName, firstName, playerId, gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , voidRRId, qty, price, discAmt, ptsEarned, ptsRedeemed, discPerDollar, prevBal, magCard, gamingSession)
    as
    (        
    select
      p.LastName, p.FirstName, p.PlayerID
    , rr.GamingDate
    , rr.DTStamp
    , rr.TransactionNumber
	, rd.RegisterDetailID
    , tt.TransactionType
    , rr.TransactionTypeID
    , isnull(rd.VoidedRegisterReceiptID, 0)
    , isnull(rd.Quantity, 0)
    , isnull(rd.PackagePrice, 0)
    , isnull(rd.DiscountAmount, 0) 
    , isnull(rd.TotalPtsEarned, 0)
    , isnull(rd.TotalPtsRedeemed, 0)
    , isnull(rd.DiscountPtsPerDollar, 0)
    , isnull(rr.PreSalePoints, 0)
    , pmc.MagneticCardNo
    , sp.GamingSession
    from Player p 
    join RegisterReceipt rr on p.PlayerID = rr.PlayerID
    Left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID -- DE12751 Changed to Left join
    join RegisterDetail rd on rr.RegisterReceiptID = rd.VoidedRegisterReceiptID
    left join TransactionType tt on rr.TransactiontypeID = tt.TransactiontypeID
     LEFT JOIN SessionPlayed sp on sp.SessionPlayedID = rd.SessionPlayedID  
    where
    rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime) 
    and rr.GamingDate <= cast(convert(varchar(12),@EndDate, 101) as smalldatetime) 
    and rr.OperatorID = @OperatorID
    and rr.TransactiontypeID = 2
    )
    insert @RESULTS
    ( lastName, firstName, playerId, gamingDate, 
     pointsEffect, magCard, gamingSession)
    select 
      lastName, firstName, playerId
    , gamingDate 
    , -1.0 * ((qty * ptsEarned) - (qty * ptsRedeemed) + (qty * discAmt) * discPerDollar)  
    , magCard
    , gamingSession
    from VOIDS;


    -- Cashouts: decrease points
    with CASHOUTS 
    (lastName, firstName, playerId, gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , voidRRId, qty, price, discAmt, ptsEarned, ptsRedeemed, discPerDollar, prevBal, magCard, gamingSession)
    as
    (        
    select
      p.LastName, p.FirstName, p.PlayerID
    , rr.GamingDate
    , rr.DTStamp
    , rr.TransactionNumber
	, rd.RegisterDetailID
    , tt.TransactionType
    , rr.TransactionTypeID
    , isnull(rd.VoidedRegisterReceiptID, 0)
    , isnull(rd.Quantity, 0)
    , isnull(rd.PackagePrice, 0)
    , isnull(rd.DiscountAmount, 0) 
    , isnull(rd.TotalPtsEarned, 0)
    , isnull(rd.TotalPtsRedeemed, 0)
    , isnull(rd.DiscountPtsPerDollar, 0)
    , isnull(rr.PreSalePoints, 0)
    , pmc.MagneticCardNo
    , sp.GamingSession
    from Player p 
    join RegisterReceipt rr on p.PlayerID = rr.PlayerID
    left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID  -- DE12751 Changed to Left join
    join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
    left join TransactionType tt on rr.TransactiontypeID = tt.TransactiontypeID
    LEFT JOIN SessionPlayed sp on sp.SessionPlayedID = rd.SessionPlayedID 
    where
    rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime) 
    and rr.GamingDate <= cast(convert(varchar(12),@EndDate, 101) as smalldatetime) 
    and rr.OperatorID = @OperatorID
    and rr.TransactiontypeID in (10, 16)
    )
    insert @RESULTS
    ( lastName, firstName, playerId, gamingDate
    , pointsEffect, magCard, gamingSession )
    select 
      lastName, firstName, playerId
    , gamingDate 
    , -1.0 * ((qty * ptsEarned) - (qty * ptsRedeemed) + (qty * discAmt) * discPerDollar)  
    , magCard
    , gamingSession
    from CASHOUTS;
    

    -- Player Swipes
    -- Apparently, these exist only in the History db!
    with SWIPES (lastName, firstName, playerId, gamingDate
               , transDate, transNbr
			   , transSubNbr
			   , transType, transTypeId, prevBal, delta, postBal, magCard, gamingSession)
    as
    (        
    select 
      p.LastName, p.FirstName, p.PlayerID
    , gtGamingDate, gtTransDate, gtdGameTransID, isnull(gtdRegisterReceiptID, 0), 'Player Swipe Transaction', gtTransactionTypeID 
    , gtdPrevious, gtdDelta, gtdPost
    , pmc.MagneticCardNo
    , IsNull(gt.gtGamingSession, 0)
    from Player p
    join History.dbo.GameTrans gt on p.PlayerID = gt.gtPlayerID
    left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID    -- DE12751 Changed to Left join
    join History.dbo.GameTransDetail gtd on gt.gtGameTransID = gtdGameTransID
    where 
    gt.gtGamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime) 
    and gt.gtGamingDate <= cast(convert(varchar(12),@EndDate, 101) as smalldatetime)  
    and gt.gtOperatorID = 1 
    and isnull(gt.gtRegisterReceiptID, 0) = 0 
    and gt.gtTransactionTypeID = 9 
    )
    insert @RESULTS
    ( lastName, firstName, playerId, gamingDate 
	, pointsEffect, magCard, gamingSession)
    select 
      lastName, firstName, playerId
    , gamingDate
    , delta
    , magCard
    , gamingSession
    from SWIPES;


    -- Finally, return sorted results
    select 
    gamingDate,
    gamingSession,
    firstName,
    lastName,
    magCard,
    SUM(pointsEffect) as pointChange
    from @RESULTS
    Where pointsEffect <> 0
    Group by lastName, firstName, magCard, gamingDate, gamingSession
    order by gamingDate, gamingSession, lastName, firstName 
End


















GO

