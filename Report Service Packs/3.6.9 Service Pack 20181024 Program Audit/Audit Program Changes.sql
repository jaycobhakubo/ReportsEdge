USE Daily

SET IDENTITY_INSERT AuditTypes ON

IF NOT EXISTS (SELECT 1 FROM AuditTypes WHERE AuditTypeID = 18)
BEGIN
    INSERT INTO AuditTypes (AuditTypeID, Name) VALUES (18, 'Program')
END

SET IDENTITY_INSERT AuditTypes OFF

/*    ==Scripting Parameters==

    Source Server Version : SQL Server 2008 R2 (10.50.2500)
    Source Database Engine Edition : Microsoft SQL Server Standard Edition
    Source Database Engine Type : Standalone SQL Server

    Target Server Version : SQL Server 2017
    Target Database Engine Edition : Microsoft SQL Server Standard Edition
    Target Database Engine Type : Standalone SQL Server
*/

USE [Daily]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE [dbo].[spDeleteProgramGamesPatterns]
GO

CREATE procedure [dbo].[spDeleteProgramGamesPatterns]
--=============================================================================
-- 2018.10.23 jkn: Adding support for auditing when a patterns are removed
--=============================================================================
	@ProgramGamesID int
as
SET NOCOUNT ON

DECLARE @ReturnValue int
    , @auditEntry nvarchar(max)
    , @operatorId int
    , @patternNames nvarchar(max)

SELECT TOP 1 @operatorId = OperatorId, @ReturnValue = 0 FROM CurrentOperator

SELECT @patternNames = COALESCE(@patternNames + ', ', '') + PatternName FROM ProgramGamesPatterns (NOLOCK) WHERE ProgramGamesID = @ProgramGamesID

SELECT @auditEntry = 'Removed the following pattern(s) '
                   + @patternNames + ' from '
                   + (SELECT TOP (1) GameName FROM ProgramGames (NOLOCK) WHERE ProgramGamesID = @ProgramGamesID)
                   + ' game number ' + CAST ((SELECT TOP (1) DisplayGameNo FROM ProgramGames (NOLOCK) WHERE ProgramGamesID = @ProgramGamesID) AS nvarchar)
                   + '.'

DELETE ProgramGamesPatterns WHERE ProgramGamesID = @ProgramGamesID

IF @@Error <> 0
BEGIN
	SELECT @ReturnValue = -70
END

IF (@auditEntry IS NOT NULL)
    exec spAddAuditLogEntry 18, NULL, NULL, @operatorId, @auditEntry

SELECT @ReturnValue

SET NOCOUNT OFF
GO

USE [Daily]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE [dbo].[spSetProgramGameData]
GO

CREATE PROCEDURE [dbo].[spSetProgramGameData]
--=============================================================================
-- US3973 Adding support for multiple game categories per game
--  Removed the GameCategory id parameter, this is being tracked in the 
--  ProgramGameCategory table now
-- US4261 Setting ball call timer per game
-- US5361 Support for bonus validation
-- 2018.10.23 jkn: Auditing changes made to a game
--=============================================================================
	@ProgramGamesID INT,
	@GameTypeID INT,
	@ProgramID INT,
	@GameSeqNo INT,
	@IsContinued BIT,
	@EliminationGame BIT,
	@GameName NVARCHAR (64),
	@DisplayGameNo INT,
	@DisplayPartNo NVARCHAR(10),
	@Color INT,
	@IsBonanza BIT = 0,
	@IsActive BIT = 1,	
	@CooldownTimer INT = NULL,
	@GameSettingsID INT = 0,
	@PayoutCategoryID INT, -- Rally US1572
	@BonusValidationEligible INT = NULL
AS
SET NOCOUNT ON
	
DECLARE @CurrentProgramID int
    , @auditEntry nvarchar(max) = ''
    , @changesMade bit = 0
    , @operatorId int = 0

SELECT TOP 1 @operatorId = OperatorId FROM CurrentOperator

if @GameSeqNo = 0
begin
	select @GameSeqNo = MAX(GameSeqNo) + 1
	from ProgramGames WITH (NOLOCK)
	where ProgramID	= @ProgramID 

	if @GameSeqNo IS NULL
		select @GameSeqNo = 1
end
	
IF @ProgramGamesID = 0
BEGIN
	EXEC spInsertProgramGameSequenceNo	@ProgramID, @GameSeqNo
	
	INSERT ProgramGames (
		GameTypeID,
		ProgramID,
		PayoutCategoryID,
		GameSeqNo,
		IsContinued,
		EliminationGame,
		GameName,
		DisplayGameNo,
		DisplayPartNo,
		Color,
		IsActive,
		IsBonanza,
		GameSettingsID,
		CooldownTimer,
		BonusValidationEligible)
	VALUES (
		@GameTypeID,
		@ProgramID,
		NULLIF(@PayoutCategoryID, 0),
		@GameSeqNo,
		@IsContinued,
		@EliminationGame,
		@GameName,
		@DisplayGameNo,
		@DisplayPartNo,
		@Color,
		@IsActive,
		@IsBonanza,
		@GameSettingsID,
		@CooldownTimer,
		@BonusValidationEligible)
			 
	SET	@ProgramGamesID = SCOPE_IDENTITY () 

    SET @auditEntry = 'A new game was added to the ' + (SELECT ISNULL(ProgramName, '') FROM Program (NOLOCK) WHERE @programId = ProgramID) + ' program with the following settings:' + char(13)
	    + '    Game type = ' + (SELECT ISNULL(GameTypeName, '') FROM GameTypes (NOLOCK) WHERE @GameTypeID = GameTypeID) + char(13)
	    + '    Game sequence number = ' + CAST (@GameSeqNo AS nvarchar) + char(13)
	    + '    Is continued = ' + CASE WHEN @IsContinued = 1 THEN 'True' ELSE 'False' END + char(13)
	    + '    Eliminination game = ' + CASE WHEN @eliminationGame = 1 THEN 'True' ELSE 'False' END + char(13)
	    + '    Game name = ' + @gameName + char(13)
	    + '    Display game number = ' + CAST (@displayGameNo AS nvarchar) + char(13)
	    + '    Display part number = ' + CAST (@displayPartNo AS nvarchar) + char(13)
	    + '    Is active = ' + CASE WHEN @isActive = 1 THEN 'True' ELSE 'False' END + char(13)
	    + '    Bonanza game = ' + CASE WHEN @isBonanza = 1 THEN 'True' ELSE 'False' END + char(13)
	    + '    Game setting = ' + (SELECT ISNULL(gsGameSettingsname, '') FROM GameSettings WHERE gsGameSettingsID = @GameSettingsID) + char(13)
	    + '    Cooldown timer = ' + CASE WHEN @CooldownTimer IS NULL THEN 'None' ELSE CAST (@CooldownTimer AS nvarchar) END + char(13)
	    + '    Bonus validation eligible = ' + CASE WHEN @bonusValidationEligible = 1 THEN 'True' ELSE 'False' END + char(13)
    SET @changesMade = 1

    IF EXISTS (SELECT 1 FROM Color WHERE Color = @color)
        SELECT @auditEntry = @auditEntry + '    Color = ' + (SELECT ISNULL(ColorName, 'Not set') FROM Color WHERE Color = @color) + char(13)

    IF EXISTS (SELECT 1 FROM PayoutCategories WHERE PayoutCategoryID = @PayoutCategoryID)
        SELECT @auditEntry = @auditEntry + '   Payout category ' + (SELECT ISNULL(PayoutCategoryName, '(Default)') FROM PayoutCategories WHERE @PayoutCategoryID = PayoutCategoryID)

END
ELSE
BEGIN
	--Get current ProgramID
	select @CurrentProgramID = ProgramID from ProgramGames (nolock)
	where ProgramGamesID = @ProgramGamesID

    DECLARE @orgProgramGamesID INT,
		    @orgGameTypeID INT,
		    @orgProgramID INT,
		    @orgGameSeqNo INT,
		    @orgIsContinued BIT,
		    @orgEliminationGame BIT,
		    @orgGameName NVARCHAR (64),
		    @orgDisplayGameNo INT,
		    @orgDisplayPartNo NVARCHAR(10),
		    @orgColor INT,
		    @orgIsBonanza BIT = 0,
		    @orgIsActive BIT = 1,	
		    @orgCooldownTimer INT = NULL,
		    @orgGameSettingsID INT = 0,
		    @orgPayoutCategoryID INT, -- Rally US1572
		    @orgBonusValidationEligible INT = NULL
		
	SELECT @orgGameTypeID =	ISNULL(GameTypeID, 0)
		, @orgProgramID =	ISNULL(ProgramID, 0)
		, @orgGameSeqNo =	ISNULL(GameSeqNo, 0)
		, @orgIsContinued = ISNULL(IsContinued, 0)
        , @orgEliminationGame   = ISNULL(EliminationGame, 0)
		, @orgGameName =	ISNULL(GameName, '')
		, @orgDisplayGameNo =	ISNULL(DisplayGameNo, 0)
		, @orgDisplayPartNo =	ISNULL(DisplayPartNo, '')
		, @orgColor =	ISNULL(Color, 0)
		, @orgIsBonanza = ISNULL(IsBonanza, 0)
		, @orgIsActive = ISNULL(IsActive, 0)
		, @orgCooldownTimer =	ISNULL(CooldownTimer, 0)
		, @orgGameSettingsID = ISNULL(GameSettingsID, 0)
		, @orgPayoutCategoryID = ISNULL(PayoutCategoryID, 0)
		, @orgBonusValidationEligible = ISNULL(BonusValidationEligible, 0)
	FROM ProgramGames (NOLOCK)
	WHERE ProgramGamesID = @ProgramGamesID

	UPDATE ProgramGames
	SET GameTypeID = @GameTypeID,
		ProgramID = @ProgramID,
		PayoutCategoryID = NULLIF(@PayoutCategoryID, 0), -- END: US1572
		GameSeqNo = @GameSeqNo,
		IsContinued = @IsContinued,
		EliminationGame = @EliminationGame,
		GameName = @GameName,
		DisplayGameNo = @DisplayGameNo,
		DisplayPartNo = @DisplayPartNo,
		Color = @Color,
		IsActive = @IsActive,
		IsBonanza = @IsBonanza,
		GameSettingsID = @GameSettingsID,
		CooldownTimer = @CooldownTimer,
		BonusValidationEligible = @BonusValidationEligible
	WHERE ProgramGamesID = @ProgramGamesID

    SET @auditEntry = 'A game in the ' + (SELECT ProgramName FROM Program WHERE ProgramId = @ProgramID) + ' program was modified:'

    SET @auditEntry = (SELECT ProgramName FROM Program (NOLOCK) WHERE ProgramId = @ProgramID)
                    + ' program game number ' + CAST(@DisplayGameNo AS nvarchar) + ' was modified' 

    IF (@orgGameTypeId != @GameTypeID)
        SELECT @auditEntry = @auditEntry + char(13)
                           + '    Game type = From '
                           + (SELECT GameTypeName FROM GameTypes (NOLOCK) WHERE @orgGameTypeID = GameTypeID) + ' to '
                           + (SELECT GameTypeName FROM GameTypes (NOLOCK) WHERE @GameTypeID = GameTypeID)
            , @changesMade = 1

    IF (@orgPayoutCategoryID != @PayoutCategoryID)
		SELECT @auditEntry = @auditEntry + char(13) 
                           + '    Payout category = From '
                           + (SELECT COALESCE (MAX(PayoutCategoryName), '(Default)') FROM PayoutCategories (NOLOCK) WHERE @orgPayoutCategoryID = PayoutCategoryID) + ' to '
                           + (SELECT COALESCE (MAX(PayoutCategoryName), '(Default)') FROM PayoutCategories WHERE @PayoutCategoryID = PayoutCategoryID)
            , @changesMade = 1

	IF (@orgGameSeqNo != @GameSeqNo)
		SELECT @auditEntry = @auditEntry + char(13)
                           + '    Game sequence number = From '
                           + CAST (@orgGameSeqNo AS nvarchar) + ' to '
                           + CAST (@GameSeqNo AS nvarchar)
            , @changesMade = 1

	IF (@orgIsContinued != @IsContinued)
		SELECT @auditEntry = @auditEntry + char(13)
                           + '    Is continued = From '
                           + (CASE WHEN CAST(@orgIsContinued AS CHAR(1)) = 1 THEN 'True' ELSE 'False' END) + ' to '
                           + (CASE WHEN CAST(@IsContinued AS CHAR(1)) = 1 THEN 'True' ELSE 'False' END)
            , @changesMade = 1

	IF (@orgEliminationGame != @EliminationGame)
		SELECT @auditEntry = @auditEntry + char(13)
                           + '    Eliminination game = From '
                           + CASE WHEN @orgEliminationGame = 1 THEN 'True' ELSE 'False' END + ' to '
                           + CASE WHEN @eliminationGame = 1 THEN 'True' ELSE 'False' END
            , @changesMade = 1

    IF (@orgGameName != @GameName)
		SELECT @auditEntry = @auditEntry + char(13)
                           + '    Game name = From '
                           + (SELECT CAST(@orgGameName AS nvarchar)) + ' to '
                           + (SELECT CAST(@gameName AS nvarchar))
            , @changesMade = 1

    IF (@orgDisplayGameNo != @DisplayGameNo)
		SELECT @auditEntry = @auditEntry + char(13)
                           + '    Display game number = From '
                           + CAST (@orgDisplayGameNo AS nvarchar) + ' to '
                           + CAST (@displayGameNo AS nvarchar)
            , @changesMade = 1

	IF (@orgDisplayPartNo != @displayPartNo)
		SELECT @auditEntry = @auditEntry + char(13)
                           + '    Display part number = From '
                           + @orgDisplayPartNo + ' to '
                           + @displayPartNo
            , @changesMade = 1

    IF (@orgColor != @color)
        SELECT @auditEntry = @auditEntry + char(13)
                           + '    Color = From '
                           + (SELECT ColorName FROM Color WHERE Color = @orgColor) + ' to '
                           + (SELECT ColorName FROM Color WHERE Color = @color)
            , @changesMade = 1

    IF (@orgIsActive != @isActive)
		SELECT @auditEntry = @auditEntry + char(13)
                           + '    Is active = From '
                           + CASE WHEN @orgIsActive = 1 THEN 'True' ELSE 'False' END + ' to '
                           + CASE WHEN @isActive = 1 THEN 'True' ELSE 'False' END
            , @changesMade = 1

    IF (@orgIsBonanza != @isBonanza)
        SELECT @auditEntry = @auditEntry + char(13)
                           + '    Bonanza = From '
                           + CASE WHEN @orgIsBonanza = 1 THEN 'True' ELSE 'False' END + ' to '
                           + CASE WHEN @isBonanza = 1 THEN 'True' ELSE 'False' END
            , @changesMade = 1

    IF (@orgGameSettingsID != @GameSettingsID)
        SELECT @auditEntry = @auditEntry + char(13)
                           + '    Game setting = From '
                           + (SELECT gsGameSettingsname FROM GameSettings WHERE gsGameSettingsID = @orgGameSettingsID) + ' to '
                           + (SELECT gsGameSettingsname FROM GameSettings WHERE gsGameSettingsID = @GameSettingsID)
            , @changesMade = 1

    IF (@orgCooldowntimer != @cooldowntimer)
        SELECT @auditEntry = @auditEntry + char(13)
                           + '    Cooldown timer = From '
                           + CAST (@orgCooldownTimer AS nvarchar) + ' to '
                           + CAST (@CooldownTimer AS nvarchar)
            , @changesMade = 1

    IF (@orgBonusValidationEligible != @bonusValidationEligible)
		SELECT @auditEntry = @auditEntry + char(13)
                           + '    Bonus validation eligible = From '
                           + CASE WHEN @orgBonusValidationEligible = 1 THEN 'True' ELSE 'False' END + ' to '
                           + CASE WHEN @bonusValidationEligible = 1 THEN 'True' ELSE 'False' END
            , @changesMade = 1

--    SELECT @auditEntry

	If @IsActive = 0 OR @CurrentProgramID <> @ProgramID
	Begin
		--Delete inactive games from GameEligibilityDefs
		--Delete records that are no longer valid due to ProgramID changes
		exec spDeleteGameEligibilityDefs @ProgramGamesID

		--adjust the gedNumGamesRequired value before deleting
		declare @Master int, @RemainingGames int, @NumGames int

		declare NumGames_Cursor CURSOR FOR
		select gdtlMasterProgamGamesID from GameEligibilityDetail (nolock)
		where gdtlReqProgramGamesID = @ProgramGamesID

		OPEN NumGames_Cursor

		FETCH NEXT FROM NumGames_Cursor INTO @Master
		WHILE @@FETCH_STATUS = 0
		BEGIN
			select @RemainingGames = COUNT(*) - 1 from GameEligibilityDetail (nolock)
			where gdtlMasterProgamGamesID = @Master

			If @RemainingGames = 0
			Begin
				exec spDeleteGameEligibilityDefs @Master
			End
			Else
			Begin
				select @NumGames = gedNumGamesRequired
				from GameEligibilityDefs (nolock)
				where gedMasterProgamGamesID = @Master

				if @RemainingGames < @NumGames
				begin
					update GameEligibilityDefs
					set gedNumGamesRequired = @RemainingGames
					where gedMasterProgamGamesID = @Master
				end

				Delete GameEligibilityDetail
				where gdtlMasterProgamGamesID = @Master
				and gdtlReqProgramGamesID = @ProgramGamesID
			End

			FETCH NEXT FROM NumGames_Cursor INTO @Master
		END
			
		CLOSE NumGames_Cursor
		DEALLOCATE NumGames_Cursor		 
	End
END

IF (@auditEntry IS NOT NULL AND @changesMade = 1)
    exec spAddAuditLogEntry 18, NULL, NULL, @operatorId, @auditEntry

Exec spRenumberProgramGames @ProgramID

SELECT ProgramGameID = @ProgramGamesID 

SET NOCOUNT OFF

RETURN
GO

/*    ==Scripting Parameters==

    Source Server Version : SQL Server 2008 R2 (10.50.2500)
    Source Database Engine Edition : Microsoft SQL Server Standard Edition
    Source Database Engine Type : Standalone SQL Server

    Target Server Version : SQL Server 2017
    Target Database Engine Edition : Microsoft SQL Server Standard Edition
    Target Database Engine Type : Standalone SQL Server
*/

USE [Daily]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE [dbo].[spSetProgramGamePatternData]
GO

CREATE PROCEDURE [dbo].[spSetProgramGamePatternData]
--=============================================================================
-- 2018.10.23 jkn: Adding support for auditing game pattern changes
--=============================================================================
	@ProgramGamesID int,
	@PatternNo int,
	@PatternName nvarchar(64),
	@CBBPatternMask int = NULL
AS
SET NOCOUNT ON

DECLARE @auditEntry nvarchar(max)
    , @operatorId int

SELECT TOP 1 @operatorId = OperatorId FROM CurrentOperator

IF EXISTS (SELECT * FROM ProgramGamesPatterns (NOLOCK)
			WHERE ProgramGamesID = @ProgramGamesID
			    AND PatternNo = @PatternNo)
BEGIN
	DECLARE @orgPatternName nvarchar(64)

    SELECT @orgPatternName = PatternName
    FROM ProgramGamesPatterns (NOLOCK)
    WHERE ProgramGamesID = @ProgramGamesID
	    AND PatternNo = @PatternNo

    IF (@orgPatternName != @PatternName)
        SELECT @auditEntry = 'A pattern name was changed from '
                           + @orgPatternName + ' to ' + @PatternName + ' for '
                           + (SELECT GameName FROM ProgramGames (NOLOCK) WHERE ProgramGamesId = @ProgramGamesID)
                           + ' game number ' + CAST ((SELECT DisplayGameNo FROM ProgramGames (NOLOCK) WHERE ProgramGamesId = @ProgramGamesID) AS nvarchar)
                           + '.'
    
    UPDATE ProgramGamesPatterns
	SET PatternName = @PatternName,
		CBBPatternMask = @CBBPatternMask
	WHERE ProgramGamesID = @ProgramGamesID
	    AND PatternNo = @PatternNo
END
ELSE
BEGIN	
	INSERT ProgramGamesPatterns (
		ProgramGamesID,
		PatternNo,
		PatternName,
		CBBPatternMask)
	VALUES (
		@ProgramGamesID,
		@PatternNo,
		@PatternName,
		@CBBPatternMask)

    SELECT @auditEntry = 'Added pattern ' + @PatternName
                       + ' (' + CAST(@PatternNo AS nvarchar) + ') to '
                       + (SELECT GameName FROM ProgramGames (NOLOCK) WHERE ProgramGamesId = @ProgramGamesID)
                       + ' game number ' + CAST((SELECT DisplayGameNo FROM ProgramGames (NOLOCK) WHERE ProgramGamesId = @ProgramGamesID) AS nvarchar)
                       + '.'
END

IF (@auditEntry IS NOT NULL)
    exec spAddAuditLogEntry 18, NULL, NULL, @operatorId, @auditEntry

SET NOCOUNT OFF

RETURN
GO

/*    ==Scripting Parameters==

    Source Server Version : SQL Server 2008 R2 (10.50.2500)
    Source Database Engine Edition : Microsoft SQL Server Standard Edition
    Source Database Engine Type : Standalone SQL Server

    Target Server Version : SQL Server 2017
    Target Database Engine Edition : Microsoft SQL Server Standard Edition
    Target Database Engine Type : Standalone SQL Server
*/

USE [Daily]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE [dbo].[spSetProgramGamesCategories]
GO

CREATE PROCEDURE [dbo].[spSetProgramGamesCategories]
--=============================================================================
-- 2018.10.23 JKN: Adding support for auditing game category changes
--=============================================================================
	@programGamesId int,
	@gameCategoryId int,
	@cleanTable bit
AS
SET NOCOUNT ON

DECLARE @auditEntry nvarchar(max)
    , @operatorId int 

SELECT @operatorId = OperatorId FROM CurrentOperator

IF @cleanTable = 1
BEGIN
    DECLARE @categories nvarchar(max)

    SELECT @categories = COALESCE(@categories + ', ', '') + gc.GCName 
    FROM GameCategory gc (NOLOCK)
        JOIN ProgramGameCategory pgc (NOLOCK) ON gc.GameCategoryID = pgc.GameCategoryId
    WHERE pgc.ProgramGamesId = @programGamesId

    SELECT @auditEntry = 'Removed the following game categories '
                       + @categories + ' from '
                       + (SELECT GameName FROM ProgramGames (NOLOCK) WHERE ProgramGamesId = @programGamesId)
                       + ' game number ' + CAST ((SELECT DisplayGameNo FROM ProgramGames (NOLOCK) WHERE ProgramGamesId = @programGamesId) AS nvarchar)
                       + '.'

    DELETE FROM ProgramGameCategory WHERE ProgramGamesId = @programGamesId

    IF (@auditEntry IS NOT NULL)
        exec spAddAuditLogEntry 18, NULL, NULL, @operatorId, @auditEntry
END

INSERT ProgramGameCategory (
	ProgramGamesId,
	GameCategoryId)
VALUES (
	@programGamesId,
	@gameCategoryId)

    SELECT @auditEntry = 'Added the following game category '
                       + (SELECT GCName FROM GameCategory (NOLOCK) WHERE GameCategoryID = @gameCategoryId)
                       + ' to ' + (SELECT GameName FROM ProgramGames (NOLOCK) WHERE ProgramGamesID = @programGamesId)
                       + ' game number ' + CAST ((SELECT DisplayGameNo FROM ProgramGames (NOLOCK) WHERE ProgramGamesId = @programGamesId) AS nvarchar)
                       + '.'

    IF (@auditEntry IS NOT NULL)
        exec spAddAuditLogEntry 18, NULL, NULL, @operatorId, @auditEntry

SET NOCOUNT OFF

RETURN
GO