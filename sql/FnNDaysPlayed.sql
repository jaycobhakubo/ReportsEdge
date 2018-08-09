USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnNDaysPlayed]    Script Date: 10/07/2013 15:47:29 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnNDaysPlayed]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnNDaysPlayed]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnNDaysPlayed]    Script Date: 10/07/2013 15:47:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE function [dbo].[FnNDaysPlayed]
		(@FromDate Datetime,
		@ToDate Datetime ,
		@IsRange bit  ,
		@FromRange int,
		@ToRange int ,
		@IsOption bit ,
		@Optionsign NVARCHAR(3),
		@Option int)		 
		returns @DaysPlayed table	 
		(PlayerID int,
		GamingDate datetime, 
		Nvisit int)
as
begin
	 if (@FromDate is null and @ToDate is null)
	 begin 
		 declare @isDate int set @IsDate = 0
	 end 	 
	set @IsRange =  isnull(@Isrange, 0)
	set @FromRange = isnull(@FromRange , 0)
	set @ToRange = isnull(@ToRange , 0)
	set @IsOption = ISNULL(@IsOption, 0)
	set @Optionsign = ISNULL(@Optionsign, '')
	set @Option = isnull(@Option , 0)
	declare @TableA table
	(PlayerID int,
	GamingDate datetime, 
    Nvisit int)
	declare @TableData table
	(PlayerID int,
	GamingDate datetime, 
    NDayPlayed int)
	;with x (PlayerID, GamingDate)
	as
	(
	select rr.PlayerID, rr.GamingDate   
	from
	RegisterReceipt rr
	join RegisterDetail rd on rr.RegisterReceiptId = rd.RegisterReceiptId
	join PlayerInformation pinfo on rr.PlayerId = pinfo.PlayerId
	join SessionPlayed sp on sp.SessionPlayedID = rd.SessionPlayedID 
	where rr.SaleSuccess = 1	
	and rd.VoidedRegisterReceiptID is null
	--and  sp.IsOverridden = 0 --Removed DE11149
	and ((rr.GamingDate >= CAST(CONVERT(varchar(12), @FromDate , 101) AS smalldatetime)
	and rr.GamingDate <= CAST(CONVERT(varchar(12), @ToDate , 101) AS smalldatetime)) or @isDate = 0)											
	group by rr.GamingDate, rr.PlayerID  )
	,y  (PlayerID, GamingDate, g) as
	(
	select PlayerID, GamingDate, ROW_NUMBER() OVER (PARTITION BY PlayerID ORDER BY gamingDate asc) as z
	from x 
	)insert into @TableA 
	select PlayerID, GamingDate, g   from y;	
	insert into @TableData 
	select A.PlayerID, A.GamingDate, A.Nvisit  NDayVisit 
	from @TableA A inner join (select PlayerID, max(Nvisit) NVist from  @TableA group by  PlayerID) B on B.PlayerID = A.PlayerID and B.NVist = A.Nvisit 
	order by PlayerID asc	 
	 delete from @TableA 
	 insert into @TableA 
	 select playerID, GamingDate, NDayPlayed   from @TableData 		
	 if (@IsRange = 1)
	begin 
		 delete from @TableData 
		 insert into @TableData 		
		 select PlayerID, GamingDate, NVisit  from @TableA where Nvisit >= @FromRange  and Nvisit <=  @ToRange 
		 delete from @TableA 
		 insert @TableA 
		 select PlayerID, GamingDate, NDayPlayed  from @TableData 
	 end
	 if (@IsOption = 1)
	 begin 
		if (@Optionsign = '>') 
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NVisit  from @TableA where Nvisit > @Option and Nvisit <> @Option 
		end 
		else
		if (@Optionsign = '>=')
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NVisit  from @TableA where Nvisit >= @Option 
		end 
		else
		if (@Optionsign = '=')
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NVisit  from @TableA where Nvisit = @Option 
		end 
		else
		if (@Optionsign = '<=')
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NVisit  from @TableA where Nvisit <= @Option 
		end 
		else 
		if (@Optionsign = '<')
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NVisit  from @TableA where Nvisit < @Option and Nvisit <> @Option
		end 

	 end
	 insert into @DaysPlayed 
	 select  PlayerID, GamingDate, NDayPlayed NDaysPlayed from @TableData 
	 return
 end


GO


