USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spComps_AwardGroupPlayerComps]    Script Date: 04/11/2018 16:49:55 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spComps_AwardGroupPlayerComps]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spComps_AwardGroupPlayerComps]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spComps_AwardGroupPlayerComps]    Script Date: 04/11/2018 16:49:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


--exec spComps_AwardGroupPlayerComps 137,  174, 2

--select * from PlayerListDefinition
--select * from PlayerListDetail


CREATE  proc  [dbo].[spComps_AwardGroupPlayerComps]
(
--=============================================================================
-- 2015.07.20 Adding support for calling spRptPlayerList for retrieving the
--  list of players that are to receive the giving coupon
-- 20180409 tmp: DE14053 Filtering by Number of Sessions Played was not working.
--               Flag @IsNOfSessioPlayed was not set to 1 when the session parameters were set. 
--=============================================================================
    @operatorId int
    ,@definitionId int
    ,@compId int
    ,@playersAffected int output
)
as
set nocount on

declare @usageCount int
select @usageCount = MaxUsage
from Comps
where CompId = @compId

--Get every settingID per DefID
declare @SettingTable table
(
    SettingId int
    , SettingValue varchar(500)
)

insert into @SettingTable (SettingID, SettingValue) 
select SettingID, SettingValue from PlayerListDetail where ListDefinitionId = @definitionId

declare @BDFrom as Datetime
    ,@BDEnd as Datetime  
    ,@GenderType as nvarchar(4)
    ,@Min as Money
    ,@Max as Money
    ,@PBOptionSelected nvarchar(50)
    ,@PBOptionValue money   
    ,@LVStart as Datetime
    ,@LVEnd as Datetime 
    ,@Spend as bit  
    ,@Average as Bit
    ,@AmountFrom as money
    ,@AmountTo as money 
    ,@StartDate as Datetime
    ,@EndDate as Datetime 
    ,@SAOption as bit
    ,@SAOptionSelected nvarchar(50)
    ,@SAOptionValue money
    ,@StatusID as nvarchar(max)
    ,@LocationType int
    ,@LocationDefinition nvarchar(max)
    ,@IsNOfDaysPlayed bit 
    ,@IsNOfSessioPlayed bit
    ,@DPDateRangeFrom datetime
    ,@DPDateRangeTo datetime
    ,@IsDPRange bit
    ,@DPRangeFrom int--
    ,@DPRangeTo  int--
    ,@IsDPOption bit
    ,@DPOprtionSelected nvarchar(50)
    ,@DPOptionValue int
    ,@IsSPRange bit
    ,@SPRangeFrom int
    ,@SPRangeTo  int
    ,@IsSPOption bit
    ,@SPOprtionSelected nvarchar(50)
    ,@SPOptionValue int
    ,@DaysOfWeekNSessionNbr varchar(max)
    ,@IsPackageName bit
    ,@PackageName varchar(500)

-- Set the defaults for the parameters    
set @BDFrom = '1900-01-01 00:00:00'
set @BDEnd = '1900-01-01 00:00:00'  
set @GenderType = ''
set @Min = -1 
set @Max = 0
set @PBOptionSelected = ''
set @PBOptionValue = 0   
set @LVStart = '1900-01-01 00:00:00' 
set @LVEnd = '1900-01-01 00:00:00'  
set @Spend = 0  
set @Average = 0 
set @AmountFrom = 0 
set @AmountTo = 0  
set @StartDate = '1900-01-01 00:00:00' 
set @EndDate = '1900-01-01 00:00:00'
set @SAOption  = 0
set @SAOptionSelected = ''
set @SAOptionValue = 0   
set @StatusID = N''
set @LocationType = 0
set @LocationDefinition = N''
set @IsNOfDaysPlayed = 0 
set @IsNOfSessioPlayed = 0
set @DPDateRangeFrom = '1900-01-01 00:00:00'
set @DPDateRangeTo = '1900-01-01 00:00:00'
set @IsDPRange = 0
set @DPRangeFrom = 0
set @DPRangeTo  = 0
set @IsDPOption = 0
set @DPOprtionSelected = N''
set @DPOptionValue = 0
set @IsSPRange = 0
set @SPRangeFrom = 0
set @SPRangeTo  = 0
set @IsSPOption = 0
set @SPOprtionSelected = N''
set @SPOptionValue = 0
set @DaysOfWeekNSessionNbr = ''
set @IsPackageName = 0
set @PackageName = ''

--Lets create a cursor to iterate each data.
 
declare @SettingID int, @SettingValue varchar(500)
declare CursorSettingID cursor fast_forward 
for
select SettingID, SettingValue from @SettingTable 

Open CursorSettingID 
fetch next from  CursorSettingID 
into @SettingID, @SettingValue

while @@FETCH_STATUS = 0
begin

--select @SettingID, @SettingValue
	if (@SettingID = 1) set @GenderType = @SettingValue 
	else if (@SettingID = 2) set @StatusID = @SettingValue
	else if (@SettingID = 3) set @BDFrom = @SettingValue
	else if (@SettingID = 4) set @BDEnd =  @SettingValue
	else if (@SettingID = 5) begin set @LocationDefinition = @SettingValue set @LocationType = 1 end
	else if (@SettingID = 6) begin set @LocationDefinition = @SettingValue set @LocationType = 2 end
	else if (@SettingID = 7) begin set @LocationDefinition = @SettingValue set @LocationType = 3 end 
	else if (@SettingID = 8) begin set @LocationDefinition = @SettingValue set @LocationType = 4 end
	else if (@SettingID = 9) set @DPDateRangeFrom = @SettingValue
	else if (@SettingID = 10) set @DPDateRangeTo = @SettingValue
	else if (@SettingID = 11) set @LVStart = @SettingValue
	else if (@SettingID = 12) set @LVEnd = @SettingValue
	else if (@SettingID = 13) set @DPRangeFrom = @SettingValue
	else if (@SettingID = 14) set  @DPRangeTo = @SettingValue
	else if (@SettingID = 15) begin set @DPOprtionSelected = '>' set @DPOptionValue = @SettingValue end
	else if (@SettingID = 16) begin set @DPOprtionSelected = '>=' set @DPOptionValue = @SettingValue end
	else if (@SettingID = 17) begin set @DPOprtionSelected = '=' set @DPOptionValue = @SettingValue end
	else if (@SettingID = 18) begin set @DPOprtionSelected = '<=' set @DPOptionValue = @SettingValue end
	else if (@SettingID = 19) begin set @DPOprtionSelected = '<' set @DPOptionValue = @SettingValue end
	else if (@SettingID = 20) begin set @SPRangeFrom = @SettingValue set @IsNOfSessioPlayed  = 1 set @IsSPRange = 1 end   -- 20180409 tmp
	else if (@SettingID = 21) begin set @SPRangeTo = @SettingValue set @IsNOfSessioPlayed  = 1 set @IsSPRange = 1 end		-- 20180409 tmp
	else if (@SettingID = 22) begin set @SPOprtionSelected = '>' set @SPOptionValue = @SettingValue set @IsNOfSessioPlayed  = 1 set @IsSPOption = 1 end		-- 20180409 tmp
	else if (@SettingID = 23) begin set @SPOprtionSelected = '>=' set @SpOptionValue = @SettingValue set @IsNOfSessioPlayed  = 1 set @IsSPOption = 1 end		-- 20180409 tmp
	else if (@SettingID = 24) begin set @SPOprtionSelected = '=' set @SPOptionValue = @SettingValue set @IsNOfSessioPlayed  = 1 set @IsSPOption = 1 end		-- 20180409 tmp
	else if (@SettingID = 25) begin set @SPOprtionSelected = '<=' set @SPOptionValue = @SettingValue set @IsNOfSessioPlayed  = 1 set @IsSPOption = 1 end		-- 20180409 tmp
	else if (@SettingID = 26) begin set @SPOprtionSelected = '<' set @SPOptionValue = @SettingValue set @IsNOfSessioPlayed  = 1 set @IsSPOption = 1 end		-- 20180409 tmp
	else if (@SettingID = 27) begin set @DaysOfWeekNSessionNbr = @SettingValue set @IsNOfSessioPlayed  =1 end
	else if (@SettingID = 28) begin set @StartDate = @SettingValue end
	else if (@SettingID = 29) begin set @EndDate = @SettingValue end
	else if (@SettingID = 30) begin set @IsPackageName = 1 set @PackageName = @SettingValue end
	else if (@SettingID = 31) set @Min = @SettingValue 
 	else if (@SettingID = 32) set @Max = @SettingValue
	else if (@SettingID = 33) begin set @PBOptionSelected = '>' set @PBOptionValue = @SettingValue  end
	else if (@SettingID = 34) begin  set @PBOptionSelected = '>=' set @PBOptionValue = @SettingValue end
	else if (@SettingID = 35) begin set @PBOptionSelected = '=' set @PBOptionValue = @SettingValue end
	else if (@SettingID = 36) begin set @PBOptionSelected = '<=' set @PBOptionValue = @SettingValue end
	else if (@SettingID = 37) begin set @PBOptionSelected = '<' set @PBOptionValue = @SettingValue end
	else if (@SettingID = 38) begin set @IsSPRange = 1 set @AmountFrom = @SettingValue set @Spend = 1 end
	else if (@SettingID = 39) begin set @AmountTo = @SettingValue end
	else if (@SettingID = 40) begin set @SAOption = 1 set @SAOptionSelected = '>' set @SAOptionValue = @SettingValue set @Spend = 1 end
	else if (@SettingID = 41) begin set @SAOption = 1 set @SAOptionSelected = '>=' set @SAOptionValue = @SettingValue set @Spend = 1 end
	else if (@SettingID = 42) begin set @SAOption = 1 set @SAOptionSelected = '=' set @SAOptionValue = @SettingValue set @Spend = 1 end
	else if (@SettingID = 43) begin set @SAOption = 1 set @SAOptionSelected = '<=' set @SAOptionValue = @SettingValue set @Spend = 1 end
	else if (@SettingID = 44) begin set @SAOption = 1 set @SAOptionSelected = '<' set @SAOptionValue = @SettingValue set @Spend = 1 end
	else if (@SettingID = 45) begin set @IsSPRange = 1 set @AmountFrom = @SettingValue set @Average= 1 end
	else if (@SettingID = 46) begin set @AmountTo = @SettingValue end
	else if (@SettingID = 47) begin set @SAOption = 1 set @SAOptionSelected = '>' set @SAOptionValue = @SettingValue set @Average= 1 end
	else if (@SettingID = 48) begin set @SAOption = 1 set @SAOptionSelected = '>=' set @SAOptionValue = @SettingValue set @Average= 1 end
	else if (@SettingID = 49) begin set @SAOption = 1 set @SAOptionSelected = '=' set @SAOptionValue = @SettingValue set @Average= 1 end
	else if (@SettingID = 50) begin set @SAOption = 1 set @SAOptionSelected = '<=' set @SAOptionValue = @SettingValue set @Average= 1 end
	else if (@SettingID = 51) begin set @SAOption = 1 set @SAOptionSelected = '<' set @SAOptionValue = @SettingValue set @Average= 1 end

    fetch next from  CursorSettingID 
    into @SettingID, @SettingValue
end

CLOSE CursorSettingID 
DEALLOCATE CursorSettingID 

declare @PlayerList table
(
  PlayerID int
  ,FirstName nvarchar(32)   
  ,MiddleInitial nvarchar(4)   
  ,LastName nvarchar(32)   
  ,Birthdate datetime
  ,Email nvarchar(200)   
  ,Gender nvarchar(4)  
  ,Address1 nvarchar(64)   
  ,Address2 nvarchar(64)   
  ,City nvarchar(32)   
  ,State nvarchar(32)   
  ,Country nvarchar(32)   
  ,Zip nvarchar(32)  
  ,Refundable money   
  ,NonRefundable money  
  ,LastVisitDate datetime
  ,PointsBalance money   
  ,Spend money   
  ,AvgSpend money  
  ,Visits int  
  ,StatusName nvarchar(1000)
  ,OperatorID int  
  ,GovIssuedIdNum nvarchar(48)
  ,PlayerIdent nvarchar(64)
  ,Phone nvarchar(64)
  ,JoinDate datetime
  ,Comment nvarchar(510)
  ,MagCardNo nvarchar(64)
  ,NDaysPlayed int
  ,NSessionPlayed int    	
  ,GamingDate datetime
  ,SessionNbr int
  ,[Days] varchar(10)
)

insert into @PlayerList
exec spRptPlayerList @OperatorID, @BDFrom, @BDEnd, @GenderType, @Min, @Max, @PBOptionSelected, @PBOptionValue, @LVStart
    ,@LVEnd, @Spend, @Average, @AmountFrom, @AmountTo, @StartDate, @EndDate, @SAOption, @SAOptionSelected, @SAOptionValue
    ,@StatusID, @LocationType, @LocationDefinition, @IsNOfDaysPlayed, @IsNOfSessioPlayed, @DPDateRangeFrom , @DPDateRangeTo
    ,@IsDPRange,@DPRangeFrom, @DPRangeTo, @IsDPOption, @DPOprtionSelected, @DPOptionValue, @IsSPRange, @SPRangeFrom
    ,@SPRangeTo, @IsSPOption, @SPOprtionSelected, @SPOptionValue, @DaysOfWeekNSessionNbr, @IsPackageName, @PackageName

insert into CompAward
    (CompId, PlayerId, AwardedDate, AwardedCount, UsedCount)
select @compId, PlayerId, getdate(), @usageCount, 0
from @PlayerList
order by PlayerId

--Set The lastawardeddate
    update Comps
    set LastAwardedDate = GETDATE()
    where CompID = @compId

set @playersAffected = @@rowcount

set nocount off

GO

