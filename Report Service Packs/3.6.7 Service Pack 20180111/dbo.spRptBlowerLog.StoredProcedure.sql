USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBlowerLog]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBlowerLog]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE procedure [dbo].[spRptBlowerLog] 
-- =============================================
-- Author:		Travis Pollock
-- Create date: 12/30/2016
-- Description:	US4813 Retrieves the balls pulled by the blower.
-- 20170131 tmp: DE13432 - @OperatorID parameter was misspelled. 
-- =============================================
-- Add the parameters for the stored procedure here
		@OperatorID int,
		@StartDate	datetime,
		@EndDate	datetime,
		@Session	int
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;
	
	declare @Results table
	(
		GamingDate		datetime,
		GamingSession	int,
		GamePlayedId	int,
		GameNumber		int,
		PartNumber		int,
		GameName		nvarchar(64),
		SequenceNumber	int,
		DTStamp			datetime,
		BallNumber		int,
		BonanzaPreCall	bit,
		BonusPreCall	bit,
		IsIgnored		bit
	);
	
	declare @Sequential nvarchar(32);

	set @Sequential =	( select	SettingValue
						  from		GlobalSettings
						  where		GlobalSettingID = 323);
	if @Sequential = 'True'
	begin
		insert into @Results
		(
			GamingDate,
			GamingSession,
			GamePlayedId,
			GameNumber,
			PartNumber,
			GameName,
			SequenceNumber,
			DTStamp,
			BallNumber,
			BonanzaPreCall,
			BonusPreCall,
			IsIgnored
		)
		select	s.GamingDate,
				s.GamingSession,
				sp.SessionGamesPlayedID,
				sp.DisplayGameNo,
				sp.DisplayPartNo,
				sp.GameName,
				sp.GameSeqNo,
				b.DTStamp,
				b.BallNumber,
				b.IsBonanzaPreCall,
				b.IsBonusPreCall,
				b.IsIgnoredCall
		from	BlowerLog b
				left join SessionGamesPlayed sp on b.SessionGamesPlayedID = sp.SessionGamesPlayedID
				left join SessionPlayed s on sp.SessionPlayedID = s.SessionPlayedID				
			--	left join BlowerLog b on sp.SessionGamesPlayedID = b.SessionGamesPlayedID
		where	--s.OperatorID = @OperatorID 
				 CAST(CONVERT(varchar(12), b.DTStamp, 101) AS smalldatetime) >= @StartDate
				and CAST(CONVERT(varchar(12), b.DTStamp, 101) AS smalldatetime) <= @EndDate
				--and	s.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
				--and s.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
				and ( @Session = 0 
					  or s.GamingSession = 1
					);
	end
	else
	begin
		insert into @Results
		(
			GamingDate,
			GamingSession,
			GamePlayedId,
			GameNumber,
			PartNumber,
			GameName,
			SequenceNumber,
			DTStamp,
			BallNumber,
			BonanzaPreCall,
			BonusPreCall,
			IsIgnored
		)
		select	s.GamingDate,
				s.GamingSession,
				sp.SessionGamesPlayedID,
				sp.DisplayGameNo,
				sp.DisplayPartNo,
				sp.GameName,
				sp.GameSeqNo,
				b.DTStamp,
				b.BallNumber,
				b.IsBonanzaPreCall,
				b.IsBonusPreCall,
				b.IsIgnoredCall
		from	BlowerLog b
				left join SessionGamesPlayed sp on b.SessionGamesPlayedID = sp.SessionGamesPlayedID
				left join SessionPlayed s on sp.SessionPlayedID = s.SessionPlayedID
		--		left join BlowerLog b on sp.SessionGamesPlayedID = b.SessionGamesPlayedID
		where	--s.OperatorID = @OperatorID
				CAST(CONVERT(varchar(12), b.DTStamp, 101) AS smalldatetime) >= @StartDate
				and CAST(CONVERT(varchar(12), b.DTStamp, 101) AS smalldatetime) <= @EndDate
			--	and	s.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
			--	and s.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
				and ( @Session = 0 
					  or s.GamingSession = 1
					);
	end;			
			    
	select	*
	from	@Results
	order by DTStamp;

	set nocount off;

end;





GO

