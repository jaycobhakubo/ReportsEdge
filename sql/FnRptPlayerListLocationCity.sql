USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListLocationCity]    Script Date: 10/07/2013 15:49:40 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnRptPlayerListLocationCity]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnRptPlayerListLocationCity]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListLocationCity]    Script Date: 10/07/2013 15:49:40 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create function  [dbo].[FnRptPlayerListLocationCity]
-- =============================================
-- Author:			Karlo Camacho
-- Date:			7/1/2013
-- Description:		It will return a table with a list of City.
---- =============================================
(@City  as nvarchar(max))
returns @Table table
(
City varchar(200)
)
as
begin
	declare @Count int 
	declare @patindex int
	declare @Start int
	declare @Len int 
	set @Count = 0
	set @patindex = patindex('%_|_%',@City)	
	if @patindex <> 0 
	begin
		set @City  =  @City+'_|_'
	end
	if (@patindex = 0)
	begin
		insert into @Table 
		values (@City) 
	end
	while (@patindex <> 0)
	begin 
		set @Len = (select len(@City))
		set @Start = (select patindex ('%_|_%', @City)) + 1
		set @Count = @Count + 1	
		insert into @Table 
		values (rtrim(Ltrim(substring (@City, 1 , @start-2))))				
		select @City =  substring(@City ,@Start+2, @Len)
		set @patindex = patindex('%_|_%',@City)
	end
	return 
end


GO


