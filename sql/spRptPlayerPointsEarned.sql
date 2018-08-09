USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerPointsEarned]    Script Date: 08/30/2012 10:48:59 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerPointsEarned]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerPointsEarned]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerPointsEarned]    Script Date: 08/30/2012 10:48:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[spRptPlayerPointsEarned]
(
-- =============================================
-- Author:		Barry Silver
-- Description:	Receipt style closing report
--
-- 06/15/2011 BJS: DE8563 replace old player report.
--                 reduce dependency on History db.
-- =============================================
	@OperatorID	AS	INT,
	@StartDate	AS	DATETIME,
	@EndDate	AS	DATETIME,
	@PlayerID   AS  INT
)	
as
	
--declare 
--@OperatorID		INT,
--@StartDate		DATETIME,
--@EndDate		DATETIME,
--@PlayerID     INT

--set @OperatorID = 1
--set @StartDate = '8/29/2012 00:00:00'
--set @EndDate = '8/29/2012 00:00:00'
--set @PlayerID = 0

	
begin
    set nocount on;
    
    declare @RESULTS table
    ( lastName      nvarchar(32)
    , firstName     nvarchar(32)
    , playerId      int
    , gamingDate    datetime
    , transDate     datetime
    , transNbr      int     
	, transSubNbr	int
	, transType     nvarchar(64)
    , transTypeId   int
    , amount        money
    , pointsEffect  money
    , prevBal       money
    , postBal       money
    );
    
    -- Transactions which generally increase player points.  
    -- (Returns are stored as neg amts so we include them here for proper arithmetrick!)
    -- Sales, Returns, Cashouts, Credit wagers, Credit Game Win (SRCC)
    with INCREASES 
    (lastName, firstName, playerId, gamingDate, transDate, transNbr
	 , transSubNbr
	 , transType, transTypeId
     , voidRRId, qty, price, discAmt, ptsEarned, ptsRedeemed, discPerDollar, prevBal)
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
    from Player p 
    join RegisterReceipt rr on p.PlayerID = rr.PlayerID
    join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
    left join TransactionType tt on rr.TransactiontypeID = tt.TransactiontypeID
    where
    (rr.GamingDate >= @StartDate and rr.GamingDate <= @EndDate)
    and rr.OperatorID = @OperatorID 
    and (@PlayerID = 0 or rr.PlayerID = @PlayerID)
    and rr.TransactiontypeID in (1, 3, 12, 13, 15)
    and rr.SaleSuccess = 1
    )
    insert @RESULTS
    ( lastName, firstName, playerId, gamingDate, transDate, transNbr
    , transSubNbr
    , transType, transTypeId
    , amount, pointsEffect, prevBal, postBal )
    select 
      lastName, firstName, playerId
    , gamingDate, transDate, transNbr
    , transSubNbr
    , transType, transTypeId
    , (qty * price) + (qty * discAmt) 
    , (qty * ptsEarned) - (qty * ptsRedeemed) + (qty * discAmt) * discPerDollar  
    , prevBal 
    , prevBal + (qty * ptsEarned) - (qty * ptsRedeemed) + (qty * discAmt) * discPerDollar 
    from INCREASES;
    

    
    -- DEBUG
    --select * from @Results;
    
    -- Voids decrease points
    with VOIDS 
    (lastName, firstName, playerId, gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , voidRRId, qty, price, discAmt, ptsEarned, ptsRedeemed, discPerDollar, prevBal)
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
    from Player p 
    join RegisterReceipt rr on p.PlayerID = rr.PlayerID
    join RegisterDetail rd on rr.RegisterReceiptID = rd.VoidedRegisterReceiptID
    left join TransactionType tt on rr.TransactiontypeID = tt.TransactiontypeID
    where
    (rr.GamingDate >= @StartDate and rr.GamingDate <= @EndDate)
    and rr.OperatorID = @OperatorID 
    and (@PlayerID = 0 or rr.PlayerID = @PlayerID)
    and rr.TransactiontypeID = 2
    )
    insert @RESULTS
    ( lastName, firstName, playerId, gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , amount, pointsEffect, prevBal, postBal )
    select 
      lastName, firstName, playerId
    , gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , -1.0 * ((qty * price) + (qty * discAmt)) 
    , -1.0 * ((qty * ptsEarned) - (qty * ptsRedeemed) + (qty * discAmt) * discPerDollar)  
    , prevBal 
    , prevBal + ( -1.0 * ((qty * ptsEarned) - (qty * ptsRedeemed) + (qty * discAmt) * discPerDollar))
    from VOIDS;



    -- Cashouts: decrease points
    with CASHOUTS 
    (lastName, firstName, playerId, gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , voidRRId, qty, price, discAmt, ptsEarned, ptsRedeemed, discPerDollar, prevBal)
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
    from Player p 
    join RegisterReceipt rr on p.PlayerID = rr.PlayerID
    join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
    left join TransactionType tt on rr.TransactiontypeID = tt.TransactiontypeID
    where
    (rr.GamingDate >= @StartDate and rr.GamingDate <= @EndDate)
    and rr.OperatorID = @OperatorID 
    and (@PlayerID = 0 or rr.PlayerID = @PlayerID)
    and rr.TransactiontypeID in (10, 16)
    )
    insert @RESULTS
    ( lastName, firstName, playerId, gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , amount, pointsEffect, prevBal, postBal )
    select 
      lastName, firstName, playerId
    , gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , -1.0 * ((qty * price) + (qty * discAmt)) 
    , -1.0 * ((qty * ptsEarned) - (qty * ptsRedeemed) + (qty * discAmt) * discPerDollar)  
    , prevBal 
    , prevBal + ( -1.0 * ((qty * ptsEarned) - (qty * ptsRedeemed) + (qty * discAmt) * discPerDollar))
    from CASHOUTS;
    


    -- Player Swipes
    -- Apparently, these exist only in the History db!
    with SWIPES (lastName, firstName, playerId, gamingDate
               , transDate, transNbr
			   , transSubNbr
			   , transType, transTypeId, prevBal, delta, postBal)
    as
    (        
    select 
      p.LastName, p.FirstName, p.PlayerID
    , gtGamingDate, gtTransDate, gtdGameTransID, isnull(gtdRegisterReceiptID, 0), 'Player Swipe Transaction', gtTransactionTypeID 
    , /*gtdPrevious*/00.00, gtdDelta, gtdPost
    from Player p
    join History.dbo.GameTrans gt on p.PlayerID = gt.gtPlayerID 
    join History.dbo.GameTransDetail gtd on gt.gtGameTransID = gtdGameTransID
    where 
    (gt.gtGamingDate >= @StartDate and gt.gtGamingDate <= @EndDate)
    and gt.gtOperatorID = @OperatorID 
    and (@PlayerID = 0 or gt.gtPlayerID = @PlayerID)
    and isnull(gt.gtRegisterReceiptID, 0) = 0 
    and gt.gtTransactionTypeID = 9 
    )
    insert @RESULTS
    ( lastName, firstName, playerId, gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , amount, pointsEffect, prevBal, postBal )
    select 
      lastName, firstName, playerId
    , gamingDate, transDate, transNbr
	, transSubNbr
	, transType, transTypeId
    , prevBal
    , delta
    , prevBal
    , (prevBal + delta)
    from SWIPES;



    -- Finally, return sorted results
    select * from @RESULTS
    order by lastName, firstName, playerId, transDate;        

end;

set nocount off;





GO


