USE [Daily]
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'spRptPlayerList2') AND type IN (N'P', N'PC')) 
DROP PROCEDURE [dbo].[spRptPlayerList2]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE proc [dbo].[spRptPlayerList2] 
--======================
-- Author : Fortunet
-- Description: Derived from spRptPlayerList.
--				: Get the number of player in a Player List Definition. 
-- 20170804 tmp: DE13690 Does not return players when set to use spend and spend options.
--               Spend options was checking for players before the Player Spend and Average Spend 
--               was calculated. Moved to calculate the spend to happen before checking the spend options.
--               Also optimized the spend calculation.
-- 2019.05.20 tmp: Removed adding a day to @EndDate parameter 
--======================
 @OperatorID as int,   
 @BDFrom as Datetime,     
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
,@TotalNumberOfPlayers int output
as
--==============
--Save for testing
--==============
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


--set
-- @OperatorID  = 1
-- set @BDFrom = '1900-01-01 00:00:00'      -- DE9192
-- set @BDEnd = '1900-01-01 00:00:00' 
-- set @GenderType = 'M'
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

set @LVEnd = Dateadd(Day,1,@LVEnd)  
--set @EndDate = Dateadd(Day,1,@EndDate) 20190520 tmp: Do not need to add a day

   if (@PBisOption = 1)
   begin 
   set @PointsBalance = 0
   end
   
set @BDFrom = dateadd(year, datediff(year, @BDFrom, '1/1/2000'), @BDFrom)
set @BDEnd = dateadd(year, datediff(year, @BDEnd, '1/1/2000'), @BDEnd)

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


insert into #TempPlayer
( FirstName, MiddleInitial, LastName, PlayerID, Birthdate
, Email, Gender, Address1, Address2, City
, [State], Country, Zip, Refundable, NonRefundable
, LastVisitDate, PointsBalance, PIN.OperatorID, Visits
, GovIssuedIdNum, PlayerIdent, Phone, JoinDate
, Comment, MagCardNo )  
 select
	p.FirstName, p.MiddleInitial, p.LastName, p.PlayerID, p.BirthDate
	,p.EMail, p.Gender, a.Address1, a.Address2, a.City
	,a.State, a.Country, a.Zip, isnull(cb.Refundable, 0), isnull(cb.NonRefundable, 0)
	,pInfo.LastVisitDate, isnull(pb.pbPointsBalance, 0), @OperatorID , pInfo.VisitCount
    , p.GovIssuedIDNum, p.PlayerIdent, p.Phone, pInfo.FirstVisitDate
	,pInfo.Comment, pmc.MagneticCardNo
	from Player p
	join [Address] a on p.AddressID = a.AddressID
	join PlayerInformation pInfo on p.PlayerId = pInfo.PlayerId
	join CreditBalances cb on pInfo.CreditBalancesId = cb.CreditBalancesId
	join PointBalances pb on pInfo.PointBalancesId = pb.pbPointBalancesId
	left join PlayerMagCards pmc on p.PlayerId = pmc.PlayerId
where --(@Birthday = 0 or datepart(dayofyear, tpl.Birthdate)+1 between datepart(dayofyear, @BDFrom) and datepart(dayofyear, @BDEnd))--Issue with leap year
(@Birthday = 0 or (select dbo.FNGetMonthDayEquivalentToInt(p.Birthdate)) between (select dbo.FNGetMonthDayEquivalentToInt(@BDFrom)) and (select dbo.FNGetMonthDayEquivalentToInt(@BDEnd)))
and (@Gender = 0 or p.Gender = @GenderType)    
and (@PointsBalance = 0 or pb.pbPointsBalance between @Min and @Max)
and (@LastVisit = 0 or pInfo.LastVisitDate >= cast(convert(varchar(12), @LVStart, 101) as smalldatetime)   
and pInfo.LastVisitDate < cast(convert(varchar(12), @LVEnd, 101) as smalldatetime))
and (@Country = '' or a.Country in (select Country from FnRptPlayerListLocationCountry(@Country)))
and (@CityName = '' or a.City in (select City from FnRptPlayerListLocationCity(@CityName)))
and (@ZipCode = '' or a.Zip in (select ZipCode from  FnRptPlayerListLocationZipCode(@ZipCode)))
and (@State = '' or a.State in (select [State] from FnRptPlayerListLocationState(@State)))

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
		--set @EndDate = DATEDIFF(day, 1, @EndDate) 20190520 tmp: Do not need to add a day

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
	
	
if (@Status = 1)
begin

	declare @statusName nvarchar(1000), @curPlayerId int

	declare StatusCursor cursor for select PlayerID from #TempPlayer 
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

delete from @TempPlayer 


-- DE13690 Start replaced cursor and function with cte
if (@Average = 1 or @Spend =1)
begin
	
	;with cte_PlayerSpend
	(
		PlayerID,
		RegisterReceiptId,
		Spend
	)
	as
		(
			select  rr.PlayerID,
					rr.RegisterReceiptID,
					case rr.TransactionTypeID 
						when 1 then ((sum(isnull(rd.PackagePrice, 0) * isnull(rd.Quantity, 0))) + (sum(isnull(rd.DiscountAmount, 0) * isnull(rd.Quantity, 0))) + (sum(isnull(rd.SalesTaxAmt, 0) * isnull(rd.Quantity, 0))))
						when 3 then ((sum(isnull(rd.PackagePrice, 0) * isnull(rd.Quantity, 0))) + (sum(isnull(DiscountAmount, 0) * isnull(Quantity, 0))) + (sum(isnull(rd.SalesTaxAmt, 0) * isnull(rd.Quantity, 0)))) * -1
					end 
			from	RegisterReceipt rr
					join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
			where	rr.OperatorID = @OperatorID
					and rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
					and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
					and rr.TransactionTypeID in (1, 3)
					and rr.SaleSuccess = 1
					and rr.PlayerID is not null
					and rd.VoidedRegisterReceiptID is null
			group by rr.RegisterReceiptID, rr.PlayerID, rr.TransactionTypeID
		)
		,	cte_PlayerSpendDeviceFees
			(
				PlayerID,
				RegisterReceiptID,
				Spend
			)
			as
				(
					select  ctePS.PlayerID,
							ctePS.RegisterReceiptID,
							isnull(ctePS.Spend, 0) + isnull(rr.DeviceFee, 0)
					from	RegisterReceipt rr
							join cte_PlayerSpend ctePS on rr.RegisterReceiptID = ctePS.RegisterReceiptId
				)
				, cte_PlayerTotalAvgSpend
				(
					PlayerID,
					AverageSpend,
					Spend
				)
				as 
					(
						select	PlayerID,
								(sum(ctePSDF.Spend) / count(RegisterReceiptID)),
								sum(ctePSDF.spend)
						from cte_PlayerSpendDeviceFees ctePSDF
						group by PlayerID
					)
				
				update	#TempPlayer
				set #TempPlayer.Spend = cteTAS.Spend, #TempPlayer.AvgSpend = cteTAS.AverageSpend
				from	cte_PlayerTotalAvgSpend cteTAS
						join #TempPlayer on cteTAS.PlayerId = #TempPlayer.PlayerID
	   
   --declare @PlayerID2 int 
   
   --declare SpendAverageCursor cursor for
   --select PlayerID from   #TempPlayer
   --open SpendAverageCursor 
   --fetch next from SpendAverageCursor into @PlayerID2
   
   --declare @TotalSpend money, @AverageSpend money
   
   --while @@FETCH_STATUS = 0
   --begin
   
   --	  select @TotalSpend = TotalSpend, @AverageSpend = AverageSpend  from dbo.fnGetSpendAveragePerPlayer(@OperatorID,@StartDate, datediff(Day,1,@EndDate),@PlayerID2)
   --	  update #TempPlayer
   --	  set spend = @TotalSpend,
   --	  AvgSpend = @AverageSpend
   --	  where PlayerID = @PlayerID2
   		
   --   fetch next from SpendAverageCursor into @PlayerID2
   --end
   
   --close SpendAverageCursor 
   --deallocate SpendAverageCursor
   
-- DE13690 end

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
		
		delete from #TempPlayer
		where dateadd(dd, 0, datediff(dd, 0, LastVisitDate)) < dateadd(dd, 0, datediff(dd, 0, @StartDate))

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


if (@Spend = 1 and   @SAOption = 0)
set  @TotalNumberOfPlayers = (select  count(*) as NPlayers
  --  PlayerID, FirstName, MiddleInitial, LastName, BirthDate
  --, Email, Gender, Address1, Address2, City
  --, [State], Country, Zip, Refundable, NonRefundable
  --, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
  --, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
  --, JoinDate, Comment, MagCardNo,   NDaysPlayed , NSessionPlayed, GamingDate, SessionNbr, [Days]   
 from  
  #TempPlayer
 where  
  Spend >= @AmountFrom AND  
  Spend <= @AmountTo  
 --order by  
 -- LastName  
 --asc 
 ) 
else if (@Average = 1 and @SAOption = 0) 
begin

set @TotalNumberOfPlayers = (select  count(*) as NPlayers
  --  PlayerID, FirstName, MiddleInitial, LastName, BirthDate
  --, Email, Gender, Address1, Address2, City
  --, [State], Country, Zip, Refundable, NonRefundable
  --, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
  --, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
  --, JoinDate, Comment, MagCardNo  ,   NDaysPlayed ,NSessionPlayed , GamingDate, SessionNbr, [Days]   
 from  
  #TempPlayer
 where  
  AvgSpend >= @AmountFrom AND  
  AvgSpend <= @AmountTo  
 --order by  
 -- LastName  
 --asc
  ) 
end
else
set @TotalNumberOfPlayers = 
  (select  count(*) as NPlayers
  --  PlayerID, FirstName, MiddleInitial, LastName, BirthDate
  --, Email, Gender, Address1, Address2, City
  --, [State], Country, Zip, Refundable, NonRefundable
  --, LastVisitDate, PointsBalance, Spend, AvgSpend, Visits
  --, StatusName, OperatorID, GovIssuedIdNum, PlayerIdent, Phone
  --, JoinDate, Comment, MagCardNo  ,   NDaysPlayed , NSessionPlayed , GamingDate, SessionNbr, [Days]   
 from  
  #TempPlayer
 --order by  
 -- LastName
 --desc
 )

drop table #TempPlayer




GO


