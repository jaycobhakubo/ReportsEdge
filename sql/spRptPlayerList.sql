USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerList]    Script Date: 10/07/2013 16:01:08 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerList]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerList]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerList]    Script Date: 10/07/2013 16:01:08 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[spRptPlayerList]
-- ============================================================================
-- Author:		GameTech
-- Description:	Print mailing labels for VIP players
--
-- BJS 10/05/2011: DE9192 cols 2 and 3 offset (unable to run report w/in Crystal due to param mismatch)
-- 2012.05.15 jkn: TA11038 Adding more fields to the result set and the entire set of status'
-- 2012.05.16 jkn: Fixed issue with the visit count being the same for all players
-- 2012.05.30 jkn: DE9843 Spend over date range was not being calculated correctly
--	also reformatted report for optimizations
-- 2012.06.05 jkn: DE9842 Ensure that the date range is not used if it is not specified
-- 2012.09.26 jkn: Fixed issue with potential divide by zero error.
-- 2013.09.10 jkn: Added default parameter to functions
-- 2013.09.19 knc: Convert Cast @StartDate and @EndDate to Date disregarding the time. 
-- ============================================================================
 @OperatorID as int,   
 @BDFrom as Datetime,      -- DE9192
 @BDEnd as Datetime,  
 @GenderType as nvarchar(4),
 @Min as Money,  
 @Max as Money,
 @PBOptionSelected nvarchar(50),
 @PBOptionValue money,   
 @LVStart as Datetime,  
 @LVEnd as Datetime,  
 @Spend as bit,  
 @Average as Bit,  
 @AmountFrom as money,  
 @AmountTo as money,  
 @StartDate as Datetime,  
 @EndDate as Datetime, 
 @SAOption as bit,
 @SAOptionSelected nvarchar(50),
 @SAOptionValue money,   
 @StatusID as nvarchar(max), 
 @LocationType int,
 @LocationDefinition nvarchar(max)
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
as



SET NOCOUNT ON  

declare @Birthday  bit set @Birthday = 0 if (@BDFrom <> '1900-01-01 00:00:00') set @Birthday = 1;    
declare @Gender bit set @Gender = 0 if (@GenderType <> '') set @Gender = 1;
declare @PBisOption bit			set @PBisOption = 0 if (@PBOptionSelected <> '') set @PBisOption = 1;
declare @PointsBalance bit	set  @PointsBalance = 0 if (@Min  <> -1) set @PointsBalance = 1;
declare @LastVisit  bit			set @LastVisit = 0 if (@LVStart <> '1900-01-01 00:00:00') set @LastVisit = 1;
declare @Status   Bit			set @Status = 0 if (@StatusID <> '') set @Status = 1;
declare @CityName varchar(max)  set @CityName = '' if (@LocationType = 1) set @CityName = @LocationDefinition ;
declare @State varchar(max)		set @State = ''	if (@LocationType = 2) set @State = @LocationDefinition ;
declare @ZipCode varchar(max)   set @ZipCode = '' if (@LocationType = 3) set @ZipCode = @LocationDefinition ;
declare @Country varchar(max)   set @Country = '' if (@LocationType = 4) set @Country = @LocationDefinition ;
set @StartDate =  cast(CONVERT(VARCHAR(10),@StartDate,10) as datetime)
set @EndDate =  cast(CONVERT(VARCHAR(10),@EndDate,10) as datetime)

declare @TempPlayerList table
 (FirstName nvarchar(32),   
 MiddleInitial nvarchar(4),   
 LastName nvarchar(32),   
 PlayerID int,   
 Birthdate datetime,   -- DE9192
 Email nvarchar(200),   
 Gender nvarchar(4),  
 Address1 nvarchar(64),   
 Address2 nvarchar(64),   
 City nvarchar(32),   
 State nvarchar(32),   
 Country nvarchar(32),   
 Zip nvarchar(32),  
 Refundable money,   
 NonRefundable money,  
 LastVisitDate datetime,   -- DE9192
 PointsBalance money,   
 OperatorID int,  
 Spend money,   
 Visits int,  
 AvgSpend money,
 GovIssuedIdNum nvarchar(48),
 PlayerIdent nvarchar(64),
 Phone nvarchar(64),
 JoinDate datetime,
 Comment nvarchar(510),
 MagCardNo nvarchar(64))  

set @LVEnd = Dateadd(Day,1,@LVEnd)  
set @EndDate = Dateadd(Day,1,@EndDate)


-- Shift the birthday start and end to a leap year to account for leap day
--	birthdays.
-- These calculations determine the difference in years from the given year 
--	to a leap year and then changes the start and end year to the leap year
set @BDFrom = dateadd(year, datediff(year, @BDFrom, '1/1/2000'), @BDFrom)
set @BDEnd = dateadd(year, datediff(year, @BDEnd, '1/1/2000'), @BDEnd)
--select @BDFrom, @BDEnd  --GOOD



if (@Average = 1 or @Spend =1)
begin
	;with PlayerSpendData (Spend,AvgSpend,PlayerId)
	as
	(
		select TotalSpend, AverageSpend, PlayerID from dbo.fnGetSpendAveragePerPlayer(@OperatorID,@StartDate, datediff(Day,1,@EndDate),default)
	)
	 -- INSERT ALL Players into this temporary table  
	insert into @TempPlayerList
	(FirstName, MiddleInitial, LastName, PlayerID, Birthdate
	,Email, Gender, Address1, Address2, City
	,State, Country, Zip, Refundable, NonRefundable
	,LastVisitDate, PointsBalance, OperatorID, Spend, Visits
	,AvgSpend, GovIssuedIdNum, PlayerIdent, Phone, JoinDate
	,Comment, MagCardNo)
	 select
	p.FirstName, p.MiddleInitial, p.LastName, p.PlayerID, p.BirthDate
	,p.EMail, p.Gender, a.Address1, a.Address2, a.City
	,a.State, a.Country, a.Zip, isnull(cb.Refundable, 0), isnull(cb.NonRefundable, 0)
	,pInfo.LastVisitDate, isnull(pb.pbPointsBalance, 0), @OperatorID, isnull(psd.Spend, 0), pInfo.VisitCount
	,isnull(psd.AvgSpend, 0), p.GovIssuedIDNum, p.PlayerIdent, p.Phone, pInfo.FirstVisitDate
	,pInfo.Comment, pmc.MagneticCardNo
	from Player p
	join [Address] a on p.AddressID = a.AddressID
	join PlayerInformation pInfo on p.PlayerId = pInfo.PlayerId
	join CreditBalances cb on pInfo.CreditBalancesId = cb.CreditBalancesId
	join PointBalances pb on pInfo.PointBalancesId = pb.pbPointBalancesId
	left join PlayerMagCards pmc on p.PlayerId = pmc.PlayerId
	/*DE11153/TA11924 left -->*/  join PlayerSpendData psd on psd.PlayerId = p.PlayerId/*<--DE11153/TA11924 */
end
else 
begin
	;with PlayerSpendData (Spend,AvgSpend,PlayerId)
	as
	(select TotalSpend, /*AverageSpend*/ null, PlayerID from dbo.fnGetSpendAveragePerPlayer(@OperatorID,'1/1/1900', getdate(),default)

	)
	 -- INSERT ALL Players into this temporary table  
	insert into @TempPlayerList
	(FirstName, MiddleInitial, LastName, PlayerID, Birthdate
	,Email, Gender, Address1, Address2, City
	,State, Country, Zip, Refundable, NonRefundable
	,LastVisitDate, PointsBalance, OperatorID, Spend, Visits
	,AvgSpend, GovIssuedIdNum, PlayerIdent, Phone, JoinDate
	,Comment, MagCardNo)
	 select
	p.FirstName, p.MiddleInitial, p.LastName, p.PlayerID, p.BirthDate
	,p.EMail, p.Gender, a.Address1, a.Address2, a.City
	,a.State, a.Country, a.Zip, isnull(cb.Refundable, 0), isnull(cb.NonRefundable, 0)
	,pInfo.LastVisitDate, isnull(pb.pbPointsBalance, 0), @OperatorID, isnull(psd.Spend, 0), pInfo.VisitCount
	,/*isnull(psd.AvgSpend, 0)*/psd.AvgSpend , p.GovIssuedIDNum, p.PlayerIdent, p.Phone, pInfo.FirstVisitDate
	,pInfo.Comment, pmc.MagneticCardNo
	from Player p
	join [Address] a on p.AddressID = a.AddressID
	join PlayerInformation pInfo on p.PlayerId = pInfo.PlayerId
	join CreditBalances cb on pInfo.CreditBalancesId = cb.CreditBalancesId
	join PointBalances pb on pInfo.PointBalancesId = pb.pbPointBalancesId
	left join PlayerMagCards pmc on p.PlayerId = pmc.PlayerId
	/*DE11153/TA11924 left -->*/ left join PlayerSpendData psd on psd.PlayerId = p.PlayerId/*<--DE11153/TA11924 */
end




  create table #TempPlayer
  (FirstName nvarchar(32),   
  MiddleInitial nvarchar(4),   
  LastName nvarchar(32),   
  PlayerID int,   
  Birthdate datetime,     -- DE9192
  Email nvarchar(200),   
  Gender nvarchar(4),  
  Address1 nvarchar(64),   
  Address2 nvarchar(64),   
  City nvarchar(32),   
  State nvarchar(32),   
  Country nvarchar(32),   
  Zip nvarchar(32),  
  Refundable money,   
  NonRefundable money,  
  LastVisitDate datetime,     -- DE9192
  PointsBalance money,   
  OperatorID int,  
  Spend money,   
  Visits int,  
  AvgSpend money,  
  StatusName nvarchar(1000),
  GovIssuedIdNum nvarchar(48),
  PlayerIdent nvarchar(64),
  Phone nvarchar(64),
  JoinDate datetime,
  Comment nvarchar(510),
  MagCardNo nvarchar(64)
  ,NDaysPlayed int
  ,NSessionPlayed int    	
   ,[Days] varchar(10), 
   SessionNbr int, 
   GamingDate datetime)

  declare   @TempPlayer table
  (FirstName nvarchar(32),   
  MiddleInitial nvarchar(4),   
  LastName nvarchar(32),   
  PlayerID int,   
  Birthdate datetime,     -- DE9192
  Email nvarchar(200),   
  Gender nvarchar(4),  
  Address1 nvarchar(64),   
  Address2 nvarchar(64),   
  City nvarchar(32),   
  State nvarchar(32),   
  Country nvarchar(32),   
  Zip nvarchar(32),  
  Refundable money,   
  NonRefundable money,  
  LastVisitDate datetime,     -- DE9192
  PointsBalance money,   
  OperatorID int,  
  Spend money,   
  Visits int,  
  AvgSpend money,  
  StatusName nvarchar(1000),
  GovIssuedIdNum nvarchar(48),
  PlayerIdent nvarchar(64),
  Phone nvarchar(64),
  JoinDate datetime,
  Comment nvarchar(510),
  MagCardNo nvarchar(64)
  ,NDaysPlayed int
  ,NSessionPlayed int    	
   ,[Days] varchar(10), 
   SessionNbr int, 
   GamingDate datetime) 

   if (@PBisOption = 1)
   begin 
   set @PointsBalance = 0
   end

insert into #TempPlayer
( FirstName, MiddleInitial, LastName, PlayerID, Birthdate
, Email, Gender, Address1, Address2, City
, [State], Country, Zip, Refundable, NonRefundable
, LastVisitDate, PointsBalance, PIN.OperatorID, Spend, Visits
, AvgSpend, GovIssuedIdNum, PlayerIdent, Phone, JoinDate
, Comment, MagCardNo )  
select
tpl.FirstName, tpl.MiddleInitial, tpl.LastName, tpl.PlayerID, tpl.Birthdate
, tpl.Email, tpl.Gender, tpl.Address1, tpl.Address2, tpl.City
, tpl.State, tpl.Country, tpl.Zip, tpl.Refundable, tpl.NonRefundable
, tpl.LastVisitDate, tpl.PointsBalance, tpl.OperatorID, tpl.Spend, tpl.Visits
, tpl.AvgSpend, tpl.GovIssuedIdNum, tpl.PlayerIdent, tpl.Phone, tpl.JoinDate
, tpl.Comment, tpl.MagCardNo
from @TempPlayerList tpl  
where --(@Birthday = 0 or datepart(dayofyear, tpl.Birthdate)+1 between datepart(dayofyear, @BDFrom) and datepart(dayofyear, @BDEnd))--Issue with leap year
(
@Birthday = 0 
or
(select dbo.FNGetMonthDayEquivalentToInt(tpl.Birthdate)) between (select dbo.FNGetMonthDayEquivalentToInt(@BDFrom)) and (select dbo.FNGetMonthDayEquivalentToInt(@BDEnd))
 )
and (@Gender = 0 or tpl.Gender = @GenderType)   
--	and (@PointsBalance = 0 or tpl.PointsBalance >= @Min and tpl.PointsBalance <= @Max)  
and (@PointsBalance = 0 or tpl.PointsBalance between @Min and @Max)
and (@LastVisit = 0 or tpl.LastVisitDate >= cast(convert(varchar(12), @LVStart, 101) as smalldatetime)   
and tpl.LastVisitDate < cast(convert(varchar(12), @LVEnd, 101) as smalldatetime))
-- DE7912 - Collect all the player's statuses (and potentially filter them out).
--and (@Status = 0 or exists(select 1 from PlayerStatus where PlayerID = tpl.PlayerID AND PlayerStatusCodeID = @StatusID))
and (@Country = '' or tpl.Country in (select Country from FnRptPlayerListLocationCountry(@Country)))
and (@CityName = '' or tpl.City in (select City from FnRptPlayerListLocationCity(@CityName)))
and (@ZipCode = '' or tpl.Zip in (select ZipCode from  FnRptPlayerListLocationZipCode(@ZipCode)))
and (@State = '' or tpl.State in (select [State] from FnRptPlayerListLocationState(@State)))
	



	declare @IsDaysOfWeeknSession bit
	if (@DaysOfWeekNSessionNbr = '')  --If its empty
	begin
		Set @IsDaysOfWeeknSession = 0	 
	end
	else --If it has something
	begin
		set @IsDaysOfWeeknSession = 1
	end

	if (@IsDaysOfWeeknSession = 1 or @IsNOfDaysPlayed = 1 or @IsNOfSessioPlayed = 1)
	begin
		if (@IsDaysOfWeeknSession = 1) 
		begin 
			declare @Count int set @Count = 0;
			declare @PatIndex int set @PatIndex = 0;
			set @PatIndex = patindex('%,%', @DaysOfWeekNSessionNbr)
			set @DaysOfWeekNSessionNbr = @DaysOfWeekNSessionNbr + ','
			declare @Len int set @Len = 0;
			declare @Start int set @Start = 0;
					
			if (@PatIndex <> 0)
			begin 
				while (@PatIndex <> 0)
				begin
					set @Len = (select len(@DaysOfWeekNSessionNbr));
					set @Start = (select patindex('%,%', @DaysOfWeekNSessionNbr)); 
					
					insert into  @TempPlayer
					(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
					, Email, Gender, Address1, Address2, City
					, [State], Country, Zip, Refundable, NonRefundable
					, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
					, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
					, JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed, GamingDate, SessionNBR, [Days])
					select  TP.PlayerID, FirstName, MiddleInitial, LastName, BirthDate
					, Email, Gender, Address1, Address2, City
					, [State], Country, Zip, Refundable, NonRefundable
					, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
					, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
					, JoinDate, Comment, MagCardNo, NDaysPlayed, NSessionPlayed, x.GamingDate, x.GamingSession, x.Days    from #TempPlayer tp 
					join (select  PlayerID, GamingDate, GamingSession, [Days] from [dbo].[FnRptPlayerListDaysOfWeekNSessionNbr]( @DPDateRangeFrom, @DPDateRangeTo, substring( @DaysOfWeekNSessionNbr,1 ,@Start - 1))) x
					on x.PlayerID = tp.PlayerID 
						
					

					
					select @DaysOfWeekNSessionNbr = substring (@DaysOfWeekNSessionNbr, @Start + 1 , @Len)
					set @PatIndex = PATINDEX ('%,%', @DaysOfWeekNSessionNbr)
				end
				
				delete from #TempPlayer 
				
				insert into #TempPlayer
				(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed, GamingDate, SessionNBR, [Days])
				select 
				PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed, GamingDate, SessionNbr,[Days]    
				from @TempPlayer  		
				delete from @TempPlayer 			
			end
			else 
			begin	
				insert into  @TempPlayer
				(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
				, Email, Gender, Address1, Address2, City
				, [State], Country, Zip, Refundable, NonRefundable
				, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
				, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
				, JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed, GamingDate, SessionNBR, [Days])
				select  TP.PlayerID, FirstName, MiddleInitial, LastName, BirthDate
				, Email, Gender, Address1, Address2, City
				, [State], Country, Zip, Refundable, NonRefundable
				, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
				, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
				, JoinDate, Comment, MagCardNo, NDaysPlayed, NSessionPlayed, x.GamingDate, x.GamingSession, x.Days    from #TempPlayer tp 
				join (select  PlayerID, GamingDate, GamingSession, [Days] from [dbo].[FnRptPlayerListDaysOfWeekNSessionNbr]( @DPDateRangeFrom, @DPDateRangeTo, substring( @DaysOfWeekNSessionNbr,1 ,len(@DaysOfWeekNSessionNbr) - 1))) x
				on x.PlayerID = tp.PlayerID 
			
				delete from #TempPlayer 
				
				insert into #TempPlayer
				(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed, GamingDate, SessionNBR, [Days])
				select 
				PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed, GamingDate, SessionNbr,[Days]    
				from @TempPlayer  													
				delete from @TempPlayer 	
			end
					
			select * into #Test from #TempPlayer
			select PlayerID,Days  [NDaysPlayed] into #Test2 from #Test group by PlayerID, GamingDate,Days  order by PlayerID asc --745
			delete from #TempPlayer 
			insert into #TempPlayer 
			(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			, Email, Gender, Address1, Address2, City
			, [State], Country, Zip, Refundable, NonRefundable
			, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			, JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed)
			select distinct t1.PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			, Email, Gender, Address1, Address2, City
			, [State], Country, Zip, Refundable, NonRefundable
			, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			, JoinDate, Comment, MagCardNo  , t3.NDaysPlayed , t2.NSessionPlayed /*, GamingDate, SessionNBR, [Days]*/ from #Test t1 -- 148			
			join (select PlayerID, count(SessionNbr) NSessionPlayed  from #Test group by PlayerID)  t2 on  t2.PlayerID = t1.PlayerID  
			join  (select PlayerID , count(NdaysPlayed) NDaysPlayed from #Test2 group by PlayerID)  t3 on t3.PlayerID = t1.PlayerID  

				declare   @Visit table
				(FirstName nvarchar(32),   
				MiddleInitial nvarchar(4),   
				LastName nvarchar(32),   
				PlayerID int,   
				Birthdate datetime,     -- DE9192
				Email nvarchar(200),   
				Gender nvarchar(4),  
				Address1 nvarchar(64),   
				Address2 nvarchar(64),   
				City nvarchar(32),   
				State nvarchar(32),   
				Country nvarchar(32),   
				Zip nvarchar(32),  
				Refundable money,   
				NonRefundable money,  
				LastVisitDate datetime,     -- DE9192
				PointsBalance money,   
				OperatorID int,  
				Spend money,   
				Visits int,  
				AvgSpend money,  
				StatusName nvarchar(1000),
				GovIssuedIdNum nvarchar(48),
				PlayerIdent nvarchar(64),
				Phone nvarchar(64),
				JoinDate datetime,
				Comment nvarchar(510),
				MagCardNo nvarchar(64)
				,NDaysPlayed int
				,NSessionPlayed int    	
				,[Days] varchar(10), 
				SessionNbr int, 
				GamingDate datetime) 

			delete from @TempPlayer 
			if (@IsNOfDaysPlayed = 1)
			begin 
				if (@IsDPRange = 1)
				begin 
			
					insert into @TempPlayer 
					select * from #TempPlayer where NDaysPlayed >= @DPRangeFrom and NDaysPlayed <= @DPRangeTo 					
					
				end
				else if (@IsDPOption = 1)
				begin
	
				 insert into @TempPlayer 
				 select * from #TempPlayer 
				 where 
				 case 
				 when @DPOprtionSelected = '>' and NDaysPlayed > @DPOptionValue then 1
				 when @DPOprtionSelected = '>=' and NDaysPlayed >= @DPOptionValue then 1
				 when @DPOprtionSelected = '=' and NDaysPlayed = @DPOptionValue then 1
				 when @DPOprtionSelected = '<' and NDaysPlayed < @DPOptionValue then 1
				  when @DPOprtionSelected = '<=' and NDaysPlayed <= @DPOptionValue then 1
				  else 0
				end = 1
				end
							
			end
			
			if (@IsNOfSessioPlayed = 1)
			begin
			
				if (@IsSPRange = 1)
				begin 			
					insert into @TempPlayer 
					select * from #TempPlayer where NSessionPlayed  >= @SPRangeFrom and NSessionPlayed  <= @SPRangeTo 										
				end
				else if (@IsSPOption = 1)
				begin
					 insert into @TempPlayer 
					 select * from #TempPlayer 
					 where 
					 case 
						 when @SPOprtionSelected = '>' and NSessionPlayed > @SPOptionValue then 1
						 when @SPOprtionSelected = '>=' and NSessionPlayed >= @SPOptionValue then 1
						 when @SPOprtionSelected = '=' and NSessionPlayed = @SPOptionValue then 1
						 when @SPOprtionSelected = '<' and NSessionPlayed < @SPOptionValue then 1
						 when @SPOprtionSelected = '<=' and NSessionPlayed <= @SPOptionValue then 1
						 else 0
					end = 1
				end
			end
			
				
				Insert into @Visit 
				select *  from @TempPlayer 
				delete from @TempPlayer 
			
			drop table #Test2 
			drop table #Test 

		end
		



	--#Days Played
		declare @NDaysCheck int set @NDaysCheck = 0;--DE11148_A
		if (@IsNOfDaysPlayed = 1)
		begin 
			set @NDaysCheck = 1--DE11148_B
			if (@IsDPRange = 1)
			begin			
				insert into @TempPlayer  
				 (PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  ,   NDaysPlayed, NSessionPlayed )
				select   TP.PlayerID, FirstName, MiddleInitial, LastName, BirthDate
				, Email, Gender, Address1, Address2, City
				, [State], Country, Zip, Refundable, NonRefundable
				, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
				, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
				, JoinDate, Comment, MagCardNo, x.Nvisit, y.NSessionPlayed    from #TempPlayer TP join 
				(   select PlayerID, GamingDate, Nvisit from  FnNDaysPlayed(nullif(@DPDateRangeFrom,'1900-01-01 00:00:00') ,nullif(@DPDateRangeTo,'1900-01-01 00:00:00') ,@IsDPRange ,@DPRangeFrom ,@DPRangeTo ,null,null,null)) x --this works
				on x.PlayerID = TP.PlayerID 
				join (   select PlayerID, GamingDate, NSessionPlayed  from  FnNSessionPlayed (nullif(@DPDateRangeFrom,'1900-01-01 00:00:00') ,nullif(@DPDateRangeTo,'1900-01-01 00:00:00') ,null ,null  ,null  ,null,null,null)) y --this works
				on y.PlayerID = TP.PlayerID 	
				

				delete from #TempPlayer 
				insert into #TempPlayer (PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  ,   NDaysPlayed, NSessionPlayed )
				select PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  ,   NDaysPlayed , NSessionPlayed  from @TempPlayer 
				delete from @TempPlayer 
				

			end
			else if(@IsDPOption = 1)
			begin 
		 
		   insert into @TempPlayer 
	   		(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  ,   NDaysPlayed )
				
			select   TP.PlayerID, FirstName, MiddleInitial, LastName, BirthDate
				, Email, Gender, Address1, Address2, City
				, [State], Country, Zip, Refundable, NonRefundable
				, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
				, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
				, JoinDate, Comment, MagCardNo, x.Nvisit   from #TempPlayer TP join 
				(   select PlayerID, GamingDate, Nvisit from  FnNDaysPlayed(nullif(@DPDateRangeFrom,'1900-01-01 00:00:00') ,nullif(@DPDateRangeTo,'1900-01-01 00:00:00')   ,null ,null ,null ,@IsDPOption , @DPOprtionSelected ,@DPOptionValue)) x --this works
				on x.PlayerID = TP.PlayerID 

				delete from #TempPlayer 
				insert into #TempPlayer (PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  ,   NDaysPlayed )
				select PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  ,   NDaysPlayed   from @TempPlayer 
				delete from @TempPlayer 
							
			end
			-- all player that play on monday that attended session 1:2:3
			-- if the player attended 1 2 3 then it will only count as one.
		
		end
			--SESSION 
		
		
		if (@IsNOfSessioPlayed  = 1 )
		begin 
			set @NDaysCheck = 2--DE11148_C
			if (@IsSPRange = 1)
			begin
			
			insert into @TempPlayer 
			(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo, NDaysPlayed   ,  NSessionPlayed  )

			select   TP.PlayerID, FirstName, MiddleInitial, LastName, BirthDate
				, Email, Gender, Address1, Address2, City
				, [State], Country, Zip, Refundable, NonRefundable
				, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
				, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
				, JoinDate, Comment, MagCardNo ,NDaysPlayed  ,x.NSessionPlayed     from #TempPlayer TP join 
				(   select PlayerID, GamingDate, NSessionPlayed  from  FnNSessionPlayed (nullif(@DPDateRangeFrom,'1900-01-01 00:00:00') ,nullif(@DPDateRangeTo,'1900-01-01 00:00:00') ,@IsSPRange ,@SPRangeFrom  ,@SPRangeTo  ,null,null,null)) x --this works
				on x.PlayerID = TP.PlayerID 

				delete from #TempPlayer 
				insert into #TempPlayer (PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo, NDaysPlayed   ,  NSessionPlayed  )
				select PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo, NDaysPlayed   , NSessionPlayed     from @TempPlayer
				delete from @TempPlayer 		

			end 
		
			else if (@IsSPOption = 1)
			begin 

			insert into @TempPlayer 
			(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed  )
				select   TP.PlayerID, FirstName, MiddleInitial, LastName, BirthDate
				, Email, Gender, Address1, Address2, City
				, [State], Country, Zip, Refundable, NonRefundable
				, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
				, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
				, JoinDate, Comment, MagCardNo, NDaysPlayed ,x.NSessionPlayed    from #TempPlayer  TP join 
				(   select PlayerID, GamingDate, NSessionPlayed  from  FnNSessionPlayed (nullif(@DPDateRangeFrom,'1900-01-01 00:00:00') ,nullif(@DPDateRangeTo,'1900-01-01 00:00:00')  ,null ,null ,null ,@IsSPOption , @SPOprtionSelected ,@SPOptionValue )) x --this works
				on x.PlayerID = TP.PlayerID 

				delete from #TempPlayer 
				insert into #TempPlayer (PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed  )
				select PlayerID, FirstName, MiddleInitial, LastName, BirthDate
			  , Email, Gender, Address1, Address2, City
			  , [State], Country, Zip, Refundable, NonRefundable
			  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
			  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
			  , JoinDate, Comment, MagCardNo,  NDaysPlayed  ,   NSessionPlayed   from @TempPlayer  
				delete from @TempPlayer 								
			end
		end
		
		
		insert into #TempPlayer 
		select dp.* from @Visit  dp 
		left join #TempPlayer tp on dp.PlayerID = tp.PlayerID 
		where tp.PlayerID is null
	

		delete from @Visit 
	
		
		

end
	--PACKAGE PURCHASED

	if (@IsPackageName = 1)
	begin
		set @EndDate = DATEDIFF(day, 1, @EndDate) 

		insert into @TempPlayer 
		(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
		, Email, Gender, Address1, Address2, City
		, [State], Country, Zip, Refundable, NonRefundable
		, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
		, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
		, JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed  )
		select   TP.PlayerID, FirstName, MiddleInitial, LastName, BirthDate
		, Email, Gender, Address1, Address2, City
		, [State], Country, Zip, Refundable, NonRefundable
		, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
		, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
		, JoinDate, Comment, MagCardNo, NDaysPlayed ,NSessionPlayed   from #TempPlayer  TP join 
		(   select PlayerID from  FnRptPlayerListProductPurchased (@PackageName, nullif(@StartDate,'1900-01-01 00:00:00') ,nullif(@EndDate,'1900-01-02 00:00:00')))  x
		on x.PlayerID = TP.PlayerID 

		
		delete from #TempPlayer 
		insert into #TempPlayer
		(PlayerID, FirstName, MiddleInitial, LastName, BirthDate
		, Email, Gender, Address1, Address2, City
		, [State], Country, Zip, Refundable, NonRefundable
		, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
		, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
		, JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed, GamingDate, SessionNBR, [Days])
		select 
		PlayerID, FirstName, MiddleInitial, LastName, BirthDate
		, Email, Gender, Address1, Address2, City
		, [State], Country, Zip, Refundable, NonRefundable
		, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
		, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
		, JoinDate, Comment, MagCardNo  , NDaysPlayed , NSessionPlayed, GamingDate, SessionNbr,[Days]    
		from @TempPlayer  
		delete from @TempPlayer 

	end

	--# Point Balance So far I am going to do this I cant think of any easier way 
		if (@PBisOption = 1) 
		begin	
		
		create table #TempPlayer2
		(FirstName nvarchar(32),   
		MiddleInitial nvarchar(4),   
		LastName nvarchar(32),   
		PlayerID int,   
		Birthdate datetime,     -- DE9192
		Email nvarchar(200),   
		Gender nvarchar(4),  
		Address1 nvarchar(64),   
		Address2 nvarchar(64),   
		City nvarchar(32),   
		State nvarchar(32),   
		Country nvarchar(32),   
		Zip nvarchar(32),  
		Refundable money,   
		NonRefundable money,  
		LastVisitDate datetime,     -- DE9192
		PointsBalance money,   
		OperatorID int,  
		Spend money,   
		Visits int,  
		AvgSpend money,  
		StatusName nvarchar(1000),
		GovIssuedIdNum nvarchar(48),
		PlayerIdent nvarchar(64),
		Phone nvarchar(64),
		JoinDate datetime,
		Comment nvarchar(510),
		MagCardNo nvarchar(64)
		,NDaysPlayed int
		,NSessionPlayed int    	
		,[Days] varchar(10), 
		SessionNbr int, 
		GamingDate datetime)
				
			if (@PBOptionSelected = '>')
			begin 
			delete from #TempPlayer2
			insert into #TempPlayer2 
			select  * from #TempPlayer  
			where PointsBalance > @PBOptionValue 
			end
			else if (@PBOptionSelected = '>=')
			begin
			delete from #TempPlayer2
			insert into #TempPlayer2 
			select  * from #TempPlayer  
			where PointsBalance >= @PBOptionValue 
			end
			else if (@PBOptionSelected = '=')
			begin
			delete from #TempPlayer2
			insert into #TempPlayer2 
			select  * from #TempPlayer  
			where PointsBalance = @PBOptionValue 
			end 
			else if (@PBOptionSelected = '<=')
			begin 
			delete from #TempPlayer2
			insert into #TempPlayer2 
			select  * from #TempPlayer  
			where PointsBalance <= @PBOptionValue 
			end
			else if (@PBOptionSelected = '<')
			begin
			delete from #TempPlayer2
			insert into #TempPlayer2 
			select  * from #TempPlayer 
			where PointsBalance < @PBOptionValue  
			end 	
		delete from #TempPlayer 
		insert into #TempPlayer 
		select * from #TempPlayer2 
		drop table #TempPlayer2 


		end 
	
	--# Spend And Average Option Selected
	if (@SAOption = 1)
	begin
		create table #TempPlayer3
		(FirstName nvarchar(32),   
		MiddleInitial nvarchar(4),   
		LastName nvarchar(32),   
		PlayerID int,   
		Birthdate datetime,     -- DE9192
		Email nvarchar(200),   
		Gender nvarchar(4),  
		Address1 nvarchar(64),   
		Address2 nvarchar(64),   
		City nvarchar(32),   
		State nvarchar(32),   
		Country nvarchar(32),   
		Zip nvarchar(32),  
		Refundable money,   
		NonRefundable money,  
		LastVisitDate datetime,     -- DE9192
		PointsBalance money,   
		OperatorID int,  
		Spend money,   
		Visits int,  
		AvgSpend money,  
		StatusName nvarchar(1000),
		GovIssuedIdNum nvarchar(48),
		PlayerIdent nvarchar(64),
		Phone nvarchar(64),
		JoinDate datetime,
		Comment nvarchar(510),
		MagCardNo nvarchar(64)
		,NDaysPlayed int
		,NSessionPlayed int    	
		,[Days] varchar(10), 
		SessionNbr int, 
		GamingDate datetime)

			if (@SAOptionSelected = '>')
			begin 
				if (@Spend = 1)
				begin 
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where Spend > @SAOptionValue 
				end
				if (@Average  = 1)
				begin 							
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where AvgSpend  > @SAOptionValue 					
				end
					
			end 

			else if (@SAOptionSelected = '>=')
			begin
				if (@Spend = 1)
				begin 
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where Spend >= @SAOptionValue 
				end
				if (@Average  = 1)
				begin 
				
				print @Average
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where AvgSpend  >=  @SAOptionValue 
				end
			end

			else if (@SAOptionSelected = '=')
			begin
				if (@Spend = 1)
				begin 
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where Spend = @SAOptionValue 
				end
				if (@Average  = 1)
				begin 
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where AvgSpend  = @SAOptionValue 
				end
			end 

			else if (@SAOptionSelected = '<=')
			begin 
				if (@Spend = 1)
				begin 
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where Spend <= @SAOptionValue 
				end
				if (@Average  = 1)
				begin 
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where AvgSpend  <= @SAOptionValue 
				end
			end

			else if (@SAOptionSelected = '<')
			begin
				if (@Spend = 1)
				begin 
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where Spend < @SAOptionValue 
				end
				if (@Average  = 1)
				begin 
					delete from #TempPlayer3 
					insert into #TempPlayer3 
					select * from #TempPlayer 
					where AvgSpend  < @SAOptionValue 
				end
			end 	

		delete from #TempPlayer 
		insert into #TempPlayer 
		select * from #TempPlayer3 
		drop table #TempPlayer3 


	end



if (@Status = 1)
begin

	--Add all of the Status' to the result set
	declare @statusName nvarchar(1000), @curPlayerId int

	declare StatusCursor cursor for select PlayerID from #TempPlayer where playerid in (787, 1595, 1692)
	open StatusCursor
	fetch next from StatusCursor into @curPlayerId
	while @@fetch_status = 0
	begin
		set @statusName = ''
		--select @statusName
		select @statusName = @statusName + '|' + psc.StatusName	
		from PlayerStatus ps
			join PlayerStatusCode psc on ps.PlayerStatusCodeId = psc.PlayerStatusCodeId
		where
			ps.PlayerId = @curPlayerId
	

			--select @statusName

			--if (@statusName != '')
			--			begin
			
			--			select @curPlayerId
			--			select 	@statusName	

			--		select  psc.StatusName	
			--		from PlayerStatus ps
			--			join PlayerStatusCode psc on ps.PlayerStatusCodeId = psc.PlayerStatusCodeId
			--		where
			--			ps.PlayerId = @curPlayerId
			--end
				
		if (len(@statusName) > 0)
		begin
			set @statusName = right(@statusName, (len(@statusName) - 1))
		end		
	
	

		update #TempPlayer
		set StatusName = @statusName
		where current of StatusCursor
	
		fetch next from StatusCursor into @curPlayerId
	end
	close StatusCursor
	deallocate StatusCursor



	delete from @TempPlayer 
	insert into @TempPlayer 
	select * from #TempPlayer 
	delete from #TempPlayer 

	--select @StatusID
	--select * from @TempPlayer where [StatusName] not like ''
		

	declare @x int
	select @x = charindex('/|\',@StatusID)
	if (@x !=  0)
	begin
		set  @StatusID = REPLACE(@StatusID,'/|\','|') 
		insert into #TempPlayer 
		select * from @TempPlayer 
		where StatusName = @StatusID 	
	end
	else if (@x = 0)
	begin

--declare @StatusID varchar(100) = 'Bingo'
--select * from #test123 

--select distinct(tp.PlayerID)/*, psc.StatusName*/  from #test123   tp
--		join PlayerStatus ps on ps.PlayerID = tp.PlayerID 
--		join PlayerStatusCode psc on  psc.PlayerStatusCodeID = ps.PlayerStatusCodeID 
--		where  tp.StatusName like '%|%'
--		and psc.StatusName in (select StatusName  from  dbo.FnRptPlayerListStatus(@StatusID))


		insert into #TempPlayer 
		select * from @TempPlayer 
		where 
		(
		StatusName in (select StatusName  from  dbo.FnRptPlayerListStatus(@StatusID))
		or PlayerID in (select distinct(tp.PlayerID)/*, psc.StatusName*/  from @TempPlayer tp
		join PlayerStatus ps on ps.PlayerID = tp.PlayerID 
		join PlayerStatusCode psc on  psc.PlayerStatusCodeID = ps.PlayerStatusCodeID 
		where  tp.StatusName like '%|%'
		and psc.StatusName in (select StatusName  from  dbo.FnRptPlayerListStatus(@StatusID)))
		)
	end
end



if (@Spend = 1 and   @SAOption = 0)
 select  
    PlayerID, FirstName, MiddleInitial, LastName, BirthDate
  , Email, Gender, Address1, Address2, City
  , [State], Country, Zip, Refundable, NonRefundable
  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
  , JoinDate, Comment, MagCardNo,   NDaysPlayed , NSessionPlayed, GamingDate, SessionNbr, [Days]   
 from  
  #TempPlayer
 where  
  Spend >= @AmountFrom AND  
  Spend <= @AmountTo  
 order by  
  LastName  
 asc  
else if (@Average = 1 and @SAOption = 0) 
begin


 select  
    PlayerID, FirstName, MiddleInitial, LastName, BirthDate
  , Email, Gender, Address1, Address2, City
  , [State], Country, Zip, Refundable, NonRefundable
  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
  , JoinDate, Comment, MagCardNo  ,   NDaysPlayed ,NSessionPlayed , GamingDate, SessionNbr, [Days]   
 from  
  #TempPlayer
 where  
  AvgSpend >= @AmountFrom AND  
  AvgSpend <= @AmountTo  
 order by  
  LastName  
 asc  
end
else

  select  
    PlayerID, FirstName, MiddleInitial, LastName, BirthDate
  , Email, Gender, Address1, Address2, City
  , [State], Country, Zip, Refundable, NonRefundable
  , LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
  , StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
  , JoinDate, Comment, MagCardNo  ,   NDaysPlayed , NSessionPlayed , GamingDate, SessionNbr, [Days]   
 from  
  #TempPlayer
 order by  
  LastName
 desc



 drop table #TempPlayer 

--END SP
--=====================================

--TEST VARIABLES
--declare
-- @OperatorID as int,  
-- @BDFrom as Datetime,      -- DE9192
-- @BDEnd as Datetime, 
-- @GenderType as nvarchar(4),
-- @Min as Money, 
-- @Max as Money,
-- @PBOptionSelected nvarchar(50),
-- @PBOptionValue money,  
-- @LVStart as Datetime, 
-- @LVEnd as Datetime, 
-- @Spend as bit, 
-- @Average as Bit, 
-- @AmountFrom as money, 
-- @AmountTo as money, 
-- @StartDate as Datetime, 
-- @EndDate as Datetime,
-- @SAOption as bit,
-- @SAOptionSelected nvarchar(50),
-- @SAOptionValue money,  
-- @StatusID as nvarchar(max),
-- @LocationType int,
-- @LocationDefinition nvarchar(max)
-- ,@IsNOfDaysPlayed bit
-- ,@IsNOfSessioPlayed bit
--,@DPDateRangeFrom datetime
--,@DPDateRangeTo datetime
--,@IsDPRange bit
--,@DPRangeFrom int--
--,@DPRangeTo  int--
--,@IsDPOption bit
--,@DPOprtionSelected nvarchar(50)
--,@DPOptionValue int
--,@IsSPRange bit
--,@SPRangeFrom int
--,@SPRangeTo  int
--,@IsSPOption bit
--,@SPOprtionSelected nvarchar(50)
--,@SPOptionValue int
--,@DaysOfWeekNSessionNbr varchar(max)
--,@IsPackageName bit
--,@PackageName varchar(500)
----as

--set
-- @OperatorID  = 1
-- set @BDFrom = '2015-07-01 00:00:00'      -- DE9192
-- set @BDEnd = '2015-08-31 00:00:00' 
-- set @GenderType = ''
-- set @Min = -1
-- set @Max = 0
-- set @PBOptionSelected = ''
-- set @PBOptionValue = 0  
-- set @LVStart = '1900-01-01 00:00:00'
-- set @LVEnd = '1900-01-01 00:00:00' 
-- set @Spend = 0 
-- set @Average = 0
-- set @AmountFrom = 0
-- set @AmountTo = 0 
-- set @StartDate = '1900-01-01 00:00:00'
-- set @EndDate = '1900-01-01 00:00:00'
-- set @SAOption  = 0
-- set @SAOptionSelected = ''
-- set @SAOptionValue = 0  
-- set @StatusID = N''
-- set @LocationType = 0
-- set @LocationDefinition = N''
-- set @IsNOfDaysPlayed = 0
-- set @IsNOfSessioPlayed = 0
--set @DPDateRangeFrom = '1900-01-01 00:00:00'
--set @DPDateRangeTo = '1900-01-01 00:00:00'
--set @IsDPRange = 0
--set @DPRangeFrom = 0
--set @DPRangeTo  = 0
--set @IsDPOption = 0
--set @DPOprtionSelected = N''
--set @DPOptionValue = 0
--set @IsSPRange = 0
--set @SPRangeFrom = 0
--set @SPRangeTo  = 0
--set @IsSPOption = 0
--set @SPOprtionSelected = N''
--set @SPOptionValue = 0
--set @DaysOfWeekNSessionNbr = ''
--set @IsPackageName = 0
--set @PackageName = ''

 --REFERNCE (deleted from original)
 --20150716
	--knc[9/3/2013]: OLD SPEND AVERAGE --> select Spend = isnull (sum(rd.Quantity * rd.PackagePrice), 0)
	-->DE11151 --,AvgSpend = isnull (sum(rd.Quantity * rd.PackagePrice) / isnull(nullif(pinfo.VisitCount, 0), 1), 0)
	--,AvgSpend = isnull (sum(rd.Quantity * rd.PackagePrice) / isnull(nullif(pnr.NoOfReceipt , 0), 1), 0)-->DE11151
	--,PlayerId = rr.PlayerId
	--from
	--RegisterReceipt rr
	--join RegisterDetail rd on rr.RegisterReceiptId = rd.RegisterReceiptId
	----> DE1151 --join PlayerInformation pinfo on rr.PlayerId = pinfo.PlayerId
	--join @PlayerNoReciept pnr on pnr.PlayerID = rr.PlayerID -->DE11151
	--where rr.SaleSuccess = 1
	----and pinfo.OperatorId = @OperatorId
	--and rr.OriginalReceiptId is null 
	--and rd.VoidedRegisterReceiptId is null
	--and (@Spend = 0 or(rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
	--and  rr.GamingDate < CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)))
	--/*DE11151->*/and (@Average  = 0 or(rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
	--and   rr.GamingDate < CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)))/*<-DE11151*/
	--knc[9/3/2013]: OLD SPEND AVERAGE --><--group by rr.PlayerId, pnr.NoOfReceipt  


	-- --DE11151 --> 
--declare @PlayerNoReciept table (NoOfReceipt int, PlayerID int)
--;with PlayerReceipt (RegisterReceipt , PlayerID)
--as
--(
--select rr.RegisterReceiptID, rr.PlayerID  
--from
--RegisterReceipt rr
--join RegisterDetail rd on rr.RegisterReceiptId = rd.RegisterReceiptId
--where rr.SaleSuccess = 1
--and rr.OriginalReceiptId is null 
--and rd.VoidedRegisterReceiptId is null
--and (@Spend = 0 or(rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
--and  rr.GamingDate < CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)))
--and (@Average  = 0 or(rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
--and   rr.GamingDate < CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)))
--and rr.PlayerID is not null
--group by rr.RegisterReceiptID , rr.PlayerID 
--)
--, PlayerNoReceipt (NoOfReceipt , PlayerID)
--as
--(
--select COUNT(RegisterReceipt), PlayerID  from PlayerReceipt group by PlayerID 
--)
--insert into @PlayerNoReciept 
--select NoOfReceipt, PlayerID  from PlayerNoReceipt order by PlayerID 
--;
----<-- DE11151 


--select TotalSpend, AverageSpend, PlayerID from dbo.fnGetSpendAveragePerPlayer(@OperatorID,'01/01/1900', getdate()),default)


	--select Spend = isnull (sum(rd.Quantity * rd.PackagePrice), 0)
	---->DE11151 --,AvgSpend = isnull (sum(rd.Quantity * rd.PackagePrice) / isnull(nullif(pinfo.VisitCount, 0), 1), 0)
	--,AvgSpend = isnull (sum(rd.Quantity * rd.PackagePrice) / isnull(nullif(pnr.NoOfReceipt , 0), 1), 0)-->DE11151
	--,PlayerId = rr.PlayerId
	--from
	--RegisterReceipt rr
	--join RegisterDetail rd on rr.RegisterReceiptId = rd.RegisterReceiptId
	----> DE1151 --join PlayerInformation pinfo on rr.PlayerId = pinfo.PlayerId
	--join @PlayerNoReciept pnr on pnr.PlayerID = rr.PlayerID -->DE11151
	--where rr.SaleSuccess = 1
	----and pinfo.OperatorId = @OperatorId
	--and rr.OriginalReceiptId is null 
	--and rd.VoidedRegisterReceiptId is null
	--and (@Spend = 0 or(rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
	--and  rr.GamingDate < CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)))
	--/*DE11151->*/and (@Average  = 0 or(rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
	--and   rr.GamingDate < CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)))/*<-DE11151*/
	--group by rr.PlayerId, pnr.NoOfReceipt  



















GO


