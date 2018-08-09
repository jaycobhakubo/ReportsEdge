USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListLocationState]    Script Date: 10/07/2013 15:51:13 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnRptPlayerListLocationState]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnRptPlayerListLocationState]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListLocationState]    Script Date: 10/07/2013 15:51:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE function  [dbo].[FnRptPlayerListLocationState]
-- =============================================
-- Author:			Karlo Camacho
-- Date:			7/1/2013
-- Description:		It will return a table with a list of State.
---- =============================================
(@State  as nvarchar(max))
returns @Table table
(
State varchar(200)
)
as
begin
	declare @Count int 
	declare @patindex int
	declare @Start int
	declare @Len int 
	set @Count = 0
	set @patindex = patindex('%_|_%',@State)	
	if @patindex <> 0 
		begin
		set @State  =  @State+'_|_'
		end
	if (@patindex = 0)
	begin
		insert into @Table 
		values (@State) 
	end
	while (@patindex <> 0)
	begin 
		set @Len = (select len(@State))
		set @Start = (select patindex ('%_|_%', @State)) + 1
		set @Count = @Count + 1	
		insert into @Table 
		values (rtrim(Ltrim(substring (@State, 1 , @start-2))))			
		select @State =  substring(@State ,@Start+2, @Len)
		set @patindex = patindex('%_|_%',@State)
	end
	return 
end


GO


