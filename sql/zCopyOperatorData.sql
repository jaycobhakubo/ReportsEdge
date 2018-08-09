USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[zCopyOperatorData]    Script Date: 07/22/2013 15:14:24 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[zCopyOperatorData]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[zCopyOperatorData]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[zCopyOperatorData]    Script Date: 07/22/2013 15:14:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE procedure [dbo].[zCopyOperatorData]
-- =============================================
-- Description:	Copy data in several tables from 
-- one operator to another. Presupposes "from" and
-- "to" operators already exist.
--
-- 2011.07.11 bjs: Added Edge 3.4 tables, 
--                 transaction and error handling
-- 2013.07.22 tmp: Removed SecurityAccess and SecuritySettings tables
--				   because they no longer exist in the database
-- =============================================
	@FromOperatorID int,
	@ToOperatorID int
as
SET NOCOUNT ON

-- Parameter validation
declare @id int;
select @id = OperatorID from Operator where OperatorID = @FromOperatorID;
if( @id is not null)
begin
    print 'Original Operator ID: ' + convert(nvarchar(5), @FromOperatorID);
end; 
else
begin
    print 'Original Operator ID (' + convert(nvarchar(5), @FromOperatorID) + ') does NOT exist.';
	print 'No information copied.';
    return;
end;   
set @id = -1;
select @id = OperatorID from Operator where OperatorID = @ToOperatorID;
if( @id >= 0)
begin
    print 'New Operator ID: ' + convert(nvarchar(5), @ToOperatorID);
end; 
else
begin
    print 'New Operator ID (' + convert(nvarchar(5), @ToOperatorID) + ') does NOT exist.';
	print 'No information copied.';
    return;
end;   


-- Error Handling: rollback if any errors occur
begin try

    -- Encapsulate work w/in a transaction.  Rollback if anything bad happens!
    begin tran CopyOperatorTransaction;
    
    --turn off constraints
    ALTER TABLE AccessLog NOCHECK CONSTRAINT ALL;
    ALTER TABLE Address NOCHECK CONSTRAINT ALL;
    ALTER TABLE BadCheck NOCHECK CONSTRAINT ALL;
    ALTER TABLE BadCheckPayment NOCHECK CONSTRAINT ALL;
    ALTER TABLE BadCheckStatus NOCHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardBonusDefs NOCHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardHeader NOCHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardSales NOCHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardStartNumber NOCHECK CONSTRAINT ALL;
    ALTER TABLE BonusEndTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE BonusIcons NOCHECK CONSTRAINT ALL;
    ALTER TABLE BonusIconSelect NOCHECK CONSTRAINT ALL;
    ALTER TABLE BonusItemTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE BonusTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE BSM NOCHECK CONSTRAINT ALL;
    ALTER TABLE ButtonGraphic NOCHECK CONSTRAINT ALL;
    ALTER TABLE CardCuts NOCHECK CONSTRAINT ALL;
    ALTER TABLE CardLevel NOCHECK CONSTRAINT ALL;
    ALTER TABLE CardMedia NOCHECK CONSTRAINT ALL;
    ALTER TABLE CardStartsTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE CardStatus NOCHECK CONSTRAINT ALL;
    ALTER TABLE CardStatusOverride NOCHECK CONSTRAINT ALL;
    ALTER TABLE CardType NOCHECK CONSTRAINT ALL;
    ALTER TABLE CashMethod NOCHECK CONSTRAINT ALL;
    ALTER TABLE CBBFavorites NOCHECK CONSTRAINT ALL;
    ALTER TABLE Channel NOCHECK CONSTRAINT ALL;
    ALTER TABLE Color NOCHECK CONSTRAINT ALL;
    ALTER TABLE Company NOCHECK CONSTRAINT ALL;
    ALTER TABLE CompAutoAwardRules NOCHECK CONSTRAINT ALL;
    ALTER TABLE CompAward NOCHECK CONSTRAINT ALL;
    ALTER TABLE CompCriteriaAwardHistory NOCHECK CONSTRAINT ALL;
    ALTER TABLE CompLimit NOCHECK CONSTRAINT ALL;
    ALTER TABLE CompRafflePrizes NOCHECK CONSTRAINT ALL;
    ALTER TABLE CompRaffles NOCHECK CONSTRAINT ALL;
    ALTER TABLE CompRaffleType NOCHECK CONSTRAINT ALL;
    ALTER TABLE Comps NOCHECK CONSTRAINT ALL;
    ALTER TABLE ConfigPhoto NOCHECK CONSTRAINT ALL;
    ALTER TABLE Configuration NOCHECK CONSTRAINT ALL;
    ALTER TABLE CreditBalances NOCHECK CONSTRAINT ALL;
    ALTER TABLE CreditBalancesTransLog NOCHECK CONSTRAINT ALL;
    ALTER TABLE CreditGroupAccounts NOCHECK CONSTRAINT ALL;
    ALTER TABLE CreditGroupPlayers NOCHECK CONSTRAINT ALL;
    ALTER TABLE CurrencyType NOCHECK CONSTRAINT ALL;
    ALTER TABLE CustomDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE CustomerMailer NOCHECK CONSTRAINT ALL;
    ALTER TABLE CustomField NOCHECK CONSTRAINT ALL;
    ALTER TABLE CustomFieldType NOCHECK CONSTRAINT ALL;
    ALTER TABLE CustomFieldValue NOCHECK CONSTRAINT ALL;
    ALTER TABLE DailyGamesLink NOCHECK CONSTRAINT ALL;
    ALTER TABLE DailyMenuButtons NOCHECK CONSTRAINT ALL;
    ALTER TABLE DailyPackageProduct NOCHECK CONSTRAINT ALL;
    ALTER TABLE DailyStaffMenu NOCHECK CONSTRAINT ALL;
    ALTER TABLE Device NOCHECK CONSTRAINT ALL;
    ALTER TABLE DeviceHardwareAttributes NOCHECK CONSTRAINT ALL;
    ALTER TABLE DeviceModules NOCHECK CONSTRAINT ALL;
    ALTER TABLE DeviceMotif NOCHECK CONSTRAINT ALL;
    ALTER TABLE DeviceProductFeatures NOCHECK CONSTRAINT ALL;
    ALTER TABLE Discounts NOCHECK CONSTRAINT ALL;
    ALTER TABLE DiscountTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE Event NOCHECK CONSTRAINT ALL;
    ALTER TABLE EventObject NOCHECK CONSTRAINT ALL;
    ALTER TABLE FeaturePermissions NOCHECK CONSTRAINT ALL;
    ALTER TABLE Functions NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameBallsCalled NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameCategory NOCHECK CONSTRAINT ALL;
    --ALTER TABLE GameCurrency NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameDenomDefs NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameDenomsAvail NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameEligibilityDefs NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameEligibilityDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistory NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistoryDtl NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistoryWinLine NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistoryWinLineBonus NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistoryWinLineDtl NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameLevel NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameLockTrans NOCHECK CONSTRAINT ALL;
    --ALTER TABLE GameMedia NOCHECK CONSTRAINT ALL;
    ALTER TABLE GamePlayHistoryLineDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameSet NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameSetGame NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameSettings NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameTrans NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameTransDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE GameTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE GiftCard NOCHECK CONSTRAINT ALL;
    ALTER TABLE GlobalSettings NOCHECK CONSTRAINT ALL;
    ALTER TABLE Hall NOCHECK CONSTRAINT ALL;
    ALTER TABLE HardwareAttributes NOCHECK CONSTRAINT ALL;
    ALTER TABLE HotBallSale NOCHECK CONSTRAINT ALL;
    ALTER TABLE JackpotDetails NOCHECK CONSTRAINT ALL;
    ALTER TABLE JStampDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE JStampHeader NOCHECK CONSTRAINT ALL;
    ALTER TABLE KenoBonusDef NOCHECK CONSTRAINT ALL;
    ALTER TABLE KenoBonusDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE KenoBonusHeader NOCHECK CONSTRAINT ALL;
    ALTER TABLE KenoBonusPoolSubset NOCHECK CONSTRAINT ALL;
    ALTER TABLE KenoGameDef NOCHECK CONSTRAINT ALL;
    ALTER TABLE KenoPayOptions NOCHECK CONSTRAINT ALL;
    ALTER TABLE KenoPayTable NOCHECK CONSTRAINT ALL;
    ALTER TABLE Layout NOCHECK CONSTRAINT ALL;
    ALTER TABLE LBCardBonusNums NOCHECK CONSTRAINT ALL;
    ALTER TABLE LBCardSale NOCHECK CONSTRAINT ALL;
    ALTER TABLE LBCardSaleDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE LBCardWinHold NOCHECK CONSTRAINT ALL;
    ALTER TABLE LBGame NOCHECK CONSTRAINT ALL;
    ALTER TABLE LBGameBall NOCHECK CONSTRAINT ALL;
    ALTER TABLE LBGameBallHold NOCHECK CONSTRAINT ALL;
    ALTER TABLE LBGameBonusNos NOCHECK CONSTRAINT ALL;
    ALTER TABLE LBGameBonusNosHold NOCHECK CONSTRAINT ALL;
    ALTER TABLE Location NOCHECK CONSTRAINT ALL;
    ALTER TABLE LoginConnectionType NOCHECK CONSTRAINT ALL;
    ALTER TABLE LogMain NOCHECK CONSTRAINT ALL;
    ALTER TABLE Machine NOCHECK CONSTRAINT ALL;
    ALTER TABLE MachineSettings NOCHECK CONSTRAINT ALL;
    ALTER TABLE MachineStatus NOCHECK CONSTRAINT ALL;
    ALTER TABLE MagCardReaderMode NOCHECK CONSTRAINT ALL;
    ALTER TABLE Manufacturer NOCHECK CONSTRAINT ALL;
    ALTER TABLE MenuType NOCHECK CONSTRAINT ALL;
    ALTER TABLE ModuleFeatures NOCHECK CONSTRAINT ALL;
    ALTER TABLE ModuleMachinePersistentData NOCHECK CONSTRAINT ALL;
    ALTER TABLE ModulePermissions NOCHECK CONSTRAINT ALL;
    ALTER TABLE ModulePersistentData NOCHECK CONSTRAINT ALL;
    ALTER TABLE Modules NOCHECK CONSTRAINT ALL;
    ALTER TABLE ModuleType NOCHECK CONSTRAINT ALL;
    ALTER TABLE Motif NOCHECK CONSTRAINT ALL;
    ALTER TABLE MultiLevel NOCHECK CONSTRAINT ALL;
    ALTER TABLE MultiLevelComponent NOCHECK CONSTRAINT ALL;
    ALTER TABLE NonInvPaperTrans NOCHECK CONSTRAINT ALL;
    ALTER TABLE Operator NOCHECK CONSTRAINT ALL;
    ALTER TABLE OperatorCalendar NOCHECK CONSTRAINT ALL;
    ALTER TABLE OperatorDeviceFee NOCHECK CONSTRAINT ALL;
    ALTER TABLE OperatorSettings NOCHECK CONSTRAINT ALL;
    ALTER TABLE Package NOCHECK CONSTRAINT ALL;
    ALTER TABLE PackageProductItems NOCHECK CONSTRAINT ALL;
    ALTER TABLE PackageProductOverrides NOCHECK CONSTRAINT ALL;
    ALTER TABLE PaperColorStyle NOCHECK CONSTRAINT ALL;
    ALTER TABLE PaperLayout NOCHECK CONSTRAINT ALL;
    ALTER TABLE PaperPack NOCHECK CONSTRAINT ALL;
    ALTER TABLE PaperPriceCalendar NOCHECK CONSTRAINT ALL;
    ALTER TABLE PaperTemplate NOCHECK CONSTRAINT ALL;
    ALTER TABLE PaperTemplateItem NOCHECK CONSTRAINT ALL;
    ALTER TABLE PayOptionDescriptions NOCHECK CONSTRAINT ALL;
    ALTER TABLE PayOptions NOCHECK CONSTRAINT ALL;
    ALTER TABLE Perm NOCHECK CONSTRAINT ALL;
    ALTER TABLE PermRange NOCHECK CONSTRAINT ALL;
    ALTER TABLE Photo NOCHECK CONSTRAINT ALL;
    ALTER TABLE PhotoType NOCHECK CONSTRAINT ALL;
    ALTER TABLE Player NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerConfig NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerImage NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerInformation NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerList NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerListCriteria NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerListCriteriaValue NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerLoyaltyTier NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerLoyaltyTierRules NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerMagCards NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerRaffle NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerRaffleWinners NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerStatus NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerStatusCode NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerTaxForm NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayerTierCalcTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE PlayType NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerCard NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerCardDeck NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerGameDef NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerHandType NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerHoldHint NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerPayOptions NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerPayTable NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerPayTableDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerSuit NOCHECK CONSTRAINT ALL;
    ALTER TABLE PokerWinType NOCHECK CONSTRAINT ALL;
    ALTER TABLE Position NOCHECK CONSTRAINT ALL;
    ALTER TABLE POSMenu NOCHECK CONSTRAINT ALL;
    ALTER TABLE POSMenuButtons NOCHECK CONSTRAINT ALL;
    ALTER TABLE PrizeCheck NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProductFeatures NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProductGroup NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProductItem NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProductType NOCHECK CONSTRAINT ALL;
    ALTER TABLE Program NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProgramCalendar NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProgramGames NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProgramGamesPatterns NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProgramGameWinners NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProgramGameWinnersDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE ProgramType NOCHECK CONSTRAINT ALL;
    --ALTER TABLE ProgressiveDefs NOCHECK CONSTRAINT ALL;
    ALTER TABLE PullTabStatus NOCHECK CONSTRAINT ALL;
    ALTER TABLE QuantitySales NOCHECK CONSTRAINT ALL;
    ALTER TABLE QuantitySalesVoids NOCHECK CONSTRAINT ALL;
    ALTER TABLE RegisterDetail NOCHECK CONSTRAINT ALL;
    ALTER TABLE RegisterDetailItems NOCHECK CONSTRAINT ALL;
    ALTER TABLE RegisterReceipt NOCHECK CONSTRAINT ALL;
    ALTER TABLE ReportDefinitions NOCHECK CONSTRAINT ALL;
    ALTER TABLE ReportGroupLink NOCHECK CONSTRAINT ALL;
    ALTER TABLE ReportGroups NOCHECK CONSTRAINT ALL;
    ALTER TABLE ReportImages NOCHECK CONSTRAINT ALL;
    ALTER TABLE ReportLocalizations NOCHECK CONSTRAINT ALL;
    ALTER TABLE ReportParameters NOCHECK CONSTRAINT ALL;
    ALTER TABLE Reports NOCHECK CONSTRAINT ALL;
    ALTER TABLE ReportTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE ReportUserGroupLink NOCHECK CONSTRAINT ALL;
    ALTER TABLE ReportUserTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE RollTrans NOCHECK CONSTRAINT ALL;
    ALTER TABLE RptOption NOCHECK CONSTRAINT ALL;
    ALTER TABLE SalesSource NOCHECK CONSTRAINT ALL;
    ALTER TABLE Scenes NOCHECK CONSTRAINT ALL;
    ALTER TABLE Seat NOCHECK CONSTRAINT ALL;
    ALTER TABLE Section NOCHECK CONSTRAINT ALL;
    --ALTER TABLE SecurityAccess NOCHECK CONSTRAINT ALL;
    --ALTER TABLE SecuritySettings NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionCostSetup NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionCostTemplate NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionCostTransactions NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionEligibility NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionEligibilityDetail NOCHECK CONSTRAINT ALL;
    --ALTER TABLE SessionGamesCurrency NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesLocked NOCHECK CONSTRAINT ALL;
    --ALTER TABLE SessionGamesMedia NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesPlayed NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesPlayedPattern NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesSettings NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesWild NOCHECK CONSTRAINT ALL;
    ALTER TABLE SessionPlayed NOCHECK CONSTRAINT ALL;
    --ALTER TABLE SessionSummaryDetail NOCHECK CONSTRAINT ALL;
    --ALTER TABLE SessionSummaryMaster NOCHECK CONSTRAINT ALL;
    ALTER TABLE SettingCategories NOCHECK CONSTRAINT ALL;
    ALTER TABLE Shapes NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameBonusValues NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameConfigTransactions NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameLineDefs NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGamePayTables NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameReelDefs NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGames NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGamesLinesAvailable NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameSymbolGroupItem NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameSymbolGroups NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameSymbols NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameSymbolSubstitute NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameTransactionTypes NOCHECK CONSTRAINT ALL;
    ALTER TABLE SlotPayOptions NOCHECK CONSTRAINT ALL;
    ALTER TABLE Staff NOCHECK CONSTRAINT ALL;
    ALTER TABLE StaffPositions NOCHECK CONSTRAINT ALL;
    ALTER TABLE StaffPWDLog NOCHECK CONSTRAINT ALL;
    ALTER TABLE SwipeInfo NOCHECK CONSTRAINT ALL;
    ALTER TABLE SwipeTypes NOCHECK CONSTRAINT ALL;
    --ALTER TABLE TaxForm NOCHECK CONSTRAINT ALL;
    ALTER TABLE TransactionNumber NOCHECK CONSTRAINT ALL;
    ALTER TABLE TransactionType NOCHECK CONSTRAINT ALL;
    ALTER TABLE TransCategory NOCHECK CONSTRAINT ALL;
    ALTER TABLE UKFragments NOCHECK CONSTRAINT ALL;
    ALTER TABLE UKPackageOverride NOCHECK CONSTRAINT ALL;
    ALTER TABLE UKPermDef NOCHECK CONSTRAINT ALL;
    ALTER TABLE UKSerialLookup NOCHECK CONSTRAINT ALL;
    ALTER TABLE UKSessionLookup NOCHECK CONSTRAINT ALL;
    ALTER TABLE UniqueNumber NOCHECK CONSTRAINT ALL;
    ALTER TABLE UnLockLog NOCHECK CONSTRAINT ALL;
    ALTER TABLE Vendor NOCHECK CONSTRAINT ALL;
    ALTER TABLE VersionInfo NOCHECK CONSTRAINT ALL;
    ALTER TABLE WildDefs NOCHECK CONSTRAINT ALL;
    ALTER TABLE WildSettings NOCHECK CONSTRAINT ALL;
    ALTER TABLE zTablePrefix NOCHECK CONSTRAINT ALL;


    -- New Edge 3.4 tables
    ALTER TABLE Accrual NOCHECK CONSTRAINT ALL;
    ALTER TABLE AccrualAccount NOCHECK CONSTRAINT ALL;
    ALTER TABLE AccrualDisplay NOCHECK CONSTRAINT ALL;
    ALTER TABLE AccrualDisplayItem NOCHECK CONSTRAINT ALL;
    ALTER TABLE AccrualIncreaseType NOCHECK CONSTRAINT ALL;
    ALTER TABLE AccrualOverrides NOCHECK CONSTRAINT ALL;
    ALTER TABLE AccrualOverrideAccounts NOCHECK CONSTRAINT ALL;
    ALTER TABLE AccrualProductItems NOCHECK CONSTRAINT ALL;
    ALTER TABLE AccrualTransactionDetails NOCHECK CONSTRAINT ALL;
    ALTER TABLE AccrualTransactions NOCHECK CONSTRAINT ALL;
    ALTER TABLE PayoutCategories NOCHECK CONSTRAINT ALL;
    ALTER TABLE PayoutSchedules NOCHECK CONSTRAINT ALL;
    ALTER TABLE PayoutSettings NOCHECK CONSTRAINT ALL;



    create table #PILink (xfProductItemID int, xtProductItemID int);
    create table #FromPackage (fpID int IDENTITY(1,1), fpPackageID int);
    create table #ToPackage (tpID int IDENTITY(1,1), tpPackageID int);
    create table #FromPOSMenu (fposID int IDENTITY(1,1), fposPOSMenuID int);
    create table #ToPOSMenu (tposID int IDENTITY(1,1), tposPOSMenuID int);
    create table #FromDiscounts (fdID int IDENTITY(1,1), fdDiscountID int);
    create table #ToDiscounts (tdID int IDENTITY(1,1), tdDiscountID int);
    create table #FromProgram (fprogID int IDENTITY(1,1), fprogProgramID int);
    create table #ToProgram (tprogID int IDENTITY(1,1), tprogProgramID int);
    create table #FromProgramGames (fpgID int IDENTITY(1,1), fpgProgramGamesID int);
    create table #ToProgramGames (tpgID int IDENTITY(1,1), tpgProgramGamesID int);

    create table #FromPayoutCategories (fpcID int IDENTITY(1,1), fpcPayoutCategoryID int);
    create table #ToPayoutCategories (tpcID int IDENTITY(1,1), tpcPayoutCategoryID int);
    create table #FromPayoutSchedules (fpsID int IDENTITY(1,1), fpsPayoutScheduleID int);
    create table #ToPayoutSchedules (tpsID int IDENTITY(1,1), tpsPayoutScheduleID int);
    create table #FromProductGroup (fpgID int IDENTITY(1,1), fpgProductGroupID int);
    create table #ToProductGroup (tpgID int IDENTITY(1,1), tpgProductGroupID int);



    --ProductItem
    insert ProductItem (
	    ProductTypeID,
	    SalesSourceID,
	    OperatorID,
	    ItemName,
	    IsActive,
	    BookID,
	    ProductGroupID,
	    PaperLayoutID)
	    OUTPUT INSERTED.BookID, INSERTED.ProductItemID into #PILink
    select ProductTypeID,
	    SalesSourceID,
	    @ToOperatorID,
	    ItemName,
	    IsActive,
	    ProductItemID,	--put the OLD ProductItemID in the BookID field
	    ProductGroupID,
	    PaperLayoutID	
    from ProductItem
    where OperatorID = @FromOperatorID

    update ProductItem
    set BookID = 0
    where OperatorID = @ToOperatorID

    insert #FromPackage (fpPackageID)
    select PackageID
    from Package
    where OperatorID = @FromOperatorID
    order by PackageID 

    --Package
    insert Package (
	    PackageName,
	    ChargeDeviceFee,
	    ReceiptText,
	    IsActive,
	    PackageCode,
	    OperatorID)
	    OUTPUT INSERTED.PackageID into #ToPackage
    select PackageName,
	    ChargeDeviceFee,
	    ReceiptText,
	    IsActive,
	    PackageCode,
	    @ToOperatorID
    from Package
    where OperatorID = @FromOperatorID
    order by PackageID

    insert PackageProductItems (
	    PackageID,
	    ProductItemID,
	    GameTypeID,
	    CardLevelID,
	    CardMediaID,
	    CardTypeID,
	    GameCategoryID,
	    IsTaxed,
	    Price,
	    Qty,
	    PtsPerDollar,
	    PtsPerQuantity,
	    PtsToRedeem,
	    CardCount,
	    OptionalItem,
	    NumbersRequired)
    select tpPackageID,
	    xtProductItemID,
	    GameTypeID,
	    CardLevelID,
	    CardMediaID,
	    CardTypeID,
	    GameCategoryID,
	    IsTaxed,
	    Price,
	    Qty,
	    PtsPerDollar,
	    PtsPerQuantity,
	    PtsToRedeem,
	    CardCount,
	    OptionalItem,
	    NumbersRequired
    from PackageProductItems
    join #FromPackage on PackageID = fpPackageID
    join #ToPackage on fpID = tpID
    join #PILink on ProductItemID = xfProductItemID

    insert #FromPOSMenu (fposPOSMenuID)
    select POSMenuID
    from POSMenu
    where OperatorID = @FromOperatorID
    order by POSMenuID

    --POSMenu
    insert POSMenu (
	    OperatorID,
	    MenuName,
	    MenuTypeID)
    OUTPUT INSERTED.POSMenuID INTO #ToPOSMenu
    select @ToOperatorID,
	    MenuName,
	    MenuTypeID
    from POSMenu
    where OperatorID = @FromOperatorID
    order by POSMenuID

    insert #FromDiscounts (fdDiscountID)
    select DiscountID
    from Discounts
    where OperatorID = @FromOperatorID
    order by DiscountID

    --Discounts
    insert Discounts (
	    OperatorID,
	    DiscountTypeID,
	    Amount,
	    PointsPerDollar,
	    IsActive)
	    OUTPUT INSERTED.DiscountID INTO #ToDiscounts
    select @ToOperatorID,
	    DiscountTypeID,
	    Amount,
	    PointsPerDollar,
	    IsActive
    from Discounts
    where OperatorID = @FromOperatorID
    order by DiscountID

    insert POSMenuButtons (
	    DiscountID,
	    POSMenuID,
	    FunctionsID,
	    PackageID,
	    PageNumber,
	    KeyNum,
	    KeyText,
	    KeyColor,
	    KeyLocked,
	    PlayerRequired,
	    GraphicID)
    select DiscountID,
	    tposPOSMenuID,
	    FunctionsID,
	    tpPackageID,
	    PageNumber,
	    KeyNum,
	    KeyText,
	    KeyColor,
	    KeyLocked,
	    PlayerRequired,
	    GraphicID
    from POSMenuButtons
    join #FromPOSMenu on POSMenuID = fposPOSMenuID
    join #ToPOSMenu on fposID = tposID
    join #FromPackage on PackageID = fpPackageID
    join #ToPackage on fpID = tpID

    --There is no PackageID when a DiscountID exists
    insert POSMenuButtons (
	    DiscountID,
	    POSMenuID,
	    FunctionsID,
	    PackageID,
	    PageNumber,
	    KeyNum,
	    KeyText,
	    KeyColor,
	    KeyLocked,
	    PlayerRequired,
	    GraphicID)
    select tdDiscountID,
	    tposPOSMenuID,
	    FunctionsID,
	    PackageID,
	    PageNumber,
	    KeyNum,
	    KeyText,
	    KeyColor,
	    KeyLocked,
	    PlayerRequired,
	    GraphicID
    from POSMenuButtons
    join #FromPOSMenu on POSMenuID = fposPOSMenuID
    join #ToPOSMenu on fposID = tposID
    join #FromDiscounts on DiscountID = fdDiscountID
    join #ToDiscounts on fdID =  tdID

    insert #FromProgram (fprogProgramID)
    select ProgramID
    from Program
    where OperatorID = @FromOperatorID
    order by ProgramID

    insert Program (
	    OperatorID,
	    ProgramName,
	    IsActive,
	    ProgramTypeID)
	    OUTPUT INSERTED.ProgramID INTO #ToProgram
    select @ToOperatorID,
	    ProgramName,
	    IsActive,
	    ProgramTypeID
    from Program
    where OperatorID = @FromOperatorID
    order by ProgramID

    insert #FromProgramGames (fpgProgramGamesID)
    select pg.ProgramGamesID
    from ProgramGames pg
    join Program p on pg.ProgramID = p.ProgramID
    where p.OperatorID = @FromOperatorID
    order by pg.ProgramGamesID

    insert ProgramGames (
	    GameTypeID,
	    ProgramID,
	    GameCategoryID,
	    GameSeqNo,
	    IsContinued,
	    EliminationGame,
	    GameName,
	    DisplayGameNo,
	    DisplayPartNo,
	    Color,
	    IsActive,
	    IsBonanza,
	    GameSettingsID)
 	    OUTPUT INSERTED.ProgramGamesID INTO #ToProgramGames
    select GameTypeID,
	    tprogProgramID,
	    GameCategoryID,
	    GameSeqNo,
	    IsContinued,
	    EliminationGame,
	    GameName,
	    DisplayGameNo,
	    DisplayPartNo,
	    Color,
	    IsActive,
	    IsBonanza,
	    GameSettingsID
    from ProgramGames
    join #FromProgram on ProgramID = fprogProgramID
    join #ToProgram on fprogID = tprogID
    order by ProgramGamesID

    insert ProgramGamesPatterns (
	    ProgramGamesID,
	    PatternNo,
	    PatternName,
	    CBBPatternMask)
    select tpgProgramGamesID,
	    PatternNo,
	    PatternName,
	    CBBPatternMask
    from ProgramGamesPatterns
    join #FromProgramGames on ProgramGamesID = fpgProgramGamesID
    join #ToProgramGames on fpgID = tpgID

    insert ProgramCalendar (
	    OperatorID,
	    ProgramID,
	    POSMenuID,
	    [DayOfWeek],
	    GamingSession,
	    StartDate,
	    EndDate,
	    ProgramStartTime,
	    ProgramEndTime)
    select @ToOperatorID,
	    tprogProgramID,
	    tposPOSMenuID,
	    [DayOfWeek],
	    GamingSession,
	    StartDate,
	    EndDate,
	    ProgramStartTime,
	    ProgramEndTime
    from ProgramCalendar
    join #FromProgram on ProgramID = fprogProgramID
    join #ToProgram on fprogID = tprogID
    join #FromPOSMenu on POSMenuID = fposPOSMenuID
    join #ToPOSMenu on fposID = tposID 

    -- 
    -- PayoutCategories
    --
    insert #FromPayoutCategories (fpcPayoutCategoryID)
    select PayoutCategoryID
    from PayoutCategories
    where OperatorID = @FromOperatorID
    order by PayoutCategoryID;

    insert PayoutCategories (
	    OperatorID,
	    PayoutCategoryName,
	    IsActive)
	    output inserted.PayoutCategoryID into #ToPayoutCategories
    select @ToOperatorID,
	    PayoutCategoryName,
	    IsActive
    from PayoutCategories
    where OperatorID = @FromOperatorID;

    -- 
    -- PayoutSchedules
    --
    insert #FromPayoutSchedules (fpsPayoutScheduleID)
    select PayoutScheduleID
    from PayoutSchedules
    where OperatorID = @FromOperatorID
    order by PayoutScheduleID;

    insert PayoutSchedules (
	    OperatorID,
	    PayoutScheduleName,
	    IsActive)
	    output inserted.PayoutScheduleID into #ToPayoutSchedules
    select @ToOperatorID,
	    PayoutScheduleName,
	    IsActive
    from PayoutSchedules
    where OperatorID = @FromOperatorID;

    -- 
    -- ProductGroup
    --
    insert #FromProductGroup (fpgProductGroupID)
    select ProductGroupID
    from ProductGroup
    where OperatorID = @FromOperatorID
    order by ProductGroupID;

    insert ProductGroup (
	    OperatorID,
	    GroupName,
	    IsActive)
	    output inserted.ProductGroupID into #ToProductGroup
    select @ToOperatorID,
	    GroupName,
	    IsActive
    from ProductGroup
    where OperatorID = @FromOperatorID;



    drop table #PILink;
    drop table #FromPackage;
    drop table #ToPackage;
    drop table #FromPOSMenu;
    drop table #ToPOSMenu;
    drop table #FromDiscounts;
    drop table #ToDiscounts;
    drop table #FromProgram;
    drop table #ToProgram;
    drop table #FromProgramGames;
    drop table #ToProgramGames;
    drop table #FromPayoutCategories;
    drop table #ToPayoutCategories;
    drop table #FromPayoutSchedules;
    drop table #ToPayoutSchedules;
    drop table #FromProductGroup;
    drop table #ToProductGroup;

    --turn on constraints
    ALTER TABLE AccessLog CHECK CONSTRAINT ALL;
    ALTER TABLE Address CHECK CONSTRAINT ALL;
    ALTER TABLE BadCheck CHECK CONSTRAINT ALL;
    ALTER TABLE BadCheckPayment CHECK CONSTRAINT ALL;
    ALTER TABLE BadCheckStatus CHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardBonusDefs CHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardDetail CHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardHeader CHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardSales CHECK CONSTRAINT ALL;
    ALTER TABLE BingoCardStartNumber CHECK CONSTRAINT ALL;
    ALTER TABLE BonusEndTypes CHECK CONSTRAINT ALL;
    ALTER TABLE BonusIcons CHECK CONSTRAINT ALL;
    ALTER TABLE BonusIconSelect CHECK CONSTRAINT ALL;
    ALTER TABLE BonusItemTypes CHECK CONSTRAINT ALL;
    ALTER TABLE BonusTypes CHECK CONSTRAINT ALL;
    ALTER TABLE BSM CHECK CONSTRAINT ALL;
    ALTER TABLE ButtonGraphic CHECK CONSTRAINT ALL;
    ALTER TABLE CardCuts CHECK CONSTRAINT ALL;
    ALTER TABLE CardLevel CHECK CONSTRAINT ALL;
    ALTER TABLE CardMedia CHECK CONSTRAINT ALL;
    ALTER TABLE CardStartsTypes CHECK CONSTRAINT ALL;
    ALTER TABLE CardStatus CHECK CONSTRAINT ALL;
    ALTER TABLE CardStatusOverride CHECK CONSTRAINT ALL;
    ALTER TABLE CardType CHECK CONSTRAINT ALL;
    ALTER TABLE CashMethod CHECK CONSTRAINT ALL;
    ALTER TABLE CBBFavorites CHECK CONSTRAINT ALL;
    ALTER TABLE Channel CHECK CONSTRAINT ALL;
    ALTER TABLE Color CHECK CONSTRAINT ALL;
    ALTER TABLE Company CHECK CONSTRAINT ALL;
    ALTER TABLE CompAutoAwardRules CHECK CONSTRAINT ALL;
    ALTER TABLE CompAward CHECK CONSTRAINT ALL;
    ALTER TABLE CompCriteriaAwardHistory CHECK CONSTRAINT ALL;
    ALTER TABLE CompLimit CHECK CONSTRAINT ALL;
    ALTER TABLE CompRafflePrizes CHECK CONSTRAINT ALL;
    ALTER TABLE CompRaffles CHECK CONSTRAINT ALL;
    ALTER TABLE CompRaffleType CHECK CONSTRAINT ALL;
    ALTER TABLE Comps CHECK CONSTRAINT ALL;
    ALTER TABLE ConfigPhoto CHECK CONSTRAINT ALL;
    ALTER TABLE Configuration CHECK CONSTRAINT ALL;
    ALTER TABLE CreditBalances CHECK CONSTRAINT ALL;
    ALTER TABLE CreditBalancesTransLog CHECK CONSTRAINT ALL;
    ALTER TABLE CreditGroupAccounts CHECK CONSTRAINT ALL;
    ALTER TABLE CreditGroupPlayers CHECK CONSTRAINT ALL;
    ALTER TABLE CurrencyType CHECK CONSTRAINT ALL;
    ALTER TABLE CustomDetail CHECK CONSTRAINT ALL;
    ALTER TABLE CustomerMailer CHECK CONSTRAINT ALL;
    ALTER TABLE CustomField CHECK CONSTRAINT ALL;
    ALTER TABLE CustomFieldType CHECK CONSTRAINT ALL;
    ALTER TABLE CustomFieldValue CHECK CONSTRAINT ALL;
    ALTER TABLE DailyGamesLink CHECK CONSTRAINT ALL;
    ALTER TABLE DailyMenuButtons CHECK CONSTRAINT ALL;
    ALTER TABLE DailyPackageProduct CHECK CONSTRAINT ALL;
    ALTER TABLE DailyStaffMenu CHECK CONSTRAINT ALL;
    ALTER TABLE Device CHECK CONSTRAINT ALL;
    ALTER TABLE DeviceHardwareAttributes CHECK CONSTRAINT ALL;
    ALTER TABLE DeviceModules CHECK CONSTRAINT ALL;
    ALTER TABLE DeviceMotif CHECK CONSTRAINT ALL;
    ALTER TABLE DeviceProductFeatures CHECK CONSTRAINT ALL;
    ALTER TABLE Discounts CHECK CONSTRAINT ALL;
    ALTER TABLE DiscountTypes CHECK CONSTRAINT ALL;
    ALTER TABLE Event CHECK CONSTRAINT ALL;
    ALTER TABLE EventObject CHECK CONSTRAINT ALL;
    ALTER TABLE FeaturePermissions CHECK CONSTRAINT ALL;
    ALTER TABLE Functions CHECK CONSTRAINT ALL;
    ALTER TABLE GameBallsCalled CHECK CONSTRAINT ALL;
    ALTER TABLE GameCategory CHECK CONSTRAINT ALL;
    --ALTER TABLE GameCurrency CHECK CONSTRAINT ALL;
    ALTER TABLE GameDenomDefs CHECK CONSTRAINT ALL;
    ALTER TABLE GameDenomsAvail CHECK CONSTRAINT ALL;
    ALTER TABLE GameEligibilityDefs CHECK CONSTRAINT ALL;
    ALTER TABLE GameEligibilityDetail CHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistory CHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistoryDtl CHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistoryWinLine CHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistoryWinLineBonus CHECK CONSTRAINT ALL;
    ALTER TABLE GameIPPlayHistoryWinLineDtl CHECK CONSTRAINT ALL;
    ALTER TABLE GameLevel CHECK CONSTRAINT ALL;
    ALTER TABLE GameLockTrans CHECK CONSTRAINT ALL;
    --ALTER TABLE GameMedia CHECK CONSTRAINT ALL;
    ALTER TABLE GamePlayHistoryLineDetail CHECK CONSTRAINT ALL;
    ALTER TABLE GameSet CHECK CONSTRAINT ALL;
    ALTER TABLE GameSetGame CHECK CONSTRAINT ALL;
    ALTER TABLE GameSettings CHECK CONSTRAINT ALL;
    ALTER TABLE GameTrans CHECK CONSTRAINT ALL;
    ALTER TABLE GameTransDetail CHECK CONSTRAINT ALL;
    ALTER TABLE GameTypes CHECK CONSTRAINT ALL;
    ALTER TABLE GiftCard CHECK CONSTRAINT ALL;
    ALTER TABLE GlobalSettings CHECK CONSTRAINT ALL;
    ALTER TABLE Hall CHECK CONSTRAINT ALL;
    ALTER TABLE HardwareAttributes CHECK CONSTRAINT ALL;
    ALTER TABLE HotBallSale CHECK CONSTRAINT ALL;
    ALTER TABLE JackpotDetails CHECK CONSTRAINT ALL;
    ALTER TABLE JStampDetail CHECK CONSTRAINT ALL;
    ALTER TABLE JStampHeader CHECK CONSTRAINT ALL;
    ALTER TABLE KenoBonusDef CHECK CONSTRAINT ALL;
    ALTER TABLE KenoBonusDetail CHECK CONSTRAINT ALL;
    ALTER TABLE KenoBonusHeader CHECK CONSTRAINT ALL;
    ALTER TABLE KenoBonusPoolSubset CHECK CONSTRAINT ALL;
    ALTER TABLE KenoGameDef CHECK CONSTRAINT ALL;
    ALTER TABLE KenoPayOptions CHECK CONSTRAINT ALL;
    ALTER TABLE KenoPayTable CHECK CONSTRAINT ALL;
    ALTER TABLE Layout CHECK CONSTRAINT ALL;
    ALTER TABLE LBCardBonusNums CHECK CONSTRAINT ALL;
    ALTER TABLE LBCardSale CHECK CONSTRAINT ALL;
    ALTER TABLE LBCardSaleDetail CHECK CONSTRAINT ALL;
    ALTER TABLE LBCardWinHold CHECK CONSTRAINT ALL;
    ALTER TABLE LBGame CHECK CONSTRAINT ALL;
    ALTER TABLE LBGameBall CHECK CONSTRAINT ALL;
    ALTER TABLE LBGameBallHold CHECK CONSTRAINT ALL;
    ALTER TABLE LBGameBonusNos CHECK CONSTRAINT ALL;
    ALTER TABLE LBGameBonusNosHold CHECK CONSTRAINT ALL;
    ALTER TABLE Location CHECK CONSTRAINT ALL;
    ALTER TABLE LoginConnectionType CHECK CONSTRAINT ALL;
    ALTER TABLE LogMain CHECK CONSTRAINT ALL;
    ALTER TABLE Machine CHECK CONSTRAINT ALL;
    ALTER TABLE MachineSettings CHECK CONSTRAINT ALL;
    ALTER TABLE MachineStatus CHECK CONSTRAINT ALL;
    ALTER TABLE MagCardReaderMode CHECK CONSTRAINT ALL;
    ALTER TABLE Manufacturer CHECK CONSTRAINT ALL;
    ALTER TABLE MenuType CHECK CONSTRAINT ALL;
    ALTER TABLE ModuleFeatures CHECK CONSTRAINT ALL;
    ALTER TABLE ModuleMachinePersistentData CHECK CONSTRAINT ALL;
    ALTER TABLE ModulePermissions CHECK CONSTRAINT ALL;
    ALTER TABLE ModulePersistentData CHECK CONSTRAINT ALL;
    ALTER TABLE Modules CHECK CONSTRAINT ALL;
    ALTER TABLE ModuleType CHECK CONSTRAINT ALL;
    ALTER TABLE Motif CHECK CONSTRAINT ALL;
    ALTER TABLE MultiLevel CHECK CONSTRAINT ALL;
    ALTER TABLE MultiLevelComponent CHECK CONSTRAINT ALL;
    ALTER TABLE NonInvPaperTrans CHECK CONSTRAINT ALL;
    ALTER TABLE Operator CHECK CONSTRAINT ALL;
    ALTER TABLE OperatorCalendar CHECK CONSTRAINT ALL;
    ALTER TABLE OperatorDeviceFee CHECK CONSTRAINT ALL;
    ALTER TABLE OperatorSettings CHECK CONSTRAINT ALL;
    ALTER TABLE Package CHECK CONSTRAINT ALL;
    ALTER TABLE PackageProductItems CHECK CONSTRAINT ALL;
    ALTER TABLE PackageProductOverrides CHECK CONSTRAINT ALL;
    ALTER TABLE PaperColorStyle CHECK CONSTRAINT ALL;
    ALTER TABLE PaperLayout CHECK CONSTRAINT ALL;
    ALTER TABLE PaperPack CHECK CONSTRAINT ALL;
    ALTER TABLE PaperPriceCalendar CHECK CONSTRAINT ALL;
    ALTER TABLE PaperTemplate CHECK CONSTRAINT ALL;
    ALTER TABLE PaperTemplateItem CHECK CONSTRAINT ALL;
    ALTER TABLE PayOptionDescriptions CHECK CONSTRAINT ALL;
    ALTER TABLE PayOptions CHECK CONSTRAINT ALL;
    ALTER TABLE Perm CHECK CONSTRAINT ALL;
    ALTER TABLE PermRange CHECK CONSTRAINT ALL;
    ALTER TABLE Photo CHECK CONSTRAINT ALL;
    ALTER TABLE PhotoType CHECK CONSTRAINT ALL;
    ALTER TABLE Player CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerConfig CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerImage CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerInformation CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerList CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerListCriteria CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerListCriteriaValue CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerLoyaltyTier CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerLoyaltyTierRules CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerMagCards CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerRaffle CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerRaffleWinners CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerStatus CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerStatusCode CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerTaxForm CHECK CONSTRAINT ALL;
    ALTER TABLE PlayerTierCalcTypes CHECK CONSTRAINT ALL;
    ALTER TABLE PlayType CHECK CONSTRAINT ALL;
    ALTER TABLE PokerCard CHECK CONSTRAINT ALL;
    ALTER TABLE PokerCardDeck CHECK CONSTRAINT ALL;
    ALTER TABLE PokerGameDef CHECK CONSTRAINT ALL;
    ALTER TABLE PokerHandType CHECK CONSTRAINT ALL;
    ALTER TABLE PokerHoldHint CHECK CONSTRAINT ALL;
    ALTER TABLE PokerPayOptions CHECK CONSTRAINT ALL;
    ALTER TABLE PokerPayTable CHECK CONSTRAINT ALL;
    ALTER TABLE PokerPayTableDetail CHECK CONSTRAINT ALL;
    ALTER TABLE PokerSuit CHECK CONSTRAINT ALL;
    ALTER TABLE PokerWinType CHECK CONSTRAINT ALL;
    ALTER TABLE Position CHECK CONSTRAINT ALL;
    ALTER TABLE POSMenu CHECK CONSTRAINT ALL;
    ALTER TABLE POSMenuButtons CHECK CONSTRAINT ALL;
    ALTER TABLE PrizeCheck CHECK CONSTRAINT ALL;
    ALTER TABLE ProductFeatures CHECK CONSTRAINT ALL;
    ALTER TABLE ProductGroup CHECK CONSTRAINT ALL;
    ALTER TABLE ProductItem CHECK CONSTRAINT ALL;
    ALTER TABLE ProductType CHECK CONSTRAINT ALL;
    ALTER TABLE Program CHECK CONSTRAINT ALL;
    ALTER TABLE ProgramCalendar CHECK CONSTRAINT ALL;
    ALTER TABLE ProgramGames CHECK CONSTRAINT ALL;
    ALTER TABLE ProgramGamesPatterns CHECK CONSTRAINT ALL;
    ALTER TABLE ProgramGameWinners CHECK CONSTRAINT ALL;
    ALTER TABLE ProgramGameWinnersDetail CHECK CONSTRAINT ALL;
    ALTER TABLE ProgramType CHECK CONSTRAINT ALL;
    --ALTER TABLE ProgressiveDefs CHECK CONSTRAINT ALL;
    ALTER TABLE PullTabStatus CHECK CONSTRAINT ALL;
    ALTER TABLE QuantitySales CHECK CONSTRAINT ALL;
    ALTER TABLE QuantitySalesVoids CHECK CONSTRAINT ALL;
    ALTER TABLE RegisterDetail CHECK CONSTRAINT ALL;
    ALTER TABLE RegisterDetailItems CHECK CONSTRAINT ALL;
    ALTER TABLE RegisterReceipt CHECK CONSTRAINT ALL;
    ALTER TABLE ReportDefinitions CHECK CONSTRAINT ALL;
    ALTER TABLE ReportGroupLink CHECK CONSTRAINT ALL;
    ALTER TABLE ReportGroups CHECK CONSTRAINT ALL;
    ALTER TABLE ReportImages CHECK CONSTRAINT ALL;
    ALTER TABLE ReportLocalizations CHECK CONSTRAINT ALL;
    ALTER TABLE ReportParameters CHECK CONSTRAINT ALL;
    ALTER TABLE Reports CHECK CONSTRAINT ALL;
    ALTER TABLE ReportTypes CHECK CONSTRAINT ALL;
    ALTER TABLE ReportUserGroupLink CHECK CONSTRAINT ALL;
    ALTER TABLE ReportUserTypes CHECK CONSTRAINT ALL;
    ALTER TABLE RollTrans CHECK CONSTRAINT ALL;
    ALTER TABLE RptOption CHECK CONSTRAINT ALL;
    ALTER TABLE SalesSource CHECK CONSTRAINT ALL;
    ALTER TABLE Scenes CHECK CONSTRAINT ALL;
    ALTER TABLE Seat CHECK CONSTRAINT ALL;
    ALTER TABLE Section CHECK CONSTRAINT ALL;
    --ALTER TABLE SecurityAccess CHECK CONSTRAINT ALL;
    --ALTER TABLE SecuritySettings CHECK CONSTRAINT ALL;
    ALTER TABLE SessionCostSetup CHECK CONSTRAINT ALL;
    ALTER TABLE SessionCostTemplate CHECK CONSTRAINT ALL;
    ALTER TABLE SessionCostTransactions CHECK CONSTRAINT ALL;
    ALTER TABLE SessionEligibility CHECK CONSTRAINT ALL;
    ALTER TABLE SessionEligibilityDetail CHECK CONSTRAINT ALL;
    --ALTER TABLE SessionGamesCurrency CHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesLocked CHECK CONSTRAINT ALL;
    --ALTER TABLE SessionGamesMedia CHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesPlayed CHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesPlayedPattern CHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesSettings CHECK CONSTRAINT ALL;
    ALTER TABLE SessionGamesWild CHECK CONSTRAINT ALL;
    ALTER TABLE SessionPlayed CHECK CONSTRAINT ALL;
    --ALTER TABLE SessionSummaryDetail CHECK CONSTRAINT ALL;
    --ALTER TABLE SessionSummaryMaster CHECK CONSTRAINT ALL;
    ALTER TABLE SettingCategories CHECK CONSTRAINT ALL;
    ALTER TABLE Shapes CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameBonusValues CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameConfigTransactions CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameLineDefs CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGamePayTables CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameReelDefs CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGames CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGamesLinesAvailable CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameSymbolGroupItem CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameSymbolGroups CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameSymbols CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameSymbolSubstitute CHECK CONSTRAINT ALL;
    ALTER TABLE SlotGameTransactionTypes CHECK CONSTRAINT ALL;
    ALTER TABLE SlotPayOptions CHECK CONSTRAINT ALL;
    ALTER TABLE Staff CHECK CONSTRAINT ALL;
    ALTER TABLE StaffPositions CHECK CONSTRAINT ALL;
    ALTER TABLE StaffPWDLog CHECK CONSTRAINT ALL;
    ALTER TABLE SwipeInfo CHECK CONSTRAINT ALL;
    ALTER TABLE SwipeTypes CHECK CONSTRAINT ALL;
    --ALTER TABLE TaxForm CHECK CONSTRAINT ALL;
    ALTER TABLE TransactionNumber CHECK CONSTRAINT ALL;
    ALTER TABLE TransactionType CHECK CONSTRAINT ALL;
    ALTER TABLE TransCategory CHECK CONSTRAINT ALL;
    ALTER TABLE UKFragments CHECK CONSTRAINT ALL;
    ALTER TABLE UKPackageOverride CHECK CONSTRAINT ALL;
    ALTER TABLE UKPermDef CHECK CONSTRAINT ALL;
    ALTER TABLE UKSerialLookup CHECK CONSTRAINT ALL;
    ALTER TABLE UKSessionLookup CHECK CONSTRAINT ALL;
    ALTER TABLE UniqueNumber CHECK CONSTRAINT ALL;
    ALTER TABLE UnLockLog CHECK CONSTRAINT ALL;
    ALTER TABLE Vendor CHECK CONSTRAINT ALL;
    ALTER TABLE VersionInfo CHECK CONSTRAINT ALL;
    ALTER TABLE WildDefs CHECK CONSTRAINT ALL;
    ALTER TABLE WildSettings CHECK CONSTRAINT ALL;
    ALTER TABLE zTablePrefix CHECK CONSTRAINT ALL;

    -- New Edge 3.4 tables
    ALTER TABLE Accrual CHECK CONSTRAINT ALL;
    ALTER TABLE AccrualAccount CHECK CONSTRAINT ALL;
    ALTER TABLE AccrualDisplay CHECK CONSTRAINT ALL;
    ALTER TABLE AccrualDisplayItem CHECK CONSTRAINT ALL;
    ALTER TABLE AccrualIncreaseType CHECK CONSTRAINT ALL;
    ALTER TABLE AccrualOverrides CHECK CONSTRAINT ALL;
    ALTER TABLE AccrualOverrideAccounts CHECK CONSTRAINT ALL;
    ALTER TABLE AccrualProductItems CHECK CONSTRAINT ALL;
    ALTER TABLE AccrualTransactionDetails CHECK CONSTRAINT ALL;
    ALTER TABLE AccrualTransactions CHECK CONSTRAINT ALL;
    ALTER TABLE PayoutCategories NOCHECK CONSTRAINT ALL;
    ALTER TABLE PayoutSchedules NOCHECK CONSTRAINT ALL;
    ALTER TABLE PayoutSettings NOCHECK CONSTRAINT ALL;
    
    commit transaction CopyOperatorTransaction;
    print 'Operator information copied successfully.';
end try
begin catch
    select error_number() [ErrorNumber], error_line() [ErrorLine], error_message() [ErrorMessage];
    
    rollback transaction CopyOperatorTransaction;
    print 'Transaction rolled back';
	print 'No information copied.';
end catch;

SET NOCOUNT OFF;



GO

