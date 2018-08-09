USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptUnitTransfers]    Script Date: 01/09/2012 15:19:39 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptUnitTransfers]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptUnitTransfers]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptUnitTransfers]    Script Date: 01/09/2012 15:19:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spRptUnitTransfers]
	@OperatorID as int,
	@StartDate as smalldatetime,
	@EndDate as smalldatetime,
	@Session as int
AS
SET NOCOUNT ON

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
	xToUnit smallint,
	xStaffID int,
	xFromDeviceID int,
	xDeviceID int,
	xFromTransaction int,
	xTransTotal money,
	xOriginalStaffID int,
	xTransferStaffID int,
	xTransactionTypeID int,
);

insert #Units (
	xRRID,
	xOriginalReceiptID,
	xVeryFirstRRID,
	xToTrans,
	xDTStamp,
	xToUnit,
	xStaffID,
	xDeviceID)
select RegisterReceiptID,
	OriginalReceiptID,
	NULL,
	TransactionNumber,
	DTStamp,
	UnitNumber,
	StaffID,
	DeviceID
from RegisterReceipt
WHERE 
(GamingDate >= @StartDate and GamingDate <= @EndDate)
and (@OperatorID = 0 or OperatorID = @OperatorID)
and (TransactionTypeID = 14)
and (UnitNumber > 0)
order by RegisterReceiptID;

Declare Unit_Cursor CURSOR local fast_forward FOR
select xRRID, xOriginalReceiptID from #Units;

OPEN Unit_Cursor
FETCH NEXT FROM Unit_Cursor INTO @RegisterReceiptID, @OriginalReceiptID;
WHILE @@FETCH_STATUS = 0
BEGIN
	WHILE exists (select * from #Units where xRRID = @OriginalReceiptID)
	BEGIN
		update #Units
		set xVeryFirstRRID = (select xOriginalReceiptID from #Units where xRRID = @OriginalReceiptID)
		where xRRID = @RegisterReceiptID;

		select @OriginalReceiptID = xOriginalReceiptID
		from #Units 
		where xRRID = @OriginalReceiptID
	END

	FETCH NEXT FROM Unit_Cursor INTO @RegisterReceiptID, @OriginalReceiptID;
END

CLOSE Unit_Cursor;
DEALLOCATE Unit_Cursor;

--These are the records of a first transfer or only transfer
update #Units
set xVeryFirstRRID = xOriginalReceiptID
where xVeryFirstRRID IS NULL;
 
update #Units
set xFromTransaction = TransactionNumber,
	xFromUnit = UnitNumber,
	xFromDTStamp = DTStamp,
	xTransTotal = 0.00,
	xFromDeviceID = DeviceID,
	xTransferStaffID = StaffID
From #Units 
Join RegisterReceipt  on xOriginalReceiptID = RegisterReceiptID;

Create Table #ReceiptTotal
	(zRegisterReceiptID int,
     zTransTotal money,
     zPackNumber int)
    Insert into #ReceiptTotal
    (zRegisterReceiptID, zTranstotal, zPackNumber)
    Select xRRID, (SUM(rd.Quantity * rd.PackagePrice) + SUM(rd.Quantity * Isnull(rd.DiscountAmount,0.00)) +
		SUM(rd.Quantity * rd.SalesTaxAmt)), RR.PackNumber 
	From #Units 
	Join RegisterDetail rd on  xVeryFirstRRID = rd.RegisterReceiptID
	Join RegisterReceipt RR on rd.RegisterReceiptID = RR.RegisterReceiptID
	Group By xRRID, rr.PackNumber;
	

	
--  The FromDevice and To Device are backwards.  This is due to a report issue that prints them backwards.
SELECT DISTINCT
	xFromTransaction as TransactionNumber, UnitNumber, RR.SoldToMachineID, zPackNumber as PackNumber, D.DeviceType as FromDevice,
	D1.DeviceType as ToDevice, (select DTStamp from RegisterReceipt where RegisterReceiptID = xOriginalReceiptID) as DTStamp,
    Left(UPPER(S.FirstName),1) + ' ' +S.LastName as SoldStaffName,
	RR.OperatorID,  SP.GamingDate, 	xFromUnit as FromUnitNumber,
	xToTrans as ToTrans,
	xFromTransaction as FromTransaction	
	, xDTStamp      [ToDTStamp]         -- New Crystal runtime disallows same name fields in resultset
	, xToUnit       [ToUnitNumber]
    , Left(UPPER(S1.FirstName),1) + ' ' + S1.LastName as ByStaffName
	, SP.GamingSession,	
	zTransTotal as Transtotal
FROM RegisterReceipt RR 
Join #Units  on RR.RegisterReceiptID = xRRID 
JOIN RegisterDetail RD  ON xVeryFirstRRID = RD.RegisterReceiptID 
Join #ReceiptTotal  on xRRID = zRegisterReceiptID
--left JOIN Staff S  ON RR.StaffID = S.StaffID 
left JOIN Staff S  ON xTransferStaffID = S.StaffID 
--Left Join Staff S1  on xStaffID = S1.StaffID
Left Join Staff S1  on xStaffID = S1.StaffID
left JOIN Device D  ON xDeviceid = D.DeviceID --RR.DeviceID=D.DeviceID
Left Join Device D1  on xFromDeviceID = D1.DeviceID
left Join (select distinct SessionPlayedID, GamingSession, GamingDate	--Use derived table to
			from History.dbo.SessionPlayed 		--eliminate UK duplicates
			) as SP 
			on RD.SessionPlayedID = SP.SessionPlayedID
WHERE (@Session = 0 or SP.GamingSession = @Session);


drop table #Units;
drop table #receiptTotal;
SET NOCOUNT OFF



GO


