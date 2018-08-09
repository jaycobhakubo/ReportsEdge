USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListLocationZipCode]    Script Date: 10/07/2013 15:51:59 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnRptPlayerListLocationZipCode]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnRptPlayerListLocationZipCode]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListLocationZipCode]    Script Date: 10/07/2013 15:51:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE function  [dbo].[FnRptPlayerListLocationZipCode]
-- =============================================
-- Author:			Karlo Camacho
-- Date:			7/1/2013
-- Description:		It will return a table with a list of ZipCode.
---- =============================================
(@ZipCode  as nvarchar(max))
returns @Table table
(
ZipCode Nvarchar(32)
)
as
begin
	declare @Count int 
	declare @patindex int
	declare @Start int
	declare @Len int 
	set @Count = 0
	set @patindex = patindex('%_|_%',@ZipCode)	
	if @patindex <> 0 
		begin
		set @ZipCode  =  @ZipCode+'_|_'
		end
	if (@patindex = 0)
	begin
		insert into @Table 
		values (@ZipCode) 
	end
	while (@patindex <> 0)
	begin 
		set @Len = (select len(@ZipCode))
		set @Start = (select patindex ('%_|_%', @ZipCode)) + 1
		set @Count = @Count + 1	
		insert into @Table 
		values (rtrim(Ltrim(substring (@ZipCode, 1 , @start-2))))				
		select @ZipCode =  substring(@ZipCode ,@Start+2, @Len)
		set @patindex = patindex('%_|_%',@ZipCode)
	end
	return 
end


GO


