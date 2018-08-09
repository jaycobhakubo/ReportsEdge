USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[fnGetSpendAveragePerPlayer]    Script Date: 10/07/2013 15:43:30 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fnGetSpendAveragePerPlayer]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[fnGetSpendAveragePerPlayer]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[fnGetSpendAveragePerPlayer]    Script Date: 10/07/2013 15:43:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE function [dbo].[fnGetSpendAveragePerPlayer]
-- ============================================================================
-- Author:			Karlo Camacho
-- Date:			9/3/2013
-- Description:		Return a table PlayerID, SPEND, SPENDAVERAGE
-- Output:			table PlayerID, Spend, Average
-- Input            StartDate, EndDate, OperatorID, PlayerId
--
-- 2013.09.10 jkn - Added support for passing the player Id, commented out
--  unneeded joins
-- ============================================================================
(
    @OperatorID int,
    @StartDate datetime,
    @EndDate datetime,
    @PlayerId int = null
)
returns @PlayerSpendAverage table
(
    PlayerID int,
    TotalSpend Money,
    AverageSpend Money
)
as
begin

-- ============================================================================
		--CONS AND MERCHANDISE -> 1
-- ============================================================================
;with Spend_ConsNmdse (PlayerID, ConsNmdse, TransactionNo)
as
(
select /*rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,case rr.TransactionTypeID
when   1 then     SUM(rd.Quantity * rdi.Qty * rdi.Price)
when  3 then  SUM(rd.Quantity * rdi.Qty * rdi.Price)* -1
end*/
    rr.PlayerID
    , case rr.TransactionTypeID
        when 1 then SUM(rd.Quantity * rdi.Qty * rdi.Price)
        when 3 then SUM(rd.Quantity * rdi.Qty * rdi.Price)* -1 
      end
    , rr.TransactionNumber
from RegisterReceipt rr      
    join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)      
    join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)      
--JKN    left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)      
--JKN    join Staff s on rr.StaffID = s.StaffID      
where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
    and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)      
    and rr.SaleSuccess = 1      
    and rr.TransactionTypeID in (1,3)      
    and rr.OperatorID = @OperatorID      
    and (rdi.ProductTypeID = 7  or rdi.ProductTypeID = 6)          
    and rd.VoidedRegisterReceiptID is null      
    and (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)    
    --and rr.PlayerID is not null
    and ((@PlayerId is null and rr.PlayerId is not null) or rr.PlayerId = @PlayerId)
group by PlayerID, rr.TransactionTypeID, rr.TransactionNumber    /*rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID */
)--1868
-- ============================================================================
		--ELECTRONICS -> 2
-- ============================================================================
,  spend_Electronics (PlayerID, Electronics, TransactionNo)
as
(
select /*rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,*/
    rr.PlayerID
    , case rr.TransactionTypeID
        when 1 then sum(rd.Quantity * rdi.Qty * rdi.Price)
        when 3 then sum(rd.Quantity * rdi.Qty * rdi.Price)* -1
      end
    , TransactionNumber 
from RegisterReceipt rr      
    join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)      
    join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)      
--JKN    left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)           
--JKN    join Staff s on rr.StaffID = s.StaffID      
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
    and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
    and rr.SaleSuccess = 1      
    and rr.TransactionTypeID in (1,3)      
    and rr.OperatorID = @OperatorID      
    and rdi.ProductTypeID IN (1, 2, 3, 4, 5)            
    and rd.VoidedRegisterReceiptID IS NULL       
    and (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL)  
    --and rr.PlayerID is not null
    and ((@PlayerId is null and rr.PlayerId is not null) or rr.PlayerId = @PlayerId)
    --and PlayerID = @PlayerID            
group by rr.PlayerID, rr.TransactionTypeID, rr.TransactionNumber 
)--8755
-- ============================================================================
		--DISCOUNT -> 3
-- ============================================================================
,Spend_Discount (PlayerID, Discount, TransactionNo)
as
(
select /*rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,*/
    rr.playerID
    ,case rr.TransactionTypeID
        when 1 then sum(rd.Quantity * rd.DiscountAmount)
        when 3 then sum(rd.Quantity * rd.DiscountAmount) * -1
        end
    , rr.TransactionNumber    
from RegisterReceipt rr      
    left join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
    left join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
--JKN    left join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
--JKN    left join DiscountTypes dt on rd.DiscountTypeID = dt.DiscountTypeID
--JKN    join Staff s on rr.StaffID = s.StaffID      
where rd.DiscountTypeID is not null
    and rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
    and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
    and rr.SaleSuccess = 1      
    and rr.TransactionTypeID = 1      
    and rr.OperatorID = @OperatorID      
    and rd.VoidedRegisterReceiptID IS NULL 
    --and rr.PlayerID is not null
    and ((@PlayerId is null and rr.PlayerId is not null) or rr.PlayerId = @PlayerId)
group by rr.PlayerID, rr.TransactionTypeID, rr.TransactionNumber    /* rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID  */      
)--8755
-- ============================================================================
		--OTHER SALES -> 4
-- ============================================================================
, Spend_OtherSales (PlayerID, OtherSales, TransactionNo)
as
(
select /*rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,*/
      rr.playerID
    , case rr.TransactionTypeID
        when 1 then sum(rd.Quantity * rdi.Qty * rdi.Price)
        when 3 then sum(rd.Quantity * rdi.Qty * rdi.Price)* -1
      end
    , rr.TransactionNumber    
FROM RegisterReceipt rr      
    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)      
    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)      
--jkn    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)      
--jkn    join Staff s on rr.StaffID = s.StaffID      
where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
    And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)      
    and rr.SaleSuccess = 1      
    and rr.TransactionTypeID in (1,3)    
    and rr.OperatorID = @OperatorID      
    AND (rdi.ProductTypeID IN (8, 9, 15) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))      
    and rd.VoidedRegisterReceiptID IS NULL           
    --and rr.PlayerID is not null
    and ((@PlayerId is null and rr.PlayerId is not null) or rr.PlayerId = @PlayerId)
GROUP BY   rr.PlayerID, rr.TransactionTypeID, rr.TransactionNumber    /* rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID  */   
)--22826
-- ============================================================================
		-- PULLTAB -> 5
-- ============================================================================
,Spend_PullTab (PlayerID, PullTab, TransactionNo)
as
(select /*rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,*/
     rr.playerID
    ,case rr.TransactionTypeID
        when 1 then  SUM(rd.Quantity * rdi.Qty * rdi.Price)
        when 3 then  SUM(rd.Quantity * rdi.Qty * rdi.Price)* -1
     end
    ,rr.TransactionNumber 
FROM RegisterReceipt rr
    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--jkn    JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
Where 
    (rr.GamingDate between @StartDate and @EndDate)
    and rr.SaleSuccess = 1
    and rr.TransactionTypeID in (1,3)
    and rr.OperatorID = @OperatorID
    AND rdi.ProductTypeID IN (17)
    and rd.VoidedRegisterReceiptID IS NULL	
    AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
    and (rdi.SalesSourceID = 2)  
    --and rr.PlayerID is not null
    and ((@PlayerId is null and rr.PlayerId is not null) or rr.PlayerId = @PlayerId)
GROUP BY   rr.PlayerID, rr.TransactionTypeID, rr.TransactionNumber )
--0 
-- ============================================================================
		--TAX -> 6
-- ============================================================================
, Spend_Tax (PlayerID, Tax, TransactionNo)
as
(
select /*rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,*/
     rr.playerID
    ,SUM(rd.SalesTaxAmt * rd.Quantity)
    ,rr.TransactionNumber     
FROM RegisterReceipt rr      
    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)      
    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)      
--jkn    JOIN Staff s ON (s.StaffID = rr.StaffID)     
Where       
    (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
    And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))      
    and rr.SaleSuccess = 1      
    and rr.TransactionTypeID IN (1, 3)      
    and rd.VoidedRegisterReceiptID IS NULL       
    and (@OperatorID = 0 or rr.OperatorID = @OperatorID )
    --and rr.PlayerID is not null
    and ((@PlayerId is null and rr.PlayerId is not null) or rr.PlayerId = @PlayerId)
GROUP BY   rr.PlayerID, rr.TransactionTypeID, rr.TransactionNumber    /* rr.GamingDate, sp.GamingSession, rr.TransactionNumber, rr.TransactionTypeID  */     
) -- 40968
-- ============================================================================
		-- DEVICE FEE -> 7
-- ============================================================================
, Spend_DeviceFee (PlayerID, DeviceFee, TransactionNo)
as
(
select /*rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,*/
     rr.playerID
    ,isnull(rr.DeviceFee, 0)
    ,rr.TransactionNumber 
FROM RegisterReceipt rr      
    --JOIN Staff s ON (s.StaffID = rr.StaffID)      
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
    And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)      
    and rr.SaleSuccess = 1      
    and rr.TransactionTypeID = 1      
    and rr.OperatorID = @OperatorID      
    AND rr.DeviceFee IS NOT NULL      
    AND rr.DeviceFee <> 0       
    AND EXISTS (SELECT * FROM RegisterDetail WHERE RegisterReceiptID = rr.RegisterReceiptID AND VoidedRegisterReceiptID IS NULL)   
    --and rr.PlayerID is not null
    and ((@PlayerId is null and rr.PlayerId is not null) or rr.PlayerId = @PlayerId)
) --33151
-- ============================================================================
		-- REGISTERSALES -> 8
-- ============================================================================
,Spend_RegisterSales (PlayerID, RegisterSales, TransactionNo)
as
(
select /*rr.GamingDate, sp.GamingSession, rr.TransactionNumber
,*/
     rr.playerID
    ,case rr.TransactionTypeID
        when 1 then SUM(rd.Quantity * rdi.Qty * rdi.Price)
        when 3 then SUM(rd.Quantity * rdi.Qty * rdi.Price)* -1
     end
    ,TransactionNumber 
FROM RegisterReceipt rr
    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
--jkn    JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
Where 
    (rr.GamingDate between @StartDate and @EndDate)
    and rr.SaleSuccess = 1
    and rr.TransactionTypeID in (1,3)
    and rr.OperatorID = @OperatorID
    AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)
    and rd.VoidedRegisterReceiptID IS NULL	
    AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)    -- Paper
    and (rdi.SalesSourceID = 2 or (SalesSourceID = 1 and rdi.ProductTypeID = 16)) 
    --and rr.PlayerID is not null
    and ((@PlayerId is null and rr.PlayerId is not null) or rr.PlayerId = @PlayerId)
group by rr.PlayerID, rr.TransactionTypeID, rr.TransactionNumber  
) --34093
, TransNumber (TransactionNo)-- get all transaction involved
as
(
select transactionNo from Spend_ConsNmdse
union select TransactionNo from spend_Electronics 
union select TransactionNo from Spend_Discount 
union select TransactionNo from Spend_OtherSales 
union select TransactionNo from Spend_PullTab  
union select TransactionNo from Spend_Tax  
union select TransactionNo from Spend_DeviceFee  
union select TransactionNo from Spend_RegisterSales  
) --40968=
,TransPerPlayer (TransactionNumber ,PlayerID)-- get all player associated wi that transaction 
as
(
select TransactionNo, rr.PlayerID  from TransNumber t 
join RegisterReceipt rr on rr.TransactionNumber = t.TransactionNo  
)

,PlayerSpendTransaction (PlayerID, TransactionNo, Spend) -- get how much they spen per transaction
as
(
Select tpp.PlayerID,
    TransactionNumber,
    ISNULL (sc.ConsNmdse, 0)
  + ISNULL (se.Electronics, 0)
  + ISNULL (sd.Discount, 0)
  + isnull (so.OtherSales, 0)
  + isnull (sp.PullTab, 0)
  + ISNULL (st.Tax, 0)
  + ISNULL (sdf.DeviceFee, 0)
  + isnull (sr.RegisterSales,0)     
from TransPerPlayer tpp 
    left join Spend_ConsNmdse sc on sc.TransactionNo = tpp.TransactionNumber 
    left join spend_Electronics se on se.TransactionNo = tpp.TransactionNumber 
    left join Spend_Discount sd on sd.TransactionNo = tpp.TransactionNumber 
    left join Spend_OtherSales so on so.TransactionNo = tpp.TransactionNumber 
    left join Spend_PullTab sp on sp.TransactionNo = tpp.TransactionNumber 
    left join Spend_Tax st on st.TransactionNo = tpp.TransactionNumber 
    left join Spend_DeviceFee sdf on sdf.TransactionNo =  tpp.TransactionNumber 
    left join Spend_RegisterSales sr on sr.TransactionNo = tpp.TransactionNumber 
) 

insert into @PlayerSpendAverage (PlayerID, AverageSpend, TotalSpend)
select PlayerID
    ,(SUM(spend) / COUNT(TransactionNo)) AverageSpend
    , SUM(spend) Spend
from PlayerSpendTransaction
group by PlayerID
order by PlayerID 

return
end


GO


