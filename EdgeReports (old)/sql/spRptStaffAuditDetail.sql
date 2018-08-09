USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptStaffAuditDetail]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptStaffAuditDetail]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptStaffAuditDetail] 
-- =============================================
-- Author:		GameTech
-- Description:	NGCB - Detail report that list each staff member that has access to the system.
--
-- 2011.10.12 bjs: US1954 report creation
-- =============================================
AS
	
begin
    
-- Temp table so Crystal can determine the shape of the output
declare @RESULTS table
(
    StaffName       nvarchar(66),
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
       s.LastName + ', ' + s.FirstName, s.StaffID
    , p.PositionID, p.PositionName [Position]
    , s.LoginNumber, s.IsActive
    , s.HireDate [DateCreated]
    , (
    select max(al.DTStamp)
    from AuditLog al 
    where  
    s.StaffID = al.StaffID 
    and AuditTypeID = 5 
    and al.Description like ('%Login%')
    ) [LastLogin]
    , (
    select max(spl.DTStamp)
    from StaffPWDLog spl
    where s.StaffID = spl.StaffID
    ) [PasswordChanged]
    , s.AccountLockedDate [DisabledDate]   
from Staff s
left join StaffPositions sp on s.StaffID = sp.StaffID
left join Position p on sp.PositionID = p.PositionID
where s.IsActive = 1


select * 
from @RESULTS
order by StaffName, StaffID, PositionName;

end;

SET NOCOUNT OFF
GO
