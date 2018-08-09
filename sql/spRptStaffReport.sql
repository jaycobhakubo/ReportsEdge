USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStaffReport]    Script Date: 01/13/2012 13:18:54 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptStaffReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptStaffReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStaffReport]    Script Date: 01/13/2012 13:18:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO








CREATE PROCEDURE  [dbo].[spRptStaffReport] 
-- =============================================
-- Author:		GameTech
-- Description:	NGCB - Detail report that list each staff member that has access to the system.
--
-- 2011.10.12 bjs: US1954 report creation
-- 2011.11.10 bsb: added address and contact, using it in sprptStaffReport
-- 2011.12.09 bsb: DE9619
-- =============================================
  
AS
	
begin
    
-- Temp table so Crystal can determine the shape of the output
declare @RESULTS table
(
    LastName        nvarchar(64),
    FirstName       nvarchar(64),
    address1        nvarchar(128),
    address2        nvarchar(128),
    city            nvarchar(64),
    state			nvarchar(64),
    zip				nvarchar(64),
    country         nvarchar(64),
    ContactPhone    nvarchar(16),
    StaffId         int,
    PositionId      int,
    PositionName    nvarchar(100),
    LoginNumber     int,
    IsActive        bit,
    DateCreated     datetime,
    LastLogin       datetime,
    PwdChanged      datetime,
    DisabledDate    datetime
);


insert into @RESULTS 
select 
	s.LastName
    ,s.FirstName 
	,a.Address1
	,a.Address2
	,a.City
	,a.State
	,a.Zip
	,a.Country	
	,s.HomePhone[ContactPhone]
	,s.StaffID
	, p.PositionID, p.PositionName [Position]
	, s.LoginNumber, s.IsActive
	, s.DTCreated [DateCreated]
	, s.LastLoginDate[LastLogin]
	, (
		select max(spl.DTStamp)
		from StaffPWDLog spl
		where s.StaffID = spl.StaffID
		) [PasswordChanged]
	, s.AccountLockedDate[DisabledDate]   
	from Staff s
	left join StaffPositions sp on s.StaffID = sp.StaffID
	left join Position p on sp.PositionID = p.PositionID
	left join Address a on a.AddressID = s.AddressID
	where s.StaffID > 2	
	--where s.IsActive = 1

declare @staffId int;
declare @desc varchar(1024);
declare @startIndex int;
declare @endIndex int;
declare @deActId int;
declare @DTStamp DateTime;
declare audit_cursor cursor fast_forward read_only
		for select  description,DTStamp from AuditLog
		where description like '%account deactivated%'
		order by DTStamp ;
open audit_cursor
fetch next from audit_cursor into @desc,@DTStamp;

while(@@FETCH_STATUS = 0)
begin     
	if(PATINDEX('%account deactivated%',@desc)) > 0
	begin
		set @startIndex = CHARINDEX(':',@desc) + 1;
		set @endIndex = CHARINDEX(')',@desc);
	    set @deActId = convert(int,substring(@desc,@startIndex,@endIndex-@startIndex));
	   
	    update @Results
	    set DisabledDate = @DTStamp
	    where StaffId = @deActId
	    and IsActive = 0;
	end;
	
	fetch next from audit_cursor into @desc,@DTStamp;	

end
close audit_cursor;
deallocate audit_cursor;
select * 
from @RESULTS
order by LastName, StaffID, PositionName;

end;

SET NOCOUNT OFF







GO


