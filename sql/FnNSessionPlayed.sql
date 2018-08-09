USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnNSessionPlayed]    Script Date: 10/07/2013 15:47:43 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FnNSessionPlayed]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FnNSessionPlayed]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FnNSessionPlayed]    Script Date: 10/07/2013 15:47:43 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE function [dbo].[FnNSessionPlayed]
-- =============================================
-- Author:			Karlo Camacho
-- Date:			7/1/2013
-- Description:		It will determine the number of session played per player.
---- =============================================
		(
		@FromDate Datetime,
		@ToDate Datetime ,
		@IsRange bit  ,
		@FromRange int,
		@ToRange int ,
		@IsOption bit ,
		@Optionsign NVARCHAR(3),
		@Option int)
		returns @SessionPlayed table
		(PlayerID int,
		GamingDate datetime, 
		NSessionPlayed int)
as
begin
	if (@FromDate is null and @ToDate is null)
	begin 
		declare @isDate int set @isDate = 0
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
    NSessionPlayed int)
	declare @TableData table
	(PlayerID int,
	GamingDate datetime, 
    NSessionPlayed int)	
	;with x (PlayerID, GamingDate)
	as
	(
	select rr.PlayerID, sp.GamingDate--, sp.SessionPlayedID    
	from
	RegisterReceipt rr
	join RegisterDetail rd on rr.RegisterReceiptId = rd.RegisterReceiptId
	join PlayerInformation pinfo on rr.PlayerId = pinfo.PlayerId
	join SessionPlayed sp on sp.SessionPlayedID = rd.SessionPlayedID 
	where rr.SaleSuccess = 1	
	and rd.VoidedRegisterReceiptID is null
	and ((sp.GamingDate >= CAST(CONVERT(varchar(12), @FromDate , 101) AS smalldatetime)
	and sp.GamingDate <= CAST(CONVERT(varchar(12), @ToDate , 101) AS smalldatetime)) or @isDate = 0)		
	--and  sp.IsOverridden = 0 --Removed DE11149 
	group by sp.GamingDate, rr.PlayerID , sp.SessionPlayedID)
	,y (PlayerID, GamingDate, NSessionPlayed)
	as
	(
	select PlayerID, GamingDate,   ROW_NUMBER() OVER (PARTITION BY PlayerID ORDER BY gamingDate asc) as z
	from x 
	)
	insert into @TableA 
	select PlayerID, GamingDate,NSessionPlayed    from y;
	insert into @TableData 
	select A.PlayerID, A.GamingDate, A. NSessionPlayed   NSessionPlayed 
	from @TableA A inner join (select PlayerID, max(NSessionPlayed)  NSessionPlayed from  @TableA group by  PlayerID) B on B.PlayerID = A.PlayerID and B. NSessionPlayed = A. NSessionPlayed 
	order by PlayerID asc	 
	 delete from @TableA 
	 insert into @TableA 
	 select playerID, GamingDate,  NSessionPlayed   from @TableData 
	 if (@IsRange = 1)
	 begin 
		 delete from @TableData 
		 insert into @TableData 		
		 select PlayerID, GamingDate, NSessionPlayed  from @TableA where NSessionPlayed >= @FromRange  and NSessionPlayed <=  @ToRange 
		 delete from @TableA 
		 insert @TableA 
		 select PlayerID, GamingDate, NSessionPlayed  from @TableData 
	 end
	 if (@IsOption = 1)
	 begin 
		if (@Optionsign = '>') 
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NSessionPlayed  from @TableA where NSessionPlayed > @Option and NSessionPlayed <> @Option 
		end 
		else
		if (@Optionsign = '>=')
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NSessionPlayed  from @TableA where NSessionPlayed >= @Option 
		end 
		else
		if (@Optionsign = '=')
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NSessionPlayed  from @TableA where NSessionPlayed = @Option 
		end 
		else
		if (@Optionsign = '<=')
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NSessionPlayed  from @TableA where NSessionPlayed <= @Option 
		end 
		else 
		if (@Optionsign = '<')
		begin
		 	 delete from @TableData 
			 insert into @TableData 		
			 select PlayerID, GamingDate, NSessionPlayed  from @TableA where NSessionPlayed < @Option and NSessionPlayed <> @Option
		end 
	 end
	 insert into @SessionPlayed  
	 select  PlayerID, GamingDate, NSessionPlayed  from @TableData 
	 return
 end



GO


