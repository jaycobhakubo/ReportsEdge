USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptAllPaperSales]    Script Date: 7/12/2013 4:42:07 PM ******/
DROP PROCEDURE [dbo].[spRptAllPaperSales]
GO

/****** Object:  StoredProcedure [dbo].[spRptAllPaperSales]    Script Date: 7/12/2013 4:42:07 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE proc [dbo].[spRptAllPaperSales]
(
    @operatorID int,
    @StartDate datetime,
    @Session int
)
-- ============================================================================
-- 2012.07.11 jkn DE10592 add support for limiting the sales by session
-- 2013.05.03 jkn TA11774 Separate QP and HP CBB sales
-- 2013.07.12 tmp DE11026 corrected CBB sales calculation so that sales are not doubled when a game is replayed
-- ============================================================================
as
begin
    set nocount on;
    
    --declare @OperatorID int;
    --declare @StartDate datetime;
    --declare @Session int;
    --set @OperatorID = 1;
    --set @StartDate = N'03/27/2012';
    --set @Session = 0;
    -- setup start and end dates.
    declare @EndDate datetime;
    set @StartDate = dateadd(day, 0, datediff(day, 0, @StartDate));
    set @EndDate = dateadd(day, 1, datediff(day, 0, @StartDate));
    
    declare @Results table
    (
        MasterTransId int,
        Product nvarchar(128),
        IssuedTo nvarchar(512),
        AuditStart int,
        AuditEnd int,
        AuditExceptions nvarchar(max),
        QuantitySold int,
        Price money
    );
    
    with MasterIssueTransactions as
    (
        select distinct isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID) as MasterTransId
        from InvTransaction it
            join InventoryItem ii on (it.ivtInventoryItemID = ii.iiInventoryItemID)
            join ProductItem pri on (ii.iiProductItemID = pri.ProductItemID)
        where it.ivtGamingDate >= @StartDate
    	    and it.ivtGamingDate < @EndDate
    	    and (it.ivtGamingSession = @Session or @Session = 0)
            and it.ivtTransactionTypeID = 25 -- issues
    	    and pri.ProductTypeID = 16 -- paper
    )
    insert into @Results
    select mit.MasterTransId,
        pri.ItemName,
        (select top 1 s.LastName + ', ' + s.FirstName + ' (' + cast(s.StaffID as nvarchar(10)) + ')'
        from InvLocations il
            join Staff s on (il.ilStaffID = s.StaffID)
        where il.ilInvLocationID = dbo.GetInventoryTransIssueToLocation(mit.MasterTransId)),
        dbo.GetInventoryTransStartNumber(mit.MasterTransId),
        dbo.GetInventoryTransEndNumber(mit.MasterTransId),
        '',
        dbo.GetInventoryTransIssueCount(mit.MasterTransId) -- issue
        - dbo.GetInventoryTransSkipCount(mit.MasterTransId) -- skip
        - dbo.GetInventoryTransDamageCount(mit.MasterTransId) -- damage
        - dbo.GetInventoryTransReturnCount(mit.MasterTransId), -- return = Quantity Sold
        dbo.GetInventoryTransPrice(mit.MasterTransId)
    from MasterIssueTransactions mit
        join InvTransaction it on (mit.MasterTransId = isnull(it.ivtMasterTransactionID, it.ivtInvTransactionID)
                                   and it.ivtInvTransactionID = (select top 1 ivtInvTransactionID from InvTransaction where isnull(ivtMasterTransactionID, ivtInvTransactionID) = mit.MasterTransId))
        join InventoryItem ii on (it.ivtInventoryItemID = ii.iiInventoryItemID)
        join ProductItem pri on (ii.iiProductItemID = pri.ProductItemID);
        
    --select * from @Results
    
    -- Get all of the Quick pick CBB paper sales
    insert into @Results
    select null,
        rdi.ProductItemName + ' (QP)',
        s.LastName + ', ' + s.FirstName + ' (' + cast(s.StaffID as nvarchar(10)) + ')',
        min(bch.bchMasterCardNo),
        max(bch.bchMasterCardNo),
        '',
        count(bch.bchMasterCardNo),
        rdi.Price
    from RegisterReceipt rr
        join RegisterDetail rd on rr.RegisterReceiptId = rd.RegisterReceiptId
        join SessionPlayed sp on rd.SessionPlayedId = sp.SessionPlayedId
        join RegisterDetailItems rdi on rd.RegisterDetailId = rdi.RegisterDetailId
     --   join BingoCardHeader bch on rdi.RegisterDetailItemId = bch.bchRegisterDetailItemId
		JOIN (Select Distinct bchMasterCardNo, bchRegisterDetailItemID, bchIsQuickPick, bchCardVoided From BingoCardHeader) as bch on (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID)
        join Staff s on rr.StaffId = s.StaffId
    where rr.GamingDate >= @StartDate
        and rr.GamingDate < @EndDate
        and (@OperatorId = 0 or rr.OperatorId = @OperatorId)
        and (@Session = 0 or sp.GamingSession = @Session)
        and rdi.GameTypeId = 4
        and rdi.CardMediaId = 2
        and bch.bchCardVoided = 0
        and bch.bchIsQuickPick = 1
    group by rdi.ProductItemName, s.StaffId, s.LastName, s.FirstName, rdi.Price;
    
    -- Get all of the Hand picked CBB paper sales
    insert into @Results
    select null,
        rdi.ProductItemName + ' (HP)',
        s.LastName + ', ' + s.FirstName + ' (' + cast(s.StaffID as nvarchar(10)) + ')',
        min(bch.bchMasterCardNo),
        max(bch.bchMasterCardNo),
        '',
        count(bch.bchMasterCardNo),
        rdi.Price
    from RegisterReceipt rr
        join RegisterDetail rd on rr.RegisterReceiptId = rd.RegisterReceiptId
        join SessionPlayed sp on rd.SessionPlayedId = sp.SessionPlayedId
        join RegisterDetailItems rdi on rd.RegisterDetailId = rdi.RegisterDetailId
        --join BingoCardHeader bch on rdi.RegisterDetailItemId = bch.bchRegisterDetailItemId
		JOIN (Select Distinct bchMasterCardNo, bchRegisterDetailItemID, bchIsQuickPick, bchCardVoided From BingoCardHeader) as bch on (bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID)
        join Staff s on rr.StaffId = s.StaffId
    where rr.GamingDate >= @StartDate
        and rr.GamingDate < @EndDate
        and (@OperatorId = 0 or rr.OperatorId = @OperatorId)
        and (@Session = 0 or sp.GamingSession = @Session)
        and rdi.GameTypeId = 4
        and rdi.CardMediaId = 2
        and bch.bchCardVoided = 0
        and bch.bchIsQuickPick = 0
    group by rdi.ProductItemName, s.StaffId, s.LastName, s.FirstName, rdi.Price;
    
    
    --select * from @Results
    
    --select r.MasterTransId, ite.AuditNumber
    --from @Results r
    --    join InvTransactionExceptions ite on (r.MasterTransId = ite.InvMasterTransactionId);

    declare @AuditExceptionMasterTransId int;
    declare @AuditExceptionNumber int;
    declare AuditExceptionsCursor cursor for
    select distinct r.MasterTransId, ite.AuditNumber
    from @Results r
        join InvTransactionExceptions ite on (r.MasterTransId = ite.InvMasterTransactionId);
        
    open AuditExceptionsCursor;
    fetch next from AuditExceptionsCursor into @AuditExceptionMasterTransId, @AuditExceptionNumber;

    while (@@FETCH_STATUS = 0)
    begin
        -- Update all the audit exceptions
        update @Results
        set AuditExceptions = case when len(AuditExceptions) > 0 then AuditExceptions + ', '
                                    else '' end
                               + cast(@AuditExceptionNumber as varchar(10))
        where MasterTransId = @AuditExceptionMasterTransId;
        
        fetch next from AuditExceptionsCursor into @AuditExceptionMasterTransId, @AuditExceptionNumber;
    end

    close AuditExceptionsCursor;
    deallocate AuditExceptionsCursor;
    
    select Product,
        --IssuedTo,
        --AuditStart,
        --AuditEnd,
        --AuditExceptions,
        sum(QuantitySold) as QuantitySold,
        Price,
        sum(QuantitySold) * Price as Value
    from @Results
    group by Product, Price
    
end





GO

