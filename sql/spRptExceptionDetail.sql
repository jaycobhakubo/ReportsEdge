USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptExceptionDetail]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptExceptionDetail]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[spRptExceptionDetail]
-- ============================================================================
-- Author:		Barry Silver
-- Description:	Show various exceptions and voids.
-- Group by exception type: (Sales, Banks, Payouts, Other, etc.)
--
-- 2011.12.02 bjs: New NGCB report
-- 2012.01.06 bsb:DE9671 added payout void for check, merchandise, other, credit
-- 2012.01.17 jkn:DE9942 Added device fees in the calculations of sales and sale voids
-- 2012.02.06 bsb: DE9952 Added unit transfers, failed sales
-- 2012.05.14 knc: DE10388 UnitNumber and Serial Number Not showing
-- 2012.05.15 knc: DE10387 Fixed Final Time  + fixed Staff ID on Final transaction Transfer
-- 2012.06.28 jkn: DE10457 Fixed issue with determining what units
--                  were involved in transfers and voids
-- 2014.02.27 tmp: US3067 Return bank transactions made to a previous gaming date by gaming date
--	               or transaction date.
-- 2014.10.31 tmp: US3736/US3738 Added points adjustment. 
-- ============================================================================
	@OperatorID		as int,
	@StartDate		as datetime,
	@EndDate		as datetime,
	@Session		as int

as
begin

set nocount on;

declare @Exceptions table
(
	OperatorID int,  
    ExceptionType nvarchar(20), 
	OrigTime datetime,
    OrigSession int,
    OrigSessionHistory int,
	OrigStaffName nvarchar(64),
	OrigTrans nvarchar(64),
    OrigTransType nvarchar(64),
    OrigUnit int,
    OrigSerialNumber nvarchar(128),
    OrigValue money,
    OrigPoints money,	-- US3738
	FinalTime datetime,
    FinalSession int,
	FinalStaffName nvarchar(64),
	FinalTrans nvarchar(64),
    FinalTransType nvarchar(64),
    FinalUnit int,
    FinalSerialNumber nvarchar(128),
    FinalValue money,
    FinalPoints money	-- US3738
);


Create Table #ReceiptTotal
	(zRegisterReceiptID int,
     zTransTotal money,
     zPackNumber int)
  
 --Transfers
Declare @RegisterReceiptID int,
	@OriginalReceiptID int

create table #Units (
	xRRID int,
	xOriginalReceiptID int,
	xVeryFirstRRID int,
	xToTrans int,
	xDTStamp datetime,
	xFromDTStamp datetime,
	xFromUnit int,
	xFromSerialNumber int,
	xToUnit smallint,
	xToSerialNumber int,
	xStaffID int,
	xFromDeviceID int,
	xDeviceID int,
	xFromTransaction int,
	xTransTotal money,
	xOriginalStaffID int,
	xTransferStaffID int,
	xTransactionTypeID int,
	xPackNumber int
)

insert #Units (
	xRRID,
	xOriginalReceiptID,
	xVeryFirstRRID,
	xToTrans,
	xDTStamp,
	xToUnit,
	xToSerialNumber, 
	xStaffID,
	xDeviceID)
select RegisterReceiptID,
	OriginalReceiptID,
	NULL,
	TransactionNumber,
	DTStamp,
	UnitNumber,
	UnitSerialNumber,
	StaffID,
	DeviceID
from RegisterReceipt (nolock)
WHERE GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
and GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
and OperatorID = @OperatorID
and TransactionTypeID = 14
and UnitNumber > 0
order by RegisterReceiptID


Declare Unit_Cursor CURSOR FOR
select xRRID, xOriginalReceiptID from #Units (nolock)

OPEN Unit_Cursor
FETCH NEXT FROM Unit_Cursor INTO @RegisterReceiptID, @OriginalReceiptID
WHILE @@FETCH_STATUS = 0
BEGIN
	WHILE exists (select * from #Units (nolock) where xRRID = @OriginalReceiptID)
	BEGIN
		update #Units
		set xVeryFirstRRID = (select xOriginalReceiptID from #Units (NOLOCK)
						where xRRID = @OriginalReceiptID)
		where xRRID = @RegisterReceiptID

		select @OriginalReceiptID = xOriginalReceiptID
		from #Units (NOLOCK)
		where xRRID = @OriginalReceiptID
	END

	FETCH NEXT FROM Unit_Cursor INTO @RegisterReceiptID, @OriginalReceiptID
END

CLOSE Unit_Cursor
DEALLOCATE Unit_Cursor


--These are the records of a first transfer or only transfer
update #Units
set xVeryFirstRRID = xOriginalReceiptID
where xVeryFirstRRID IS NULL

 


Update #Units
set xFromTransaction = TransactionNumber,
	xFromUnit = UnitNumber,
	xFromSerialNumber = UnitSerialNumber,
	xFromDTStamp = DTStamp,
	xTransTotal = 0.00,
	xFromDeviceID = DeviceID,
	--xTransferStaffID = StaffID -- xxx knc 5/15/2012
	xOriginalStaffID = StaffID 
From #Units (nolock)
Join RegisterReceipt (nolock) on xOriginalReceiptID = RegisterReceiptID 
 



Insert into #ReceiptTotal
    (zRegisterReceiptID, zPackNumber)
    Select xRRID,  RR.PackNumber 
	From #Units (nolock)
	Join RegisterDetail rd on  xVeryFirstRRID = rd.RegisterReceiptID
	Join RegisterReceipt RR on rd.RegisterReceiptID = RR.RegisterReceiptID
	Group By xRRID, rr.PackNumber



-- remove?
--Update #Units set xPackNumber = zPackNumber
--From #ReceiptTotal where zRegisterReceiptID = xVeryFirstRRID
--Select * from #Units
--debug
--select * from #Units
--select * from #ReceiptTotal


----------------------------------------------------------------------
-- Sales Voids
insert into @Exceptions
(
	OperatorID,  
    ExceptionType, 
	OrigTime,
    OrigSession,
    OrigSessionHistory,       
	OrigStaffName,
	OrigTrans,
    OrigTransType,
    OrigUnit ,--DE10388 /5.14.2012
    OrigSerialNumber ,--DE10388 /5.14.2012
    OrigValue,
	OrigPoints, -- US3738
	FinalTime,
    FinalSession,
	FinalStaffName,
	FinalTrans,
    FinalTransType,
    FinalUnit ,
    FinalSerialNumber, 
    FinalValue,
    FinalPoints -- US3738
)
select 
    rr.OperatorID
    , 'Sales Exceptions'
    , rr.DTStamp                   -- show original transaction time etc
    , isnull(sp.GamingSession, 0)
    , isnull(hsp.GamingSession, 0)
    , s.LastName + ', ' + s.FirstName + ' (' + convert(nvarchar(10), s.StaffID) + ')'
    , rr.TransactionNumber
    , tt.TransactionType
    , dbo.GetLastUnitNumberByTransaction(rr.TransactionNumber)
    , dbo.GetLastUnitSerialNumberByTransaction(rr.TransactionNumber)
    --, rr.UnitNumber
    --, rr.UnitSerialNumber 
    -- sum the original amounts
    , (sum(isnull(rd.Quantity, 0) * isnull(rd.PackagePrice, 0)) 
     + sum(isnull(rd.Quantity, 0) * isnull(rd.DiscountAmount, 0)) 
     + sum(isnull(rd.Quantity, 0) * isnull(rd.SalesTaxAmt, 0))
     + isnull(rr.DeviceFee, 0)) --DE9942
    , SUM(isnull(rd.TotalPtsEarned, 0)) - SUM(isnull(rd.TotalPtsRedeemed, 0)) -- US3738
    , rr2.DTStamp                   -- voided/returned "final" transaction time etc
    , isnull(sp2.GamingSession, 0)
    , s2.LastName + ', ' + s2.FirstName + ' (' + convert(nvarchar(10), s2.StaffID) + ')'
    , rr2.TransactionNumber
    , tt2.TransactionType
    , dbo.GetLastUnitNumberByTransaction(rr2.TransactionNumber)
    , dbo.GetLastUnitSerialNumberByTransaction(rr2.TransactionNumber)
    
--rr.UnitNumber ,--DE10388|kc|5/14/2012 its the same as the original one
--rr.UnitSerialNumber --DE10388|kc|5/14/2012 its the same as the original one
    -- From original report: final transaction values are null so original value * -1 instead for all voids otherwise use original value.
    , case 
        when tt2.TransactionTypeId = 2
        then
        (-1.0 * ((sum(isnull(rd.Quantity, 0) * isnull(rd.PackagePrice, 0)) 
        + sum(isnull(rd.Quantity, 0) * isnull(rd.DiscountAmount, 0)) 
        + sum(isnull(rd.Quantity, 0) * isnull(rd.SalesTaxAmt, 0)))
        + isnull(rr.DeviceFee, 0))) --DE9942
        else 
        (sum(isnull(rd.Quantity, 0) * isnull(rd.PackagePrice, 0)) 
        + sum(isnull(rd.Quantity, 0) * isnull(rd.DiscountAmount, 0)) 
        + sum(isnull(rd.Quantity, 0) * isnull(rd.SalesTaxAmt, 0))
        + isnull(rr.DeviceFee, 0)) --DE9942
     end
   , case -- US3738
        when tt2.TransactionTypeId = 2
        then (-1.0 * (SUM(isnull(rd.TotalPtsEarned, 0)) - SUM(isnull(rd.TotalPtsRedeemed, 0))))
        Else SUM(isnull(rd.TotalPtsEarned, 0)) - SUM(isnull(rd.TotalPtsRedeemed, 0))
   End  -- US3738
FROM 
-- original transaction
RegisterReceipt rr                                                     
join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID 
join TransactionType tt on rr.TransactionTypeID = tt.TransactionTypeID
left join Staff s on rr.StaffID = s.StaffID 
left join (select distinct SessionPlayedID, GamingSession, gamingdate	--Use derived table to eliminate duplicates
		    from SessionPlayed ) as sp
			on rd.SessionPlayedID = sp.SessionPlayedID
left join (select distinct SessionPlayedID, GamingSession, gamingdate	--Use derived table to eliminate duplicates (some older trans are in history only)
		    from History.dbo.SessionPlayed ) as hsp
			on rd.SessionPlayedID = hsp.SessionPlayedID
-- final transaction
left join RegisterReceipt rr2 on rr.RegisterReceiptID = rr2.OriginalReceiptID    -- points to the original receipt
left join RegisterDetail rd2 on rr2.RegisterReceiptID = rd2.RegisterReceiptID 
left join TransactionType tt2 on rr2.TransactionTypeID = tt2.TransactionTypeID
left join Staff s2 on rr2.StaffID = s2.StaffID
left join (select distinct SessionPlayedID, GamingSession, gamingdate	--Use derived table to eliminate duplicates
			from SessionPlayed ) as sp2
			on rd2.SessionPlayedID = sp2.SessionPlayedID

Where 
    (rr.GamingDate >= @StartDate and rr.GamingDate <= @EndDate)     -- only filter on original transaction!
and rr.SaleSuccess = 1
and (@OperatorID = 0 or rr.OperatorID = @OperatorID)
and (@Session = 0 or (hsp.GamingSession = @Session or sp.GamingSession = @Session) )  -- Tricky here since some older recs have been archived
and rr.TransactiontypeID <> 14          -- omit transfers
and rr2.TransactionTypeId <> 14
and rd.VoidedRegisterReceiptID > 0      -- only voids

group by
   rr.OperatorID, rr.DTStamp, sp.GamingSession, hsp.GamingSession, s.LastName, s.FirstName, s.StaffID
  ,rr.TransactionNumber, tt.TransactionType, rr2.DTStamp, sp2.GamingSession, s2.LastName, s2.FirstName
  ,s2.StaffID, rr2.TransactionNumber, tt2.TransactionType, rr.DeviceFee, rr.UnitNumber,rr.UnitSerialNumber
  ,rr2.UnitNumber, rr2.UnitSerialNumber, tt2.TransactionTypeId



----------------------------------------------------------------------------------------------------------------------------------------
-- TRANSFERS
insert into @Exceptions
(   OperatorID,
    ExceptionType,
    OrigTime,
    OrigSession,
    OrigSessionHistory,
	OrigStaffName,
	OrigTrans,
    OrigTransType,
    OrigUnit,
    OrigSerialNumber,
    OrigValue,
    FinalTime ,
    FinalStaffName,
    FinalTrans,
    FinalTransType, 
    FinalUnit,
    FinalSerialNumber ,
    FinalValue
)
SELECT  rrOrig.OperatorID
    , 'Sales Exceptions'
    , rrOrig.DTStamp
    , isnull(sp.GamingSession, 0)
    , isnull(hsp.GamingSession, 0)
    , sOrig.LastName + ', ' + sOrig.FirstName + ' (' + convert(nvarchar(10), sOrig.StaffID) + ')'
    , rrOrig.TransactionNumber
    , ttOrig.TransactionType
    , dbo.GetLastUnitNumberByTransaction(rrOrig.TransactionNumber)
    , dbo.GetLastUnitSerialNumberByTransaction(rrOrig.TransactionNumber)
    , case when rrOrig.TransactionTypeId = 14 then 0.00
        else-- sum the original amounts
         (sum(isnull(rdOrig.Quantity, 0) * isnull(rdOrig.PackagePrice, 0)) 
         + sum(isnull(rdOrig.Quantity, 0) * isnull(rdOrig.DiscountAmount, 0)) 
         + sum(isnull(rdOrig.Quantity, 0) * isnull(rdOrig.SalesTaxAmt, 0))
         + isnull(rrOrig.DeviceFee, 0)) --DE9942
         end
    , rrFinal.DTStamp
    , sFinal.LastName + ', ' + sFinal.FirstName + ' (' + convert(nvarchar(10), sFinal.StaffID) + ')'
    , rrFinal.TransactionNumber
    , ttFinal.TransactionType
    , dbo.GetLastUnitNumberByTransaction(rrFinal.TransactionNumber)
    , dbo.GetLastUnitSerialNumberByTransaction(rrFinal.TransactionNumber)
    -- From original report: final transaction values are null so original value * -1 instead for all voids otherwise use original value.
    , 0.0
    
FROM RegisterReceipt rrFinal
    left join RegisterReceipt rrOrig on rrFinal.OriginalReceiptId = rrOrig.RegisterReceiptId
    left join RegisterDetail rdOrig on rdOrig.RegisterReceiptID = rrOrig.RegisterReceiptId
    left join TransactionType ttOrig on rrOrig.TransactionTypeID = ttOrig.TransactionTypeID        -- orig trans
    left join Staff sOrig on rrOrig.StaffId = sOrig.StaffId
    
    left join TransactionType ttFinal on rrFinal.TransactionTypeID = ttFinal.TransactionTypeID       -- final trans    
    left join Staff sFinal on rrFinal.StaffId = sFinal.StaffID
    --left join Device d on rr.DeviceID = d.DeviceID
    --Left join Device d1 on xDeviceid = d1.DeviceID
    left join (select distinct SessionPlayedID, GamingSession, GamingDate	--Use derived table to eliminate UK duplicates
			    from SessionPlayed) as sp
			    on rdOrig.SessionPlayedID = sp.SessionPlayedID
    left join (select distinct SessionPlayedID, GamingSession, gamingdate	--Use derived table to eliminate duplicates  (some older trans are in history only)
		        from History.dbo.SessionPlayed ) as hsp
			    on rdOrig.SessionPlayedID = hsp.SessionPlayedID
			
where (@Session = 0 or (hsp.GamingSession = @Session or sp.GamingSession = @Session) )  -- Tricky here since some older recs have been archived
       and (@OperatorID = 0 or rrOrig.OperatorID = @OperatorID)
       and rrOrig.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
       and rrOrig.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
       and rrFinal.TransactionTypeId = 14

group by rrOrig.OperatorID
    , sp.GamingSession
    , hsp.GamingSession
    , sOrig.LastName
    , sOrig.FirstName
    , sOrig.StaffID
    , sp.GamingSession
    , hsp.GamingSession
    , ttOrig.TransactionType
    , rrOrig.TransactionTypeID
    , ttFinal.TransactionType
    , rrOrig.DeviceFee
    , sFinal.LastName
    , sFinal.FirstName
    , sFinal.StaffID
    , rrOrig.DTStamp
    , rrOrig.TransactionNumber
    , rrFinal.DTStamp
    , rrFinal.TransactionNumber
    
-------------------------------------------------------------------------------------------
-- Payout voids

insert into @Exceptions
(
	OperatorID,  
    ExceptionType, 
	OrigTime,
    OrigSession,
	OrigStaffName,
	OrigTrans,
    OrigTransType,
    OrigValue,
	
	FinalTime,
	FinalStaffName,
	FinalTrans,
    FinalTransType
    , FinalValue
)
select 
  pt.OperatorID, 'Payout Exceptions'
, pt.DTStamp
, isnull(sp.GamingSession, 0) [Session]
, s.LastName + ', ' + s.FirstName + ' (' + convert(nvarchar(10), s.StaffID) + ')' [Orig Staff]
, pt.PayoutTransNumber
, tt.TransactionType -- orig transaction
, (isnull(orig.DefaultAmount, 0)+ISNULL(ptdm.PayoutValue,0) +ISNULL(ptdc.CheckAmount,0)+ISNULL(ptdo.PayoutValue,0)+ isnull(ptdcr.Refundable,0) +isnull(ptdcr.NonRefundable,0)) [Payout]

, pt2.DTStamp
, s2.LastName + ', ' + s2.FirstName + ' (' + convert(nvarchar(10), s2.StaffID) + ')' [Final Staff]
, pt2.PayoutTransNumber
, tt2.TransactionType
, -1 * (isnull(orig.DefaultAmount, 0)+ISNULL(ptdm.PayoutValue,0) +ISNULL(ptdc.CheckAmount,0)+ISNULL(ptdo.PayoutValue,0)+ isnull(ptdcr.Refundable,0) +isnull(ptdcr.NonRefundable,0) ) [Payout Void Amount]


from PayoutTrans pt -- original trans
left join PayoutTrans pt2 on pt.VoidTransID = pt2.PayoutTransID
join TransactionType tt on pt.TransTypeID = tt.TransactionTypeID
join TransactionType tt2 on pt2.TransTypeID = tt2.TransactionTypeID
left join PayoutTransDetailCash orig on pt.PayoutTransID = orig.PayoutTransID
left join PayoutTransDetailMerchandise ptdm on pt.PayoutTransID = ptdm.PayoutTransID
left join PayoutTransDetailCheck ptdc on pt.PayoutTransID = ptdc.PayoutTransID
left join PayoutTransDetailCredit ptdcr on pt.PayoutTransID = ptdc.PayoutTransID
left join PayoutTransDetailOther ptdo on pt.PayoutTransID = ptdo.PayoutTransID
join Staff s on pt.StaffID = s.StaffID
join Staff s2 on pt2.StaffID = s2.StaffID
left join PayoutTransBingoGame bg on pt.PayoutTransID = bg.PayoutTransID
left join SessionPlayed sp on bg.SessionPlayedID = sp.SessionPlayedID

where pt.VoidTransID is not null 
	  and (@OperatorID = 0 or pt.OperatorID = @OperatorID)
	  and  pt.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
      and pt.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
      and (@Session = 0 or ( sp.GamingSession = @Session) )   ;

--------------------------------------------------------------------
-- Bank Voids
insert into @Exceptions
(
	OperatorID,  
    ExceptionType, 
	OrigTime,
    OrigSession,
	OrigStaffName,
	OrigTrans,
    OrigTransType,
    OrigValue,	
	FinalTime,
	FinalStaffName,
	FinalTrans,
    FinalTransType
    , FinalValue
)
select
  case when b.bkoperatorid is null then b2.bkOperatorID else b.bkOperatorID end
, 'Bank Exceptions'
, original.ctrCashTransactionDate [Orig]
, original.ctrGamingSession
, s.LastName + ', ' + s.FirstName + ' (' + convert(nvarchar(10), s.StaffID) + ')'
, b.bkBankName
, tt.TransactionType
, isnull(SUM(origdtl.ctrdDefaultTotal),0) [Orig]

, final.ctrCashTransactionDate [Final]
, s2.LastName + ', ' + s2.FirstName + ' (' + convert(nvarchar(10), s2.StaffID) + ')' [Final Staff]
, b2.bkBankName
, tt2.TransactionType
, -1 * isnull(SUM(origdtl.ctrdDefaultTotal),0) [Final]

from CashTransaction final    -- final transaoriginalion 
left join CashTransaction original on final.ctrOriginalCashTransactionID = original.ctrCashTransactionID
left join TransactionType tt on original.ctrTransactionTypeID = tt.TransactionTypeID 
left join TransactionType tt2 on final.ctrTransactionTypeID = tt2.TransactionTypeID 
left join CashTransactionDetail origdtl on original.ctrCashTransactionID = origdtl.ctrdCashTransactionID
left join Bank b on original.ctrSrcBankID = b.bkBankID
left join Bank b2 on original.ctrDestBankID = b2.bkBankID
left join Staff s on original.ctrTransactionStaffID = s.StaffID
left join Staff s2 on final.ctrTransactionStaffID = s2.StaffID

where ((Convert(Date, final.ctrCashTransactionDate) >= @StartDate and Convert(Date, final.ctrCashTransactionDate) <= @EndDate)       --Filter by transaction date and by gaming date.
or (CONVERT(Date, original.ctrCashTransactionDate) >= @StartDate and CONVERT(Date, original.ctrCashTransactionDate) <= @EndDate))      
and (@OperatorID = 0 or b2.bkOperatorID = @OperatorID or b.bkOperatorID = @OperatorID)  -- depending on source and destination some ops will be null
and (@Session = 0 or original.ctrGamingSession = @Session)
Group by origdtl.ctrdCashTransactionID,b.bkoperatorid, b2.bkOperatorID ,original.ctrCashTransactionDate,
        original.ctrGamingSession,b.bkBankName,tt.TransactionType,final.ctrCashTransactionDate,
        b2.bkBankName,tt2.TransactionType,s.LastName,s.FirstName,s2.LastName,s2.FirstName,s.StaffID,s2.StaffID

order by original.ctrCashTransactionDate;



---------------------------------------------------------------------------------
--------Sale Failed
insert into @Exceptions
(
	OperatorID,  
    ExceptionType, 
	OrigTime,
    OrigSession,
    OrigSessionHistory,       
	OrigStaffName,
	OrigTrans,
    OrigTransType,
    OrigUnit,
    OrigSerialNumber,
    OrigValue,
	OrigPoints,	-- US3738
	FinalTime,
    FinalSession,
	FinalStaffName,
	FinalTrans,
    FinalTransType,
    FinalUnit,
    FinalSerialNumber ,
    FinalValue,
	FinalPoints	-- US3738
)
select 
    rr.OperatorID
    , 'Sales Exceptions'
    , rr.DTStamp                   -- show original transaction time etc
    , isnull(sp.GamingSession, 0)
    , isnull(hsp.GamingSession, 0)
    , s.LastName + ', ' + s.FirstName + ' (' + convert(nvarchar(10), s.StaffID) + ')'
    , rr.TransactionNumber
    , tt.TransactionType
    ,rr.UnitNumber 
    ,rr.UnitSerialNumber 
    -- sum the original amounts
    , (sum(isnull(rd.Quantity, 0) * isnull(rd.PackagePrice, 0)) 
     + sum(isnull(rd.Quantity, 0) * isnull(rd.DiscountAmount, 0)) 
     + sum(isnull(rd.Quantity, 0) * isnull(rd.SalesTaxAmt, 0))
     + isnull(rr.DeviceFee, 0)) --DE9942
    , SUM(isnull(rd.TotalPtsEarned, 0)) - SUM(isnull(rd.TotalPtsRedeemed, 0)) -- US3738
    , rr2.DTStamp                   -- voided/returned "final" transaction time etc
    , isnull(sp2.GamingSession, 0)
    , s2.LastName + ', ' + s2.FirstName + ' (' + convert(nvarchar(10), s2.StaffID) + ')'
    , rr2.TransactionNumber
    , 'Sale Failed'
,rr.UnitNumber 
    ,rr.UnitSerialNumber 
    -- From original report: final transaction values are null so original value * -1 instead for all voids otherwise use original value.
    , (-1.0 * ((sum(isnull(rd.Quantity, 0) * isnull(rd.PackagePrice, 0)) 
        + sum(isnull(rd.Quantity, 0) * isnull(rd.DiscountAmount, 0)) 
        + sum(isnull(rd.Quantity, 0) * isnull(rd.SalesTaxAmt, 0)))
        + isnull(rr.DeviceFee, 0))) --DE9942
    , (-1.0 * (SUM(isnull(rd.TotalPtsEarned, 0)) - SUM(isnull(rd.TotalPtsRedeemed, 0)))) -- US3738
FROM 
-- original transaction
RegisterReceipt rr                                                     
join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID 
join TransactionType tt on rr.TransactionTypeID = tt.TransactionTypeID
left join Staff s on rr.StaffID = s.StaffID 
left join (select distinct SessionPlayedID, GamingSession, gamingdate	--Use derived table to eliminate duplicates
		    from SessionPlayed ) as sp
			on rd.SessionPlayedID = sp.SessionPlayedID
left join (select distinct SessionPlayedID, GamingSession, gamingdate	--Use derived table to eliminate duplicates (some older trans are in history only)
		    from History.dbo.SessionPlayed ) as hsp
			on rd.SessionPlayedID = hsp.SessionPlayedID

-- final transaction
left join RegisterReceipt rr2 on rr.RegisterReceiptID = rr2.OriginalReceiptID    -- points to the original receipt
left join RegisterDetail rd2 on rr2.RegisterReceiptID = rd2.RegisterReceiptID 
left join TransactionType tt2 on rr2.TransactionTypeID = tt2.TransactionTypeID
left join Staff s2 on rr2.StaffID = s2.StaffID
left join (select distinct SessionPlayedID, GamingSession, gamingdate	--Use derived table to eliminate duplicates
			from SessionPlayed ) as sp2
			on rd2.SessionPlayedID = sp2.SessionPlayedID

Where 
    (rr.GamingDate >= @StartDate and rr.GamingDate <= @EndDate)     -- only filter on original transaction!
and rr.SaleSuccess = 0
and (@OperatorID = 0 or rr.OperatorID = @OperatorID)
and (@Session = 0 or (hsp.GamingSession = @Session or sp.GamingSession = @Session) )  -- Tricky here since some older recs have been archived


group by
  rr.OperatorID, rr.DTStamp
  , sp.GamingSession, hsp.GamingSession, s.LastName, s.FirstName, s.StaffID
  , rr.TransactionNumber
  , tt.TransactionType
, rr2.DTStamp
, sp2.GamingSession, s2.LastName, s2.FirstName, s2.StaffID
, rr2.TransactionNumber
, tt2.TransactionType
, rr.DeviceFee --DE9942
    ,rr.UnitNumber 
    ,rr.UnitSerialNumber 
    ,rr.UnitNumber 
    ,rr.UnitSerialNumber 


select * from @Exceptions order by ExceptionType, OrigTime, FinalTime

Drop Table #Units
Drop Table #ReceiptTotal


end;

set nocount off














GO

