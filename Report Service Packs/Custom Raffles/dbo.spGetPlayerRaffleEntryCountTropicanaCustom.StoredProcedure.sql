USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spGetPlayerRaffleEntryCount]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spGetPlayerRaffleEntryCount]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spGetPlayerRaffleEntryCount] 
--=============================================================================
-- 2016.01.06 US4438 Adding support for calculating the number of entries
--  when using a player list to run the raffle
-- 2017.08.03 tmp: Configures to run custom raffles.
-- 2017.09.13 tmp: Custom version for Tropicana. Get the players that played for
--                 the current session.
--=============================================================================
	@operatorId int
	, @definitionId int = 0
as
set nocount on

--- Enable custom raffles 0 = Off 1 = On
declare @UseCustom	bit
set @UseCustom = 1 

if @UseCustom = 1
begin  

	--- Define the rules for the drawing
	declare	@DrawingDate		datetime
	declare @DrawingSession		int

	-- Set the rules for the drawing
	set @DrawingDate = dbo.GetCurrentGamingDate()
	set @DrawingSession = (	select	GamingSession
							from	SessionPlayed 
							where	GamingDate = @DrawingDate
									and IsLocked = 0
									and IsOverridden = 0
									and ProgramTypeID = 1
									and SessionStartDT IS NOT NULL
									and SessionEndDT IS NULL
							)

	if @DrawingSession is null
	set @DrawingSession = 1
end

if (@definitionId = 0 and @UseCustom = 1)
begin

	-- Get the session played id for the session the drawing
	-- will be ran in.

	declare @SessionPlayedID int

	set @SessionPlayedID = (	select	SessionPlayedID 
								from	SessionPlayed 
								where	GamingDate = @DrawingDate 
										and GamingSession = @DrawingSession
										and IsOverridden = 0
							);
							
	delete from PlayerRaffle;	
	
	insert into PlayerRaffle
	(
		PlayerID,
		OperatorId,
		AccountNumber,
		EntryTime
	)
	select	distinct(rr.PlayerID),
			rr.OperatorID,
			0,
			getdate()
	from	RegisterReceipt rr
			join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
			join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
	where	rr.OperatorID = @operatorId
			and rr.PlayerID is not null
			and rr.SaleSuccess = 1
			and rr.TransactionTypeID = 1
			and rd.VoidedRegisterReceiptID is null
			and sp.GamingSession = @DrawingSession
			and rr.GamingDate = @DrawingDate;

    select	EntryCount = COUNT(pr.PlayerID)
    from	PlayerRaffle pr with (nolock)
			join Player p with (nolock) on pr.PlayerID = p.PlayerID
    where	pr.OperatorId = @OperatorId
end
else if (@definitionId = 0 and @UseCustom = 0)
begin
    select	EntryCount = COUNT(pr.PlayerID)
    from	PlayerRaffle pr with (nolock)
			join Player p with (nolock) on pr.PlayerID = p.PlayerID
    where	pr.OperatorId = @OperatorId
end
else
begin
    declare @playerCount int
    exec spRaffle_GetNumberOfPlayerPerList @operatorId, @definitionId, @playerCount output
    
    select @playerCount as EntryCount
end




GO

