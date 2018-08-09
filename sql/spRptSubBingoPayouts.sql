USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubBingoPayouts]    Script Date: 01/11/2013 11:18:52 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSubBingoPayouts]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSubBingoPayouts]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubBingoPayouts]    Script Date: 01/11/2013 11:18:52 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE proc [dbo].[spRptSubBingoPayouts]
@OperatorID int,
@Date datetime,
@OccasionID int
as
-- ====================================
-- Author: Karlo Camacho
-- Date Created: 2012
-- 1/11/2013 (knc): Add filter IsDeleted to removed duplicate rows -FIXED
-- ============================


select 
OccasionScheduleBingoID,osb.OccasionScheduleID,
GameNbr, isnull(FullWinners,0) FullWinners, isnull(HalfWinners,0) HalfWinners, 
isnull(PrizePerFullWinner,0) PrizePerFullWinner, isnull(PrizePerHalfWinner,0) PrizePerHalfWinner
,CashPrize, isnull(NonCashPrize,0) NonCashPrize, PrizeFee,  OperatorID, [Date], Occasion         
from OccasionScheduleBingo osb 
join OccasionSchedule os on os.OccasionScheduleID = osb.OccasionScheduleID 
where (Occasion = @OccasionID or @OccasionID = 0)
and [Date] = @Date 
and OperatorID = @OperatorID
and os.IsDeleted is null


GO


