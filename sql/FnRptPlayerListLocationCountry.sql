USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListLocationCountry]    Script Date: 10/07/2013 15:50:22 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnRptPlayerListLocationCountry]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnRptPlayerListLocationCountry]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListLocationCountry]    Script Date: 10/07/2013 15:50:22 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE function  [dbo].[FnRptPlayerListLocationCountry]
-- =============================================
-- Author:			Karlo Camacho
-- Date:			7/1/2013
-- Description:		It will return a table with a list of Country.
---- =============================================
(@Country  as nvarchar(max))
returns @Table table
(
Country varchar(200)
)
as
begin
	declare @Count int 
	declare @patindex int
	declare @Start int
	declare @Len int 
	set @Count = 0
	set @patindex = patindex('%_|_%',@Country)	
	if @patindex <> 0 
		begin
		set @Country =  @Country+'_|_'
		end
	if (@patindex = 0)
	begin
		insert into @Table 
		values (@Country) 
	end
	while (@patindex <> 0)
	begin 
		set @Len = (select len(@Country))
		set @Start = (select patindex ('%_|_%', @Country)) + 1
		set @Count = @Count + 1	
		insert into @Table 
		values (rtrim(Ltrim(substring (@Country, 1 , @start-2))))				
		select @Country =  substring(@Country ,@Start+2, @Len)
		set @patindex = patindex('%_|_%',@Country)
	end
	return 
end


GO


