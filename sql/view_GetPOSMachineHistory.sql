USE [Daily]
GO

/****** Object:  View [dbo].[view_GetPOSMachineHistory]    Script Date: 04/25/2014 11:43:47 ******/
IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[view_GetPOSMachineHistory]'))
DROP VIEW [dbo].[view_GetPOSMachineHistory]
GO

USE [Daily]
GO

/****** Object:  View [dbo].[view_GetPOSMachineHistory]    Script Date: 04/25/2014 11:43:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


--------------------------------------------------------------------------------------------
-- 2014.04.25 tmp: DE11723 - Set the Transaction Type to Sale Failed if the sale does not succeed.
-------------------------------------------------------------------------------------------- 


CREATE View [dbo].[view_GetPOSMachineHistory] as

Select	ROW_NUMBER() Over(Partition By rr.SoldFromMachineID Order By rr.RegisterReceiptId) as RowID,
		rr.SoldFromMachineID,
		rr.RegisterReceiptID,
		rr.TransactionNumber,
		rr.OriginalReceiptID,
		m.ClientIdentifier,
		m.SerialNumber,
		rr.TransactionTypeID,
		Case when rr.SaleSuccess = 0	--DE11723
			Then 'Sale Failed' Else		--DE11723
		t.TransactionType End as TransactionType,
--		t.TransactionType,
		rr.PackNumber,
		rr.StaffID,
		rr.OperatorID,
		rr.GamingDate,
		rr.DTStamp,
		rr.DeviceFee
From RegisterReceipt rr join Machine m on rr.SoldFromMachineID = m.MachineID
join TransactionType t on rr.TransactionTypeID = t.TransactionTypeID



GO

