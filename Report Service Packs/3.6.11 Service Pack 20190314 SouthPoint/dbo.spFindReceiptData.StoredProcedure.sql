USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spFindReceiptData]    Script Date: 3/14/2019 9:20:16 AM ******/
DROP PROCEDURE [dbo].[spFindReceiptData]
GO

/****** Object:  StoredProcedure [dbo].[spFindReceiptData]    Script Date: 3/14/2019 9:20:16 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



--=============================================================================
-- Usage: EXECUTE spFindReceiptData
--    1,				-- Operator ID
--    N'10/9/2007',	    -- Gaming Date
--    0,				-- TransactonTypeID
--    0,				-- Transaction Number		
--    0,				-- Session Number
--    0,				-- Staff ID
--    0,				-- Pack Number
--    N'',  			-- Mag Card
--    0,				-- Player ID
--    0		    		-- Device ID
--
--  2012.08.23 jkn TA11362: When a transaction number is specified the request
--      should not be limited to the gaming date search all dates. (DE10748)
--  2013.09.27 jkn: Added support for populating the name field with a temp
--      name if a name isn't defined and there is a player id associated with
--      the receipt
-- 2014.01.31 (DE11560) jkn: The Transaction number was not being used in the
--  main selection so it would gather too much data and take too long to 
--  process the query
--  2016.08.23 (US3419) RAK: Added SuccessfulSalesFilter optional parameter.
--       Search will NOT contain receipts with the selected filter. 
--       SaleSuccess flag is now returned.
--  2016.12.19 RAK: Added UnresolvedPaymentError to results.  If 1, the
--                  transaction has at least one tender marked for audit
--                  that has not been resolved.
-- 2017.08.08 (DE13668) When attempting to find voided receipts for a specific
--      session there are no results. Added a UNION ALL to gather all of the
--      void transactions, this was much more efficient that attempting to
--      do it all in a single query
-- 2018.05.21 (US5589) When retrieving the receipts include the receipts that
--      were presold. The queries for the presales are just unioned into the 
--      temp table to make the sp fast
-- 2018.07.26 (US5562) jkn: Added support for retrieving if the receipt was presold
-- 2018.07.31 jbv: Eliminated false presales.
-- 2018.08.06 jkn: Merged changes from two previous checkins.
--  Removed hardcoded presales values
--  Removed unions that were specific to only finding items that were presold
--      instead finding all sales that were either sold for the current gaming
--      date or were presold for the gaming date.
--  2018.08.24 RAK: Added sold from machine name.
-- 2019.03.14 tmp: Reduced timeouts
--=============================================================================
CREATE PROCEDURE [dbo].[spFindReceiptData]
	@OperatorID int,
	@GamingDate nvarchar(24),
	@TransactionTypeID int,
	@TransNo int,
	@SessionNo smallint,
	@StaffID int,
	@PackNo int,
	@MagCard nvarchar(32),
	@PlayerID int,
	@DeviceID int,
	@SuccessfulSalesFilter int = 2, -- 0 = sussessful, 1 = failed, 2 = all
	@GetTransactionsWithUnresolvedPaymentErrors int = 0 
AS
SET NOCOUNT ON

CREATE TABLE #tmpReceipts
	(	[ReceiptID]					[int]				NULL,
		[TransNo]					[int]				NULL,
		[GamingDate]				[datetime]			NULL,
		[StaffID]					[int]				NULL,
		[StaffFName]				[nvarchar] (32)		NULL,
		[StaffLName]				[nvarchar] (32)		NULL,
		[PlayerID]					[int]				NULL,
		[PlayerFName]				[nvarchar] (32)		NULL,
		[PlayerLName]				[nvarchar] (32)		NULL,
		[MachineID]					[int]				NULL,
		[MachineName]				[nvarchar] (64)     NULL,
		[PackNo]					[int]				NULL,
		[TransTypeID]				[int]				NULL,
		[IsVoided]					[bit]				NULL,
		[DeviceID]					[int]				NULL,
		[SessionNo]					[smallint]			NULL,
		[MagCardNo]					[nvarchar] (32)		NULL,
		[Success]					[int]				NULL,
		[UnresolvedPaymentError]	[int]				NULL, -- 0=none, 1=unresolved, 2=resolved, 3=both   xxxxxxRU
        [Presold]                   [int]               NULL)

SET @OperatorID	= NULLIF(@OperatorID, 0)
SET @GamingDate	= NULLIF(@GamingDate, '')
SET @TransNo = NULLIF(@TransNo, 0)
SET @SessionNo = NULLIF(@SessionNo, 0)
SET @StaffID = NULLIF(@StaffID, 0)
SET @PackNo = NULLIF(@PackNo, 0)
SET @MagCard = NULLIF(@MagCard, '')
SET @PlayerID = NULLIF(@PlayerID, 0)
SET @DeviceID = NULLIF(@DeviceID, 0)

--IF @TransNo IS NOT NULL
--BEGIN
--    SET @GamingDate = NULL
--END

INSERT #tmpReceipts
SELECT DISTINCT
	rr.RegisterReceiptID,
	rr.TransactionNumber,
	GamingDate = CONVERT (nvarchar(24), rr.GamingDate, 101),
	s.StaffID,
	s.FirstName,
	s.LastName,
	p.PlayerID,
	FirstName = CASE WHEN (p.PlayerId is null)
	    THEN p.FirstName
	    ELSE (CASE WHEN p.FirstName = '' and p.LastName = ''
	            THEN '[Player Id ' + CAST(p.PlayerId AS nvarchar) + ']'
	            ELSE p.FirstName
	            END)
	    END,
	p.LastName,
	rr.SoldFromMachineID,
	m.MachineDescription,
	PackNumber = ISNULL (rr.PackNumber, 0),
	rr.TransactionTypeID,
	IsVoided = CASE WHEN (rd.VoidedRegisterReceiptID IS NOT NULL)
		THEN 1
		ELSE 0
		END,
	rr.DeviceID,
	rd.PlayGamingSession,
	pmc.MagneticCardNo,
	rr.SaleSuccess,
	0, -- Unresolved payment error
    Presold = CASE WHEN ((rr.GamingDate != rd.PlayGamingDate)
                         OR (rr.ActiveSalesSessionNumber IS NOT NULL AND rd.PlayGamingSession != rr.ActiveSalesSessionNumber))
              THEN 1 ELSE 0 END
FROM RegisterReceipt rr (NOLOCK)
    LEFT JOIN RegisterDetail rd (NOLOCK) ON rr.RegisterReceiptID = rd.RegisterReceiptID
--    LEFT JOIN SessionPlayed sp (NOLOCK) ON rd.SessionPlayedID = sp.SessionPlayedID
    LEFT JOIN Player p (NOLOCK)	ON rr.PlayerID = p.PlayerID
    LEFT JOIN PlayerMagCards pmc (NOLOCK)ON p.PlayerID = pmc.PlayerID
    LEFT JOIN Staff s (NOLOCK) ON rr.StaffID = s.StaffID
    LEFT JOIN Machine m (NOLOCK) ON rr.SoldFromMachineID = m.MachineID
WHERE 
--	@GamingDate between rr.GamingDate and rd.PlayGamingDate
	rr.GamingDate = @GamingDate
    AND rr.OperatorID = @OperatorID
    AND rr.SaleSuccess != @SuccessfulSalesFilter
    AND (rr.TransactionTypeID = @TransactionTypeID or @TransactionTypeID = 0) AND rr.TransactionTypeId <> 2
    AND (rr.TransactionNumber = @TransNo or @TransNo is null) --DE11560
UNION ALL -- Get all the voided transactions
SELECT DISTINCT
		rr.RegisterReceiptID,
		rr.TransactionNumber,
		GamingDate = CONVERT (nvarchar(24), rr.GamingDate, 101),
		s.StaffID,
		s.FirstName,
		s.LastName,
		p.PlayerID,
		FirstName = CASE WHEN (p.PlayerId is null)
		    THEN p.FirstName
		    ELSE (CASE WHEN p.FirstName = '' and p.LastName = ''
		            THEN '[Player Id ' + CAST(p.PlayerId AS nvarchar) + ']'
		            ELSE p.FirstName
		            END)
		    END,
		p.LastName,
		rr.SoldFromMachineID,
		m.MachineDescription,
		PackNumber = ISNULL (rr.PackNumber, 0),
		rr.TransactionTypeID,
		IsVoided = CASE WHEN (rd.VoidedRegisterReceiptID IS NOT NULL)
			THEN 1
			ELSE 0
			END,
		rr.DeviceID,
		rd.PlayGamingSession,
		pmc.MagneticCardNo,
		rr.SaleSuccess,
	    0, -- Unresolved payment error
        Presold = CASE WHEN ((rr.GamingDate != rd.PlayGamingDate)
                             OR (rr.ActiveSalesSessionNumber IS NOT NULL AND rd.PlayGamingSession != rr.ActiveSalesSessionNumber))
                  THEN 1 ELSE 0 END
FROM RegisterReceipt rr (NOLOCK)
    LEFT JOIN RegisterDetail rd (NOLOCK) ON rr.RegisterReceiptId = rd.VoidedRegisterReceiptId
--    LEFT JOIN SessionPlayed sp (NOLOCK) ON rd.SessionPlayedID = sp.SessionPlayedID
    LEFT JOIN Player p (NOLOCK)	ON rr.PlayerID = p.PlayerID
    LEFT JOIN PlayerMagCards pmc (NOLOCK)ON p.PlayerID = pmc.PlayerID
    LEFT JOIN Staff s (NOLOCK) ON rr.StaffID = s.StaffID
    LEFT JOIN Machine m (NOLOCK) ON rr.SoldFromMachineID = m.MachineID
WHERE 
--	@GamingDate between rr.GamingDate and rd.PlayGamingDate
	rr.GamingDate = @GamingDate
    AND rr.OperatorID = @OperatorID
    AND rr.SaleSuccess != @SuccessfulSalesFilter
    AND (rr.TransactionTypeID = @TransactionTypeID or @TransactionTypeID = 0) AND rr.TransactionTypeId = 2
    AND (rr.TransactionNumber = @TransNo or @TransNo is null) --DE11560

--mark all the transactions that have unresolved payment errors
UPDATE #tmpReceipts 
    SET UnresolvedPaymentError = 1
    WHERE ReceiptID IN (SELECT DISTINCT RegisterReceiptID 
					    FROM RegisterReceiptTender AS rrt
					        JOIN TenderReceiptData AS trd ON (rrt.RegisterReceiptTenderID = trd.RegisterReceiptTenderID) 
                        WHERE trd.TenderReceiptTypeID = 4)

--mark all the transactions that have resolved payment errors
UPDATE #tmpReceipts 
    SET UnresolvedPaymentError = UnresolvedPaymentError+2
    WHERE ReceiptID IN (SELECT DISTINCT RegisterReceiptID
                        FROM RegisterReceiptTender AS rrt
					        JOIN TenderReceiptData AS trd ON (rrt.RegisterReceiptTenderID = trd.RegisterReceiptTenderID) 
                        WHERE trd.TenderReceiptTypeID = 5)

IF @GetTransactionsWithUnresolvedPaymentErrors = 1 --filter out everything that doesn't have an unresolved payment 
BEGIN
    DELETE FROM #tmpReceipts WHERE UnresolvedPaymentError IN (0, 2)
END

--
-- Update DeviceID from UnlockLog
-- Rally DE8390 - Unable to search by device for non-crate devices
--
--DECLARE @RRID int
--DECLARE RR_Cursor CURSOR FOR SELECT ReceiptID FROM #tmpReceipts WHERE DeviceID IS NULL
--OPEN RR_Cursor
--FETCH NEXT FROM RR_Cursor INTO @RRID
--WHILE @@FETCH_STATUS = 0
--BEGIN			
--    UPDATE #tmpReceipts
--    SET DeviceID = (SELECT TOP 1 ulDeviceID 
--				    FROM UnLockLog
--				    WHERE ulRegisterReceiptID = @RRID
--				        AND ulPackLoginAssignDate IS NOT NULL
--				    ORDER BY ulPackLoginAssignDate DESC)
--    WHERE ReceiptID = @RRID

--	FETCH NEXT FROM RR_Cursor INTO @RRID
--END
--CLOSE RR_Cursor
--DEALLOCATE RR_Cursor

--Cash Only or Forced Payout - use gtdPayoutReceiptNo
UPDATE #tmpReceipts
SET TransNo = (SELECT TOP 1 gtdPayoutReceiptNo
				FROM GameTransDetail (NOLOCK)
				WHERE gtdRegisterReceiptID = ReceiptID)
WHERE TransTypeID = 16

declare @tests int = 0

IF @TransNo IS NOT NULL
	set @tests = @tests + 1

IF @SessionNo IS NOT NULL
	set @tests = @tests + 1

IF @StaffID	IS NOT NULL
	set @tests = @tests + 1

IF @PackNo IS NOT NULL
	set @tests = @tests + 1

IF @MagCard	IS NOT NULL
	set @tests = @tests + 1

IF @PlayerID IS NOT NULL
	set @tests = @tests + 1

IF 	@DeviceID IS NOT NULL
	set @tests = @tests + 1

IF @tests = 0 --no test criteria, return everything
BEGIN
	SELECT DISTINCT
	ReceiptID,
	TransNo,
	GamingDate = CONVERT (nvarchar(24), GamingDate, 101),
	StaffFName,
	StaffLName,
	PlayerFName,
	PlayerLName,
	MachineID,
	MachineName,
	PackNumber = ISNULL (PackNo, 0),
	TransTypeID,
	IsVoided,
	Success,
	UnresolvedPaymentError,
    Presold
	FROM #tmpReceipts (nolock)
END
ELSE
BEGIN --something to test
	if @tests = 1
	BEGIN --use UNION instead or OR, UNION will remove duplicate records
		SELECT DISTINCT ReceiptID,
			TransNo,
			GamingDate = CONVERT (nvarchar(24), GamingDate, 101),
			StaffFName,
			StaffLName,
			PlayerFName,
			PlayerLName,
			MachineID,
			MachineName,
			PackNumber = ISNULL (PackNo, 0),
			TransTypeID,
			IsVoided,
			Success,
			UnresolvedPaymentError,
			Presold
		FROM #tmpReceipts (nolock)
		WHERE TransNo = @TransNo
		UNION
		SELECT DISTINCT ReceiptID,
			TransNo,
			GamingDate = CONVERT (nvarchar(24), GamingDate, 101),
			StaffFName,
			StaffLName,
			PlayerFName,
			PlayerLName,
			MachineID,
			MachineName,
			PackNumber = ISNULL (PackNo, 0),
			TransTypeID,
			IsVoided,
			Success,
			UnresolvedPaymentError,
			Presold
		FROM #tmpReceipts (nolock)
		WHERE SessionNo = @SessionNo
		UNION
		SELECT DISTINCT ReceiptID,
			TransNo,
			GamingDate = CONVERT (nvarchar(24), GamingDate, 101),
			StaffFName,
			StaffLName,
			PlayerFName,
			PlayerLName,
			MachineID,
			MachineName,
			PackNumber = ISNULL (PackNo, 0),
			TransTypeID,
			IsVoided,
			Success,
			UnresolvedPaymentError,
			Presold
		FROM #tmpReceipts (nolock)
		WHERE StaffID = @StaffID
		UNION
		SELECT DISTINCT ReceiptID,
			TransNo,
			GamingDate = CONVERT (nvarchar(24), GamingDate, 101),
			StaffFName,
			StaffLName,
			PlayerFName,
			PlayerLName,
			MachineID,
			MachineName,
			PackNumber = ISNULL (PackNo, 0),
			TransTypeID,
			IsVoided,
			Success,
			UnresolvedPaymentError,
			Presold
		FROM #tmpReceipts (nolock)
		WHERE PackNo = @PackNo
		UNION
		SELECT DISTINCT ReceiptID,
			TransNo,
			GamingDate = CONVERT (nvarchar(24), GamingDate, 101),
			StaffFName,
			StaffLName,
			PlayerFName,
			PlayerLName,
			MachineID,
			MachineName,
			PackNumber = ISNULL (PackNo, 0),
			TransTypeID,
			IsVoided,
			Success,
			UnresolvedPaymentError,
			Presold
		FROM #tmpReceipts (nolock)
		WHERE MagCardNo = @MagCard
		UNION
		SELECT DISTINCT ReceiptID,
			TransNo,
			GamingDate = CONVERT (nvarchar(24), GamingDate, 101),
			StaffFName,
			StaffLName,
			PlayerFName,
			PlayerLName,
			MachineID,
			MachineName,
			PackNumber = ISNULL (PackNo, 0),
			TransTypeID,
			IsVoided,
			Success,
			UnresolvedPaymentError,
			Presold
		FROM #tmpReceipts (nolock)
		WHERE PlayerID = @PlayerID
		UNION
		SELECT DISTINCT ReceiptID,
			TransNo,
			GamingDate = CONVERT (nvarchar(24), GamingDate, 101),
			StaffFName,
			StaffLName,
			PlayerFName,
			PlayerLName,
			MachineID,
			MachineName,
			PackNumber = ISNULL (PackNo, 0),
			TransTypeID,
			IsVoided,
			Success,
			UnresolvedPaymentError,
			Presold
		FROM #tmpReceipts (nolock)
		WHERE DeviceID = @DeviceID
	END
	ELSE --multiple tests
	BEGIN
		SELECT DISTINCT ReceiptID,
			TransNo,
			GamingDate = CONVERT (nvarchar(24), GamingDate, 101),
			StaffFName,
			StaffLName,
			PlayerFName,
			PlayerLName,
			MachineID,
			MachineName,
			PackNumber = ISNULL (PackNo, 0),
			TransTypeID,
			IsVoided,
			Success,
			UnresolvedPaymentError,
			Presold
		FROM #tmpReceipts (nolock)
		WHERE	((@TransNo IS NOT NULL and TransNo = @TransNo) or @TransNo IS NULL) and
				((@SessionNo IS NOT NULL and SessionNo = @SessionNo) or @SessionNo IS NULL) and
				((@StaffID IS NOT NULL and StaffID = @StaffID) or @StaffID IS NULL) and
				((@PackNo IS NOT NULL and PackNo = @PackNo) or @PackNo IS NULL) and
				((@MagCard IS NOT NULL and MagCardNo = @MagCard) or @MagCard IS NULL) and
				((@PlayerID IS NOT NULL and PlayerID = @PlayerID) or @PlayerID IS NULL) and
				((@DeviceID IS NOT NULL and DeviceID = @DeviceID) or @DeviceID IS NULL)
	END
END

DROP TABLE #tmpReceipts
SET NOCOUNT OFF




GO

