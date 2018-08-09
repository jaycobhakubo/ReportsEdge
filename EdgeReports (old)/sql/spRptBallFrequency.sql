USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBallFrequency]    Script Date: 11/08/2011 13:45:39 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBallFrequency]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBallFrequency]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBallFrequency]    Script Date: 11/08/2011 13:45:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[spRptBallFrequency] 
-- =============================================
-- Author:		Jaysen Nolte
-- Create date: 10/13/2011
-- Description:	Retrieves the ball call frequency counts
-- 11/08/11  :BSB DE9627
-- =============================================
-- Add the parameters for the stored procedure here
     @StartDate     datetime 
	,@EndDate       datetime
	,@OperatorID    int 
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;

    declare @Results table
    (
        OpID           int,
        Number         int,
        TimesDrawn     int,
        PercentofDraws decimal(9,4),
        PercentofGames decimal(9,4),
        TotalGames     int
    );

    -- 2nd table required to insert missing balls
    declare @Results2 table
    (
        OpID           int,
        Number         int,
        TimesDrawn     int,
        PercentofDraws decimal(9,4),
        PercentofGames decimal(9,4),
        TotalGames     int
    );

    declare @GameCount int
        , @TotalBallCount int

    set @StartDate = (convert (nvarchar, @StartDate, 101) + ' 00:00:00');
    set @EndDate   = (convert (nvarchar, @EndDate, 101) + ' 23:59:59');

    select @GameCount = count (sgp.SessionGamesPlayedID)
    from SessionPlayed sp
        join SessionGamesPlayed sgp on sp.SessionPlayedID = sgp.SessionPlayedID
    where sp.GamingDate between @StartDate and @EndDate
        and (sp.OperatorID = @OperatorID or @OperatorID = 0)
        and (sgp.DTStart is not null or sgp.IsBonanza = 1)
        and sp.IsOverridden = 0
        and sgp.IsContinued = 0;


    insert into @Results
    select
          @OperatorID 
        , BallCalled
        , count (BallCalled)
        , 0
        , 0
        , @GameCount
    from GameBallsCalled gbc
        join SessionGamesPlayed sgp on gbc.SessionGamesPlayedID = sgp.SessionGamesPlayedID
        join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
    where CalledTime between @StartDate and @EndDate
        and CallStatus = 1
        and WildID = 0
        and IsActive = 1
        and (sp.OperatorID = @OperatorID or @OperatorID = 0)
    group by BallCalled
    order by BallCalled

    select @TotalBallCount = sum (TimesDrawn) from @Results

    update @Results
    set PercentofGames = 100 * (ISNULL ((cast (TimesDrawn as decimal) / cast (nullif (TotalGames, 0) as decimal)), 0))
        , PercentofDraws = 100 * (ISNULL ((cast (TimesDrawn as decimal) / cast (nullif(@TotalBallCount, 0) as decimal)), 0))

    -- debug
    -- select * from @Results order by Number

    -- Now insert all balls not called during the specified time frame
    declare @ball int, @missingCount int;
    declare @OpID int;
    declare @Number int;
    declare @TimesDrawn     int;
    declare @PercentofDraws decimal(9,4);
    declare @PercentofGames decimal(9,4);
    declare @TotalGames int;
    set @ball = 1;
    set @missingCount = 0;

    declare BALLS cursor local fast_forward for
    select OpID, Number, TimesDrawn, PercentofDraws, PercentofGames, TotalGames from @Results order by Number;

    open BALLS;
    fetch next from BALLS into @OpID, @Number, @TimesDrawn, @PercentofDraws, @PercentofGames, @TotalGames;

    -- debug
    --print @ball;

    while(@@FETCH_STATUS = 0)
    begin
        --print 'Number: ' +  + convert(nvarchar(5), @Number);
        if (@ball <> @Number)
        begin
            set @missingCount = @Number - @ball;
            while (@missingCount > 0)
            begin
                insert into @Results2 (OpID, Number, TimesDrawn, PercentofDraws, PercentofGames, TotalGames) 
                values (@OpID, @ball, 0, 0, 0, @GameCount);
                --print 'New: ' + convert(nvarchar(5), @ball) + ' ' + 'Missing: ' + convert(nvarchar(5), @missingCount);
                set @ball = @ball + 1;
                set @missingCount = @missingCount - 1;
            end;
        end

        begin
            print 'Existing:'  + convert(nvarchar(5), @ball);
            insert into @Results2 (OpID, Number, TimesDrawn, PercentofDraws, PercentofGames, TotalGames) 
            values (@OpID, @Number, @TimesDrawn, @PercentofDraws, @PercentofGames, @TotalGames);
            set @ball = @ball + 1;
        end
        
        fetch next from BALLS into @OpID, @Number, @TimesDrawn, @PercentofDraws, @PercentofGames, @TotalGames;
        --print @ball;
    end;

    -- Cleanup
    close BALLS;
    deallocate BALLS;

    -- Return our resultset ordered
    select * from @Results2 order by Number;

end;



GO


