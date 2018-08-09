USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubPulltabPayout]    Script Date: 01/11/2013 11:09:10 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSubPulltabPayout]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSubPulltabPayout]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSubPulltabPayout]    Script Date: 01/11/2013 11:09:10 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


    
CREATE proc [dbo].[spRptSubPulltabPayout]    
@OperatorID int,    
 @Date  datetime,     
@OccasionID int    
    
    
as    
-- ======================================
-- Author: Karlo Camacho
-- Created: 2012
-- (1/11/2013) -knc: Filter the Isdeleted on Occasion Schedule Table.
-- =======================================

-- =======================================
-- TEST
--set @OperatorID = 1    
--set @OccasionID = 1    
--set @Date = '2012-11-20 00:00:00'    
 -- exec spRptSubPulltabPayout 1,'1/11/2013 00:00:00',0
-- ============================================    
    
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
 from OccasionSchedulePullTab ospt    
join OccasionScheduleType ost on ost.OccasionScheduleTypeID = ospt.OccasionScheduleTypeID     
join OccasionSchedule os on os.OccasionScheduleID = ospt.OccasionScheduleID     
where os.Date = @Date     
and os.OperatorID = @OperatorID     
and (os.Occasion = @OccasionID or @OccasionID = 0)     
and os.IsDeleted is null
    
--18 
GO


