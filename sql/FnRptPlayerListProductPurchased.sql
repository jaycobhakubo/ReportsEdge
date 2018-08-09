USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListProductPurchased]    Script Date: 10/07/2013 15:52:58 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnRptPlayerListProductPurchased]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnRptPlayerListProductPurchased]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnRptPlayerListProductPurchased]    Script Date: 10/07/2013 15:52:58 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE function [dbo].[FnRptPlayerListProductPurchased]
-- =============================================
-- Author:			Karlo Camacho
-- Date:			7/6/2013
-- Description:		It will return a table with a list of playerID that bought a particular product.
---- =============================================
 (@PackageName varchar(500),
 @FromDate datetime,
 @ToDate datetime 
 /*@IsDate bit ,
 @IspackageName bit*/)
 returns @PlayerList table
 (
 PlayerID int
 )
 as 
 begin
	declare @IsDate bit
	if (@FromDate is null and @ToDate is null)
	begin
		set @IsDate = 0
	end
	declare @ProductName Table (ProductName varchar(100))
	declare @Count int
	if (@PackageName <> 'ALL')
	begin 
		declare @PatIndex int 
		set @PatIndex = PATINDEX ('%/|\%', @PackageName)	
		if (@PatIndex <> 0)
		begin
			set @PackageName = @PackageName + '/|\'
			declare @Len int
			declare @Start int
			while (@PatIndex <> 0)
			begin
				set @Len = (select len(@PackageName))
				set @Start = (select PATINDEX('%/|\%', @PackageName))
				insert into @ProductName 
				select substring (@PackageName,1,@Start-1)
				set @PackageName = SUBSTRING(@PackageName, @Start+3, @Len)
				set @PatIndex = PATINDEX('%/|\%', @PackageName) 
			end
		end
		else if (@PatIndex = 0)
		begin 
			insert into @ProductName (ProductName)
			values (@PackageName)  
		end
	end
	else
	begin
		insert into @ProductName (ProductName)
		select PackageName  from Package where IsActive = 1 order by PackageName asc
	end
	;with Player as
	(
	select PackageName, PlayerID, GamingDate  from RegisterDetail rd 
	join RegisterReceipt rr on rr.RegisterReceiptID = rd.RegisterReceiptID
	where PlayerID is not null 
	and PackageName is not null
	and PackageName in (select ProductName  from @ProductName)
	and ((rr.GamingDate >= CAST(CONVERT(varchar(12), @FromDate , 101) AS smalldatetime)
	and rr.GamingDate <= CAST(CONVERT(varchar(12), @ToDate , 101) AS smalldatetime)) or @IsDate = 0) )	
	insert into @PlayerList 
	select distinct PlayerID from Player order by PlayerID asc ;
	return
end


GO


