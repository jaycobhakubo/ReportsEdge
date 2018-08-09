USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptAccrualSettingChanges]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptAccrualSettingChanges]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRptAccrualSettingChanges] 
-- =============================================
-- Author:		Jaysen Nolte
-- Create date: 10/5/2011
-- Description:	Retrieves the accrual setting changes
--              that have happened over a period of time
-- =============================================
-- Add the parameters for the stored procedure here
     @OperatorId int
    ,@StartDate datetime
    ,@EndDate   datetime
as
begin
	-- set nocount on added to prevent extra result sets from
	-- interfering with select statements.
	set nocount on;

    select @StartDate = (convert (nvarchar, @StartDate, 101) + ' 00:00:00')
	    , @EndDate = (convert (nvarchar, @EndDate, 101) + ' 23:59:59');

    select al.DTStamp
        , isnull (s.LastName, '') as LastName
        , isnull (s.FirstName, '') as FirstName
        , isnull (al.MachineId, 0) as MachineId
        , isnull (al.Description, '') as [Description]
    from AuditLog (nolock) as al
        left join staff (nolock) as s on al.StaffId = s.StaffId
    where al.DTSTamp between @StartDate and @EndDate
        and al.AuditTypeId = 6
        and al.OperatorId = @OperatorId
    order by al.DTStamp;

    set nocount off;
end;
