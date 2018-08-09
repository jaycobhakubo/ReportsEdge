USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptExceptionReport]    Script Date: 06/26/2012 13:21:57 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptExceptionReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptExceptionReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptExceptionReport]    Script Date: 06/26/2012 13:21:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[spRptExceptionReport]
	@StartDate		as datetime,
	@EndDate		as datetime,
	@OperatorID		as int,
	@Session		as int
as
set nocount on;

create table #TempExceptions
	(DeviceFee money, 
	 TransactionNumber int,
	 Tax money, 
	 OperatorID int,  
	 PackNumber int, 
	 DTStamp datetime,
	 GamingDate SmallDateTime,
	 UnitNumber smallint,
	 StaffID int, 
	 SaleSuccess bit, 
	 DiscountAmount money,
	 PackageName nvarchar(64),	
	 Quantity smallint, 
	 PackagePrice money, 
	 TransactionTypeID int,
	 QTY smallint, 
	 Price money, 
	 ProductItemName nvarchar(64),
	 RegisterReceiptID int, 
	 RegisterDetailID int, 
	 OriginalReceiptID int, 
	 VoidedRegisterReceiptID int,
	 TransactionType nvarchar(64), 
	 GamingSession tinyint, 
	 SessionPlayedID int, 
	 DTCreated datetime,
	 DTTransfered datetime,
	 VTrans int,
	 TTo smallint,
	 TFrom smallint,
	 VDTStamp datetime,
	 FirstName nvarchar(32),
	 LastName nvarchar(32),
	 VFirst nvarchar(32),
	 VLast nvarchar(32),
	 VGamingDate smallDatetime,
	 VType int,
	 TransTotal money,
	 VTransTotal money,
	 FromDevice nvarchar(32),
	 ToDevice nvarchar(32))

create table #ReceiptTotal
	(zRegisterReceiptID int,
     zTransTotal money,
     zPackNumber int)
  
 --Transfers
declare @RegisterReceiptID int,
	@OriginalReceiptID int

create table #Units
    (xRRID int,
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
     xPackNumber int)

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
	null,
	TransactionNumber,
	DTStamp,
	UnitNumber,
	StaffID,
	DeviceID
from RegisterReceipt
where GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime) 
    and GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)  
    and OperatorID = @OperatorID
    and TransactionTypeID = 14
    and UnitNumber > 0
order by RegisterReceiptID

declare Unit_Cursor cursor for
select xRRID, xOriginalReceiptID from #Units

open Unit_Cursor
fetch next from Unit_Cursor into @RegisterReceiptID, @OriginalReceiptID
while @@fetch_status = 0
begin
	while exists (select * from #Units where xRRID = @OriginalReceiptID)
	begin
		update #Units
		set xVeryFirstRRID = (select xOriginalReceiptID
		                      from #Units
		                      where xRRID = @OriginalReceiptID)
		where xRRID = @RegisterReceiptID

		select @OriginalReceiptID = xOriginalReceiptID
		from #Units
		where xRRID = @OriginalReceiptID
	end

	fetch next from Unit_Cursor into @RegisterReceiptID, @OriginalReceiptID
end

close Unit_Cursor
deallocate Unit_Cursor

--These are the records of a first transfer or only transfer
update #Units
set xVeryFirstRRID = xOriginalReceiptID
where xVeryFirstRRID is null

update #Units
set xFromTransaction = TransactionNumber,
	xFromUnit = UnitNumber,
	xFromDTStamp = DTStamp,
	xTransTotal = 0.00,
	xFromDeviceID = DeviceID,
	xTransferStaffID = StaffID
from #Units
    join RegisterReceipt on xOriginalReceiptID = RegisterReceiptID 
 
insert into #ReceiptTotal
(zRegisterReceiptID, zPackNumber)
select xRRID,  RR.PackNumber 
from #Units 
	join RegisterDetail rd on  xVeryFirstRRID = rd.RegisterReceiptID
	join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
group by xRRID, rr.PackNumber

----Voided Items
insert into #Tempexceptions
		(GamingDate, GamingSession, TransactionNumber, PackNumber, Vtrans,
		 DTStamp, OperatorID, TFrom, TTo, VDTStamp, FirstName, LastName,
		 VFirst, VLast, RegisterReceiptID, DeviceFee, OriginalReceiptID,
		 VGamingDate, UnitNumber, VType, TransactiontypeID, TransTotal,
		 SaleSuccess)
select rrSale.GamingDate, GamingSession, rrSale.TransactionNumber, rrSale.PackNumber,
       rrVoid.Transactionnumber, rrSale.DTStamp, rrSale.OperatorID, rrSale.UnitNumber,
       rrVoid.UnitNumber, rrVoid.DTStamp, sSale.FirstName, sSale.LastName, sVoid.Firstname,
       sVoid.LastName, rrVoid.RegisterReceiptID, rrSale.DeviceFee, rrSale.RegisterReceiptID,
       rrVoid.gamingDate, rrSale.UnitNumber, rrVoid.TransactionTypeID, rrSale.TransactionTypeID,
       ( sum(rd.Quantity * rd.PackagePrice)
       + sum(rd.Quantity * isnull(rd.DiscountAmount,0.00))
       + sum(rd.Quantity * rd.SalesTaxAmt)
       + isnull(rrSale.Devicefee,0)),
		rrSale.SaleSuccess
from RegisterReceipt rrSale
    join RegisterReceipt rrVoid on rrSale.RegisterReceiptID = rrVoid.OriginalReceiptID
    join RegisterDetail rd on rrSale.RegisterReceiptID = rd.RegisterReceiptID 
    join Staff sSale on rrSale.StaffID = sSale.StaffID 
    join (select distinct SessionPlayedID, GamingSession, gamingdate	--Use derived table to
			    from History.dbo.SessionPlayed 		--eliminate UK duplicates
			    ) as sp 
			    on rd.SessionPlayedID = sp.SessionPlayedID
    left join Staff sVoid on rrVoid.StaffID = sVoid.StaffID
where rrVoid.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
    and rrVoid.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
    and rrSale.SaleSuccess = 1
	and rrSale.OperatorID = @OperatorID
	and (@Session = 0 or sp.GamingSession = @Session)
	and rrVoid.TransactiontypeID <> 14 -- Make sure that this isn't a transfer
	and VoidedRegisterReceiptID > 0
group by rrSale.GamingDate, GamingSession, rrSale.TransactionNumber, rrSale.PackNumber,
         rrVoid.Transactionnumber, rrSale.DTStamp, rrSale.OperatorID, rrSale.UnitNumber,
         rrVoid.UnitNumber, rrVoid.DTStamp, sSale.FirstName, sSale.LastName, sVoid.Firstname,
         sVoid.LastName, rrVoid.RegisterReceiptID, rrSale.DeviceFee, rrSale.RegisterReceiptID,
         rrVoid.gamingDate, rrSale.UnitNumber, rrVoid.TransactionTypeID, rrSale.TransactionTypeID,
         rrSale.SaleSuccess, rrSale.RegisterReceiptId

--get Transfers
insert into #TempExceptions
		(TransactionNumber, UnitNumber, PackNumber, VTrans, DTStamp, OperatorID,
		 FromDevice, ToDevice, TFrom, TTo, VDTStamp, FirstName, LastName, VFirst,
		 VLast, OriginalReceiptID, VGamingDate, VType, GamingDate, gamingsession,
		 TransTotal, TransactionTypeID, DeviceFee, SaleSuccess)
select 
	xFromTransaction, rr.UnitNumber, zPackNumber, xToTrans, rr.DTStamp, rr.OperatorID,
	d.DeviceType, d1.DeviceType, xfromUnit, xtoUnit, xDTStamp ,s.FirstName, s.LastName,
	s1.FirstName, s1.LastName, xOriginalReceiptID, rr.GamingDate, rr.TransactionTypeID,
	rr.GamingDate, sp.GamingSession, ( sum(rd.Quantity * rd.PackagePrice)
	                                 + sum(rd.Quantity * isnull(rd.DiscountAmount,0.00))
	                                 + sum(rd.Quantity * rd.SalesTaxAmt)
	                                 + isnull(rrSale.DeviceFee, 0)),
	(select TransactionTypeID from RegisterReceipt where RegisterReceiptID = xOriginalReceiptID),
	rrSale.DeviceFee, rr.SaleSuccess
from RegisterReceipt rr
    join RegisterReceipt rrSale on rr.OriginalReceiptId = rrSale.RegisterReceiptId
    join #Units on rr.RegisterReceiptID = xRRID 
    join RegisterDetail rd on xVeryFirstRRID = RD.RegisterReceiptID 
    join #ReceiptTotal on xRRID = zRegisterReceiptID
    left join Staff s on xTransferStaffID = s.StaffID 
    left join Staff s1 on xStaffID = s1.StaffID
    left join Device d on rr.DeviceID = d.DeviceID
    left join Device d1 on xDeviceid = d1.DeviceID
    left join (select distinct SessionPlayedID, GamingSession, GamingDate	--Use derived table to
			    from SessionPlayed (nolock)		--eliminate UK duplicates
			    ) as sp
			    on rd.SessionPlayedID = sp.SessionPlayedID
where(@Session = 0 or sp.GamingSession = @Session) 
group by xFromTransaction, rr.UnitNumber, zPackNumber, xToTrans, rr.DTStamp, rr.OperatorID,
        d.DeviceType, d1.DeviceType, xfromUnit, xtoUnit, xDTStamp, s.FirstName, s.LastName,
        s1.FirstName, s1.LastName, xOriginalReceiptID, rr.GamingDate, xVeryFirstRRID,
        rr.TransactionTypeID, rr.GamingDate, sp.GamingSession, rr.SaleSuccess, rrSale.devicefee
        
-- Update the Unit numbers for the void transactions
declare LastUnit_cursor cursor for
select RegisterReceiptId, OriginalReceiptId from #TempExceptions where VType = 2

open LastUnit_cursor
fetch next from LastUnit_cursor into @RegisterReceiptId, @OriginalReceiptId
while @@fetch_status = 0
begin
    update #TempExceptions
    set TTo = (select case when nullif(rrXfer.UnitNumber, 0) is not null then rrXfer.UnitNumber
                    when nullif(ul.ulUnitNumber,0) is not null then ul.ulUnitNumber
                    when nullif(m.UnitNumber,0) is not null then m.UnitNumber
                    when nullif(m.MachineId,0) is not null then m.MachineId       
                    else rrSale.UnitNumber end
            from RegisterReceipt rrSale
                left join RegisterReceipt rrXfer on 
                    (rrSale.RegisterReceiptId = rrXfer.OriginalReceiptId and rrXfer.TransactionTypeId = 14)                    
                left join UnlockLog ul on rrSale.RegisterReceiptId = ul.ulRegisterReceiptId
                left join Machine m on ul.ulSoldToMachineId = m.MachineId
            where rrSale.RegisterReceiptId = @OriginalReceiptId
                and ul.ulId = (select max(ulId) from UnlockLog where ulRegisterReceiptid = rrSale.RegisterReceiptid))
    where RegisterReceiptId = @RegisterReceiptId

    fetch next from LastUnit_cursor into @RegisterReceiptId, @OriginalReceiptId
end

close LastUnit_cursor 
deallocate LastUnit_cursor

select * from #TempExceptions
Drop Table #TempExceptions
Drop Table #Units
Drop Table #ReceiptTotal

SET NOCOUNT OFF





GO

