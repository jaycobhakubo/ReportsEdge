USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListSessionNbr]    Script Date: 10/07/2013 15:53:36 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnRptPlayerListSessionNbr]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnRptPlayerListSessionNbr]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListSessionNbr]    Script Date: 10/07/2013 15:53:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create function  [dbo].[FnRptPlayerListSessionNbr]
-- =============================================
-- Author:			Karlo Camacho
-- Date:			7/1/2013
-- Description:		It will return a table with a list of session number.
---- =============================================
(@SessionNbr varchar(100))
returns @Table table 
(SessionNbr int)
as 
begin 
	declare @Count int
	declare @PatIndex int
	set @Count = 0
	set @PatIndex = PATINDEX('%:%', @SessionNbr)
	if (@PatIndex <> 0)-- if more than one sessionnbr
	begin
		set @SessionNbr = @SessionNbr + ':' --adding "-" to the @sessionbr
		declare @Len int 
		declare @Start int
		declare @Test varchar(100)
		while (@PatIndex <> 0)
		begin 
			set @Len = (select len(@SessionNbr))
			set @Start = (select PATINDEX('%:%', @SessionNbr)) 
			set @Count = @Count + 1
			insert into @Table 
			values(  cast (SUBSTRING(@SessionNbr,1,@Start-1) as int))
			select @SessionNbr = SUBSTRING(@SessionNbr, @Start + 1, @Len)
			set @PatIndex = PATINDEX('%:%',@SessionNbr)  
		end
	end 
	else if (@PatIndex = 0) --if only singlke session nbr
	begin 
		insert into @Table 
		values (cast(@SessionNbr as int ))
	end
return
end 


GO


