USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionrptCalc]    Script Date: 03/18/2013 13:21:54 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptOccasionrptCalc]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptOccasionrptCalc]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptOccasionrptCalc]    Script Date: 03/18/2013 13:21:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



  
CREATE proc [dbo].[spRptOccasionrptCalc]  
@OperatorID int,  
@StartDate datetime,  
@OccasionID int  
as  
-- ======================================
-- Author: Karlo Camacho
-- Date Created: 2012
-- 03/18/2013 (knc) DE10884 - Correct the combined payout totals for the session.  FIXED
-- =======================================


-->>>>>>>>>>>TEST<<<<<<<<<<<<<<<<<<<<<<
--declare   
--@OperatorID int,  
--@StartDate datetime,  
--@OccasionID int  


--set @OperatorID = 1  
--set @StartDate = '3/18/2013 00:00:00'  
--set @OccasionID = 2 

--exec sp_helptext 'spRptOccasionrptCalc'
--exec spRptOccasionrptCalc 1,'12/05/2012 00:00:00', 0
-->>>>>>>>>>>>>END<<<<<<<<<<<<<<<<<<<<<<<
  
select   
OccasionScheduleBingoID,osb.OccasionScheduleID,  
GameNbr, isnull(FullWinners,0) FullWinners, isnull(HalfWinners,0) HalfWinners,   
isnull(PrizePerFullWinner,0) PrizePerFullWinner, isnull(PrizePerHalfWinner,0) PrizePerHalfWinner  
,CashPrize, isnull(NonCashPrize,0) NonCashPrize, PrizeFee,  OperatorID, [Date], Occasion   
into #a          
from OccasionScheduleBingo osb   
join OccasionSchedule os on os.OccasionScheduleID = osb.OccasionScheduleID   
where (Occasion = @OccasionID or @OccasionID = 0) 
and [Date] = @StartDate   
and OperatorID = @OperatorID  
and os.IsDeleted is null --DE10884/TA11653 

  
select cast(GameNo  as varchar(10))+'-'+  
case [type]  
when 'Event' then 'E'  
when 'Instant' then 'I'  
end [Game]  
, FormNo, SerialNo, isnull(LargePrizes,0.00) LargePrizes,   
isnull(SmallPrizes, 0.00) SmallPrizes,  
isnull(LargePrizes,0) + isnull(SmallPrizes,0) TotalPrizesAwarded,   
isnull(LargePrizeFee, 0) LargePrizeFee,  
isnull (SmallPrizeFee,  0)  SmallPrizeFee,  
(isnull(LargePrizes,0) + isnull(SmallPrizes,0))-(isnull(LargePrizeFee, 0)+ isnull (SmallPrizeFee,  0)) NetPayout  
 into #b  
 from OccasionSchedulePullTab ospt  
join OccasionScheduleType ost on ost.OccasionScheduleTypeID = ospt.OccasionScheduleTypeID   
join OccasionSchedule os on os.OccasionScheduleID = ospt.OccasionScheduleID   
where os.Date = @StartDate   
and os.OperatorID = @OperatorID   
--and os.Occasion = @OccasionID   
and (os.Occasion = @OccasionID or @OccasionID = 0)
and os.IsDeleted is null
  

  --if (select count(*) from #a) > 0 
  --begin 
--select * from #a   
declare @totalPrizeAmount money  
set @totalPrizeAmount =   
isnull((select /*sum(CashPrize) + sum(NonCashPrize) from #a*/  
sum((FullWinners *  PrizePerFullWinner)+ (HalfWinners * PrizePerHalfWinner) + NonCashPrize)      
from #a   
),0.00)  



declare @totalPrizeAwarded money  
set @totalPrizeAwarded = isnull((Select sum(TotalPrizesAwarded) from #b),0.00)  
  

  
declare @totalPayout money  
set @totalPayout = @totalPrizeAmount + @totalPrizeAwarded   


  
declare @prizeFeeBp money  
set @prizeFeeBp = isnull((select sum(PrizeFee)  from #a),0.00)  
  
  
  
declare @prizeFeePp money  
set @prizeFeePp = isnull((select sum(LargePrizeFee) + sum(SmallPrizeFee)   from #b),0.00)   
  

  
declare @prizeFee money  
set @prizeFee = @prizeFeeBp + @prizeFeePp   
 

  
declare @netPayout money  
set @netPayout = @totalPayout - @prizeFee   

if (@totalPayout = 0.00 and @prizeFee = 0.00 and @netPayout = 0.00)
begin
set @totalPayout = null
set @prizeFee = null
set @netPayout = null
select @totalPayout  [Total Payout], @prizeFee   [Total Prize Fees Collected],@netPayout [Net Payouts]  
end
else if (@totalPayout <> 0.00 or @prizeFee <> 0.00 or @netPayout <> 0.00)
begin
select @totalPayout  [Total Payout], @prizeFee   [Total Prize Fees Collected],@netPayout [Net Payouts] 
end

  
--select @totalPayout  [Total Payout], @prizeFee   [Total Prize Fees Collected],@netPayout [Net Payouts]  
drop table #a, #b   

  
  



GO


