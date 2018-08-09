USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListDaysOfWeekNSessionNbr]    Script Date: 10/07/2013 15:48:11 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnRptPlayerListDaysOfWeekNSessionNbr]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnRptPlayerListDaysOfWeekNSessionNbr]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListDaysOfWeekNSessionNbr]    Script Date: 10/07/2013 15:48:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create function [dbo].[FnRptPlayerListDaysOfWeekNSessionNbr]
-- =============================================
-- Author:			Karlo Camacho
-- Date:			7/1/2013
-- Description:		It will return a table that will consist the Gaming Session and days they played per player.
---- =============================================
(
@FromDate Datetime,
@ToDate Datetime,
@DaysNSession varchar (100)	
)
returns @TableData table
(
PlayerID int,
GamingDate datetime,
GamingSession int,
[Days] varchar(50)
)
as 
begin 
	declare @Count int set @Count = 0
	declare @PatIndex1 int set @PatIndex1 = patindex('%(%',@DaysNSession) + 1
	declare @PatIndex2 int set @PatIndex2 = patindex('%)%',@DaysNSession) - @patindex1
	declare @SessionNbr varchar(100) select @SessionNbr = substring (@DaysNSession, @PatIndex1, @PatIndex2)
	declare @Days varchar(10) select @Days = ltrim(rtrim(substring (@DaysNSession,1,@patindex1-3 )))
	select @Days = 
	case 
	when @Days = 'Mon' then 'Monday' 
	when @Days = 'Tue' Then 'Tuesday'
	when @Days = 'Wed' then 'Wednesday'
	when @Days = 'Thu' then 'Thursday'
	when @Days = 'Fri' then 'Friday'
	when @Days = 'Sat' then 'Saturday'
	when @Days = 'Sun' then 'Sunday'
	end
	if (@SessionNbr = '')
	begin 
		set @SessionNbr = 'ALL'
	end
	declare @TempTable table 
	(
	PlayerID int,
	GamingDate datetime,
	GamingSession int,
	[Days] varchar(50)
	)
	insert into @TempTable
	select rr.PlayerID, sp.GamingDate, /*sp.SessionPlayedID*/ GamingSession, datename(WEEKDAY , sp.GamingDate) [Days]    from 
	RegisterReceipt rr
	join RegisterDetail rd on rr.RegisterReceiptId = rd.RegisterReceiptId
	join PlayerInformation pinfo on rr.PlayerId = pinfo.PlayerId
	join SessionPlayed sp on sp.SessionPlayedID = rd.SessionPlayedID 
	where rr.SaleSuccess = 1	
	and ((sp.GamingDate >= CAST(CONVERT(varchar(12), @FromDate , 101) AS smalldatetime)
	and sp.GamingDate <= CAST(CONVERT(varchar(12), @ToDate , 101) AS smalldatetime)) /*or @isDate = 0*/)		
	and  sp.IsOverridden = 0 
	group by sp.GamingDate, rr.PlayerID , sp.SessionPlayedID, sp.GamingSession 
	order by PlayerID asc
	insert into @TableData 
	select PlayerID, GamingDate, GamingSession, [Days]  from @TempTable 
	where 
	GamingSession in (select SessionNbr from  FnRptPlayerListSessionNbr(@SessionNbr))
	and [Days] = @Days 
	return
end


GO


