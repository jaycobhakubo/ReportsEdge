USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListStatus]    Script Date: 10/07/2013 15:54:16 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnRptPlayerListStatus]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnRptPlayerListStatus]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListStatus]    Script Date: 10/07/2013 15:54:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE function [dbo].[FnRptPlayerListStatus]
(
-- =============================================
-- Author:			Karlo Camacho
-- Date:			8/14/2013
-- Description:		It will return a table with a list of Status.
---- =============================================1
 @StatusName as  nvarchar(max)

)
returns @TableStatusID table
(StatusName varchar(100)
)
as
begin 
	declare @StatusX table ([status] varchar(100))
	declare @Count int
	--if (@StatusNames <> 'ALL')
	declare @PatIndex int
	set @PatIndex = PATINDEX  ('%/|\%', @StatusName)
	if (@PatIndex <> 0)
	begin
		set @StatusName = @StatusName + '/|\'
		declare @Len int
		declare @Start int
		while (@PatIndex <> 0)
		begin
			set @Len = (select LEN(@StatusName))
			set @Start = (select PATINDEX ('%/|\%', @StatusName))
			insert into @StatusX 
			select SUBSTRING(@StatusName,1, @Start-1)
			set @StatusName = SUBSTRING(@StatusName, @Start+3, @Len)
			set @PatIndex = PATINDEX('%/|\%', @StatusName)          
		end
	end 
	else if (@PatIndex = 0)
	begin 
		insert into @StatusX
		values (@StatusName)  
	end
insert into @TableStatusID 
select [status] from @StatusX 
return	
	
end	


GO


