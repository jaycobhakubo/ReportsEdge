USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionHistory]    Script Date: 07/11/2014 16:49:28 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionHistory]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionHistory]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionHistory]    Script Date: 07/11/2014 16:49:28 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO








-- =============================================
CREATE procedure [dbo].[spRptSessionHistory]
(
-- =============================================
-- Author:		    Barjinder Bal
-- Description:	    Track each time an override is sent
--
-- 2011.11.15 bsb:  US1838 New Report
-- 2011.11.29 BSB:  US1952 added staffid
-- 2012.01.05 SA :  DE9771 maintained SessionIDAfter History
-- 2013.08.09 tmp:  US2716 added charity information
-- 2014.07.11 tmp:	US3551 add date time stamp if a session was reopened
-- =============================================
	@OperatorID as int,	
    @StartDate as datetime,
    @EndDate as datetime
	
)	 
as
begin

	set nocount on;	
    set @StartDate = (convert (nvarchar, @StartDate, 101) + ' 00:00:00');
    set @EndDate   = (convert (nvarchar, @EndDate, 101) + ' 23:59:59');

	declare @Results table
	(
		OperatorID          int,
		SessionID           int,    
		Operator            varchar(100),
		GamingDate          datetime,
		GamingSession       int,
		DTCreated           datetime,
		SessionStartTime    datetime,
		SessionEndTime      datetime,
		IsOverride          bit,
		StaffID             int,
		SessionIDAfter      int,
		charityName			Nvarchar(255),
		charityLicNum		Nvarchar(64),
		charityTaxID		Nvarchar(20),
		charityID			Int,
		ReopenDate			datetime,		--US3551
		OrgSessionEndTime	datetime		--US3551
	    
	);
	insert into @Results

	select
		sp.OperatorID,
		sp.SessionPlayedID,
		o.OperatorName,
		sp.GamingDate,
		sp.GamingSession,
		sp.DTCreated,
		sp.SessionStartDT,
		sp.SessionEndDT,
		sp.IsOverridden,
		null,
		null,
		c.Name,
		c.LicenseNumber,
		c.TaxPayerId,
		sp.CharityId,
		spl.splReopenDate,					--US3551
		spl.splOrigSessionEndDT				--US3551
	from SessionPlayed sp
	join Operator o on o.OperatorID = sp.OperatorID
	left join Charity c on sp.CharityId = c.CharityId
	left join SessionPlayedLog spl on sp.SessionPlayedID = spl.splSessionPlayedID	--US3551
	where sp.OperatorID = @OperatorID
	and GamingDate between @StartDate and @EndDate;
	
	declare @Overrides table
	(
		OperatorID          int, 
		DateCreated         datetime,
		SessionIDPrior      int,
		SessionIDAfter      int,    
		GamingDate          datetime,
		SessionStartTime    datetime,
		SessionEndTime      datetime

	    
	); 
	declare @ssID int,
        @gDate Datetime,
        @oID   int,
        @gSession int,
        @dtCreated datetime;
	declare override_cursor cursor for 
	select OperatorID,DTCreated, SessionID,GamingDate , GamingSession
	from  @Results
	where IsOverride = 1
	order by SessionID;
	
	OPEN override_cursor;

	FETCH next from override_cursor
	into  @oID,@dtCreated, @ssID, @gDate, @gSession;
	while @@FETCH_STATUS = 0
	BEGIN
		insert into @Overrides
		select  OperatorID,@dtCreated,@ssID
		,(select Top 1 SessionPlayedID from SessionPlayed where DTCreated > @dtCreated and GamingSession=@gSession and OperatorID=@oID)
		,GamingDate, SessionStartDT,SessionEndDT
		from    SessionPlayed 
		where   GamingSession = @gSession
			and IsOverridden = 0
			and OperatorID = @oID
			and GamingDate = (select GamingDate from SessionPlayed where SessionPlayedID = @ssID);
	FETCH next from override_cursor
	into  @oID,@dtCreated, @ssID, @gDate, @gSession;
	END;
	close override_cursor;
	deallocate override_cursor;    
 
    update @Results
    Set SessionIDAfter =  o.SessionIDAfter 
		from @Results r 		
		inner join @Overrides o on o.SessionIDPrior = r.SessionID
	update @Results
	Set StaffID = spl.splStaffID
	from @Results r
	inner join SessionPlayedLog spl on spl.splSessionPlayedID = r.SessionID
	
	select *  from @Results order by GamingDate;

end;

set nocount off;


















GO

