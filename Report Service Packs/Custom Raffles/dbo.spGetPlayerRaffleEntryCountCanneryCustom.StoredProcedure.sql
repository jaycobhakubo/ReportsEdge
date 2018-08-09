USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerRaffleEntryCount]    Script Date: 08/04/2017 10:11:42 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spGetPlayerRaffleEntryCount]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spGetPlayerRaffleEntryCount]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerRaffleEntryCount]    Script Date: 08/04/2017 10:11:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spGetPlayerRaffleEntryCount] 
--=============================================================================
-- 2016.01.06 US4438 Adding support for calculating the number of entries
--  when using a player list to run the raffle
-- 2017.08.03 tmp: Configures to run custom raffles.
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
	declare	@DrawingWeekday		int
	declare @DrawingSession		int
	declare @EntryStartDate		datetime
	declare @EntryEndDate		datetime
	declare @SpendAmount		money

	-- Set the rules for the drawing
	set @DrawingDate = dbo.GetCurrentGamingDate()
	set @SpendAmount = 4
	set @DrawingWeekday = datepart(weekday, @DrawingDate)

	declare @BegDate int
	set @BegDate = (@DrawingWeekday - 1) * -1

	set @EntryStartDate = dateadd(day, @BegDate, @DrawingDate)
	set @EntryEndDate = @DrawingDate
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
	
	declare @Results table
	(
		PlayerID	int,
		FirstName	nvarchar(32),
		LastName	nvarchar(32),
		Entries		int
	)

	;with cte_PresentPlayers
	(
		PlayerID
	)
	as
		(
			select	rr.PlayerID
			from	RegisterReceipt rr
					join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
					join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
			where	rr.OperatorID = @operatorId
					and rr.PlayerID is not null
					and rr.SaleSuccess = 1
					and rr.TransactionTypeID = 1
					and rd.VoidedRegisterReceiptID is null
					and sp.GamingSession = @DrawingSession
					and rr.GamingDate = @DrawingDate
			group by rr.PlayerID
		),
		cte_Receipts
		(
			RegisterReceiptID,
			PlayerID,
			DeviceFee
		)
		as
			(
				select	rr.RegisterReceiptID,
						rr.PlayerID,
						rr.DeviceFee
				from	RegisterReceipt rr
						join cte_PresentPlayers ctePP on rr.PlayerID = ctePP.PlayerID
				where	rr.OperatorID = @operatorId
						and rr.SaleSuccess = 1
						and rr.TransactionTypeID = 1
						and rr.GamingDate >= @EntryStartDate
						and rr.GamingDate <= @EntryEndDate
			),
			cte_NumberOfEntries
			(
				PlayerID,
				RegisterReceiptID,
				Entries
			)
			as
				(
					select  cteR.PlayerID,
							cteR.RegisterReceiptID,
					--		isnull(sum(rd.PackagePrice * rd.Quantity), 0) + isnull(sum(DiscountAmount * Quantity), 0) + isnull(cteR.DeviceFee, 0), --For testing
							round(((isnull(sum(rd.PackagePrice * rd.Quantity), 0) + isnull(sum(isnull(DiscountAmount, 0) * Quantity), 0) + isnull(cteR.DeviceFee, 0)) / nullif(@SpendAmount, 0)), 0, 1)
					from	RegisterDetail rd 
							join cte_Receipts cteR on rd.RegisterReceiptID = cteR.RegisterReceiptID
					where	rd.VoidedRegisterReceiptID is null
							and rd.SessionPlayedID <= @SessionPlayedID
					group by cteR.RegisterReceiptID, cteR.PlayerID, cteR.DeviceFee
				)
				,cte_OnePerSession
				(
					SessionPlayedID,
					PlayerID,
					Entries
				)
				as
					(
						select  distinct(rd.SessionPlayedID),
								cteNE.PlayerID,
								1
						from	cte_NumberOfEntries cteNE
								join RegisterDetail rd on cteNE.RegisterReceiptID = rd.RegisterReceiptID
						where	Entries > 0
						group by rd.SessionPlayedID,
								cteNE.PlayerID
					)
					insert into @Results
					(
						PlayerID,
						Entries
					)
						select  cteOne.PlayerID,
								cteOne.Entries
						from	cte_OnePerSession cteOne
						where	Entries > 0;					

	delete from PlayerRaffle;		

	declare @PlayerID int, @Entries int;

	while (select max(Entries) from @Results) > 0
	begin 

		declare enterPlayers_cursor cursor fast_forward for
		select	PlayerID,
				Entries
		from	@Results r
		where	Entries > 0;
		
		open enterPlayers_cursor;

		fetch next from enterPlayers_cursor
		into @PlayerID, @Entries
			
		while @@FETCH_STATUS = 0
		begin	
			insert into PlayerRaffle (OperatorId, PlayerID, AccountNumber, EntryTime)
			select 1, @PlayerID, 0, getdate()
			
		fetch next from enterPlayers_cursor
			into @PlayerID, @Entries

		end	

		close enterPlayers_cursor
		deallocate enterPlayers_cursor
		
		update @Results
			set Entries = Entries - 1;

	end;

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

