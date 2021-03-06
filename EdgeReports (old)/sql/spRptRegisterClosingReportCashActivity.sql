USE [Daily]
GO
/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportCashActivity]    Script Date: 06/19/2012 08:30:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 ALTER PROCEDURE [dbo].[spRptRegisterClosingReportCashActivity]
 (
 -- =============================================
-- Author:		Barry Silver
-- Description:	Receipt style closing report
--				Show Bank balances.
--
-- 06/24/2011 bjs: implicit drops (close becomes a drop)
-- 06/30/0211 bjs: show session 0 activity in other sessions
-- 2011.07.05 bjs: DE8480 cash activity subrpt drops should match cash activity rpt
-- 2011.07.07 bjs: DE8480 POS mode: staff bank issues only, MACHINE mode: master bank issues only
-- 2011.07.20 bjs: Mohawk Beta fix for Session=NA
-- 2011.11.08 bsb: DE9626 dispaly bank even if it's 0.00
-- =============================================

 @OperatorId  as int,
 @StartDate as datetime,
 @EndDate  as datetime,
 @StaffID  as int,
 @Session  as int,
 @MachineID as int

)
 as 
 begin


 -- Verfify POS sending valid values
set @StaffID = isnull(@StaffID, 0);
set @Session = isnull(@Session, 0);
set @MachineID = isnull(@MachineID, 0);


declare @ClosingResults  table
(
    GamingDate DATETIME,
    staffIdNbr          int,
    staffLastName       NVARCHAR(64),
    staffFirstName      NVARCHAR(64),
	sessionNbr          int,
	soldFromMachineId   int,
    BanksIssuedTo MONEY,
    BanksIssuedFrom MONEY,
    DropsTo MONEY,
    DropsFrom MONEY
);

-------------------------------------------------------
-- Banks
-------------------------------------------------------

declare @CashMethod int;
select @CashMethod = CashMethodID from Operator
where OperatorID = @OperatorID;

-- FIX DE8853
-- Money Center mode have true Master and Staff Banks.  Show only staff banks here (original code).
if(@CashMethod = 3)
begin

-- Get banks issued to our staff member
INSERT INTO @ClosingResults
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedTo
)
SELECT ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineID,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0))
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	AND bkBankTypeID = 2
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;

-- Get banks issued from our staff member
INSERT INTO @ClosingResults
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedFrom
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineId,
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	AND bkBankTypeID = 2
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;

-- Get banks dropped to our staff member
INSERT INTO @ClosingResults
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	DropsTo
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineID,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0))
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN ( 20, 29) -- Bank Closes and Drops too
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	AND bkBankTypeID = 2
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;

-- Get banks dropped from our staff member
INSERT INTO @ClosingResults
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	DropsFrom
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineID,
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (20, 29) -- Drops and Bank Closes (implicit drops)
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	AND bkBankTypeID = 2
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;		

end
else if(@CashMethod = 1)   -- POS mode
begin
-- POS Mode has banks, no drops

-- Get banks issued to our staff member
INSERT INTO @ClosingResults
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedTo
)
SELECT ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineID,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0))
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    and (@MachineID = 0 or b.bkMachineID = @MachineID )   -- POS mode banks lack soldfrommachineid 
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;

-- Get banks issued from our staff member
INSERT INTO @ClosingResults
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedFrom
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineId,
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;

end
else if(@CashMethod = 2)   -- MACHINE mode
begin
	print 'MACHINE MODE BANK ACTIVITY';
-- MACHINE Mode has a shared master banks in a separate group.  No drops!

-- Get banks issued to our staff member
INSERT INTO @ClosingResults
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedTo
)
SELECT ct.ctrGamingDate,
		ct.ctrGamingSession,
        b.bkStaffID, 'Bank', 'Master', 
        b.bkMachineID,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0))
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
WHERE 
	b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
GROUP BY ct.ctrGamingDate, ct.ctrGamingSession, b.bkStaffID, b.bkMachineID;

-- Get banks issued from our staff member
INSERT INTO @ClosingResults
(
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedFrom
)
SELECT	ct.ctrGamingDate,
		ct.ctrGamingSession,
        b.bkStaffID, 'Bank', 'Master', 
        b.bkMachineId,
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
WHERE 
	b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, b.bkStaffID, b.bkMachineID;

end;	-- END MACHINE MODE



with RESULTS(staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr, soldFromMachineId, Banks, Drops) as
(select staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr, soldFromMachineId
,SUM(isnull(BanksIssuedTo,0) + isnull(BanksIssuedFrom,0)) Banks
-- ,SUM(isnull(DropsTo,0) + isnull(DropsFrom,0)) Drops	DE8480  this may be changed in future if cash activity needs to display this data...
,SUM(isnull(DropsFrom,0)) Drops 
from @ClosingResults 
group by staffIdNbr,staffFirstName,staffLastName,GamingDate,sessionNbr, soldFromMachineId)
select * 
from RESULTS
--where (Banks <> 0 or Drops <> 0) --DE9626
ORDER BY staffIdNbr,gamingDate, sessionNbr ;


End





