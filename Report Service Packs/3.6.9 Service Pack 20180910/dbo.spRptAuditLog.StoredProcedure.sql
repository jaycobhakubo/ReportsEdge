USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptAuditLog]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptAuditLog]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spRptAuditLog] 
-- =============================================
-- Author:		Oscar Sessions
-- Create date: 1/05/2012
-- Description:	Retrieves the settings changed data for SettingsChangedReport
-- 2016.10.05 tmp: US4944 - Add the staff name
-- 2016.10.05 tmp: US4954 - Add the machine description
-- 2018.01.18 tmp: Added logging for some blower events. On/Off, check for duplicate ball calls, manual calls, auto passed and manual passed. 
--                 and connection issues.
-- 2018.02.08 tmp: US5516 Removed session start, end, reopen events and removed duplicate ball calls since the staff id, machine id information
--					is not tracked.
-- 2018.09.10 tmp: Do not return Login/Logout when AuditTypeID = 5 Staff Failed Logins. 
-- =============================================
-- Add the parameters for the stored procedure here
     @StartDate     datetime 
	,@EndDate       datetime
	,@OperatorID    int 
    ,@AuditTypeID   int
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;

    select @StartDate = (convert (nvarchar, @StartDate, 101) + ' 00:00:00')
	    , @EndDate = (convert (nvarchar, @EndDate, 101) + ' 23:59:59');
	    
	declare @AuditName nvarchar(32)
	set @AuditName = (select Name from AuditTypes where AuditTypeID = @AuditTypeID)
	

    --select al.DTStamp
	   -- , isnull (m.ClientIdentifier, 0) as MACAddress
	   -- , isnull (al.MachineID, 0) as MachineID
	   -- , al.Description as Reason
    --    , s.StaffID as StaffID       
    --from AuditLog al
	   -- left join Machine m (nolock) on al.MachineID = m.MachineID
    --    left join Staff s (nolock) on al.StaffID = s.StaffID
    --where al.DTSTamp between @StartDate and @EndDate
	   -- and (@AuditTypeID = 0 or al.AuditTypeID = @AuditTypeID)
    --    and (al.OperatorID = 0 or al.OperatorID = @OperatorID) 
    --order by al.DTStamp;
    
Declare @Results table
(
	DTStamp		datetime,
	MACAddress  nvarchar(64),
	MachineID	int,
	MachineDesc	nvarchar(64),	-- US4954
	Reason		nvarchar(max),
	StaffID		int,
	StaffName	nvarchar(max)	-- US4944
) 
insert @Results
(
	DTStamp,
	MACAddress,
	MachineID,
	MachineDesc,	-- US4954
	Reason,
	StaffID,
	StaffName		-- US4944
)  
	select	al.DTStamp
			, isnull (m.ClientIdentifier, 0) as MACAddress
			, isnull (al.MachineID, 0) as MachineID
			, m.MachineDescription	-- US4954
			, al.Description as Reason
			, s.StaffID as StaffID
			, s.FirstName + ' ' + s.LastName as StaffName	-- US4944
	from	AuditLog al left join Machine m (nolock) on al.MachineID = m.MachineID
						left join Staff s (nolock) on al.StaffID = s.StaffID
	where	al.DTSTamp between @StartDate and @EndDate
			and (@AuditTypeID = 0 
					or (	
							@AuditTypeID = 5
							and (	
									al.AuditTypeID = @AuditTypeID
									and al.Description <> 'Login'
									and al.Description <> 'Logout'
								)
						)
					or (
							@AuditTypeID <> 5
							and al.AuditTypeID = @AuditTypeID
						)
				)
			and (al.OperatorID = 0 or al.OperatorID = @OperatorID) 
	order by al.DTStamp;

/*	
insert into @Results
(
	DTStamp,
	MACAddress,
	MachineID,
	MachineDesc,	-- US4954
	Reason
)
	select	sp.SessionStartDT
			, isnull (m.ClientIdentifier, 0) as MACAddress
			, isnull (sp.MachineID, 0) as MachineID
			, m.MachineDescription	-- US4954
			, 'Session opened for Gaming Date ' + convert(varchar(10), sp.GamingDate, 101) + ' Session ' + convert(varchar(10), sp.GamingSession, 1)
	from	SessionPlayed sp left join Machine m on sp.MachineID = m.MachineID
	where	sp.OperatorID = @OperatorID
			and	( sp.SessionStartDT between @StartDate and @EndDate or
			      sp.GamingDate between @StartDate and @EndDate
			     )
			and @AuditTypeID = 0
			and sp.SessionStartDT is not null
			and sp.SessionEndDT is not null
			
insert into @Results
(
	DTStamp,
	MACAddress,
	MachineID,
	MachineDesc,	-- US4954
	Reason
)
	select	sp.SessionEndDT
			, isnull (m.ClientIdentifier, 0) as MACAddress
			, isnull (sp.MachineID, 0) as MachineID
			, m.MachineDescription	-- US4954
			, 'Session closed for Gaming Date ' + convert(varchar(10), sp.GamingDate, 101) + ' Session ' + convert(varchar(10), sp.GamingSession, 1)
	from	SessionPlayed sp left join Machine m on sp.MachineID = m.MachineID	-- US4954
	where	sp.OperatorID = @OperatorID
			and	( sp.SessionEndDT between @StartDate and @EndDate or
				  sp.GamingDate between @StartDate and @EndDate
				 )
			and @AuditTypeID = 0
			and sp.SessionStartDT is not null
			and sp.SessionEndDT is not null
			
insert into @Results
(
	DTStamp,
	Reason,
	StaffID,
	StaffName	-- US4944
)
	select	spl.splReopenDate,
			'Session reopened for Gaming Date ' + convert(varchar(10), sp.GamingDate, 101) + ' Session ' + convert(varchar(10), sp.GamingSession, 1),
			spl.splStaffID,
			s.FirstName + ' ' + s.LastName	-- US4944
	from	SessionPlayedLog spl join SessionPlayed sp on spl.splSessionPlayedID = sp.SessionPlayedID
								 left join Staff s on spl.splStaffID = s.StaffID	-- US4944
	where	sp.OperatorID = @OperatorID
			and	( spl.splReopenDate between @StartDate and @EndDate or
				  sp.GamingDate between @StartDate and @EndDate
				 )
			and @AuditTypeID = 0
*/
			
insert into @Results
(
	DTStamp,
	MACAddress,
	MachineID,
	MachineDesc,	
	Reason,
	StaffID,
	StaffName		
)  
	select	bl.DTStamp,
			isnull(m.ClientIdentifier, 0),
			bl.MachineID,
			m.MachineDescription,
			case when ble.BlowerLogEventID = 2 then 'Ball number ' + convert(varchar(10), bl.BallNumber , 1) + ' was called manually.'
				 when ble.BlowerLogEventID = 4 then 'Ball number ' + convert(varchar(10), bl.BallNumber , 1) + ' was passed automatically.'
				 when ble.BlowerLogEventID = 6 then 'Ball number ' + convert(varchar(10), bl.BallNumber , 1) + ' was passed manually.'
				 else ble.EventName
			end,
			bl.StaffID,
			s.FirstName + ' ' + s.LastName as StaffName
	from	BlowerLog bl
			join BlowerLogEvents ble on bl.BlowerLogEventID = ble.BlowerLogEventID
			join Machine m on bl.MachineID = m.MachineID
			left join Staff s on bl.StaffID = s.StaffID
	where	bl.BlowerLogEventID in (2, 4, 5, 6, 7, 28,29)
			and bl.DTSTamp between @StartDate and @EndDate
			and (@AuditTypeID = 0 or @AuditName = 'Blower')
			and (bl.OperatorID = 0 or bl.OperatorID = @OperatorID) 
	order by bl.DTStamp;

/*
with DuplicateBallCalls (SessionGamesPlayedID, BallNumber, BallCount)
as
(
	select	sgp.SessionGamesPlayedId,
			bl.BallNumber,
			count(bl.BallNumber)
	from	BlowerLog bl
			join Machine m on bl.MachineID = m.MachineID
			join SessionGamesPlayed sgp on bl.SessionGamesPlayedId = sgp.SessionGamesPlayedID
			join SessionPlayed sp on sgp.SessionGamesPlayedID = sp.SessionPlayedID
	where	BlowerLogEventID in (2, 4)
			and bl.DTSTamp between @StartDate and @EndDate
			and (@AuditTypeID = 0 or @AuditName = 'Blower')
			and (bl.OperatorID = 0 or bl.OperatorID = @OperatorID) 
	group by sgp.SessionGamesPlayedId, bl.BallNumber
	having count(bl.BallNumber) > 1
)
insert into @Results
(	
	Reason	
)  
	select	'On ' + convert(varchar(10), sp.GamingDate, 101) + ' in session ' + convert(varchar(10), sp.GamingSession, 1) + ' Game ' + convert(varchar(10), sgp.DisplayGameNo, 1) + ' Ball number ' + convert(varchar(10), dbc.BallNumber, 1) + ' was called ' + convert(varchar(10), dbc.BallCount, 1) + ' times.'
	from	DuplicateBallCalls dbc
			join SessionGamesPlayed sgp on dbc.SessionGamesPlayedId = sgp.SessionGamesPlayedID
			join SessionPlayed sp on sgp.SessionGamesPlayedID = sp.SessionPlayedID;
*/

select	*
from	@Results
order by DTStamp

set nocount off;

end;

GO

