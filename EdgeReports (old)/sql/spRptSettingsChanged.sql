USE [Daily]
GO
/****** Object:  StoredProcedure [dbo].[spRptSettingsChanged]    Script Date: 11/11/2011 15:13:28 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSettingsChanged]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSettingsChanged]

/****** Object:  StoredProcedure [dbo].[spRptSettingsChanged]    Script Date: 11/11/2011 15:14:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spRptSettingsChanged] 
-- =============================================
-- Author:		Oscar Sessions
-- Create date: 11/11/2011
-- Description:	Retrieves the settings changed data for SettingsChangedReport
-- =============================================
-- Add the parameters for the stored procedure here
     @StartDate     datetime 
	,@EndDate       datetime
	,@OperatorID    int 
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;

    select @StartDate = (convert (nvarchar, @StartDate, 101) + ' 00:00:00')
	    , @EndDate = (convert (nvarchar, @EndDate, 101) + ' 23:59:59');

    select al.DTStamp
	    , isnull (m.ClientIdentifier, 0) as MACAddress
	    , isnull (al.MachineID, 0) as MachineID
	    , al.Description as Reason
        , s.LoginNumber as LoginNumber       
    from AuditLog al
	    left join Machine m (nolock) on al.MachineID = m.MachineID
        left join Staff s (nolock) on al.StaffID = s.StaffID
    where al.DTSTamp between @StartDate and @EndDate
	    and al.AuditTypeID = 7
    order by al.DTStamp;

    set nocount off;
end;