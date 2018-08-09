USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesDetail]    Script Date: 06/12/2014 14:18:13 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBarcodedPaperSalesDetail]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBarcodedPaperSalesDetail]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesDetail]    Script Date: 06/12/2014 14:18:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


       
CREATE PROCEDURE  [dbo].[spRptBarcodedPaperSalesDetail]         
(        
 --=============================================        
 ----Author:  FortuNet (US3438)        
 ----Description: Reports barcoded paper sales over a date range
 --=============================================        
 @OperatorID AS INT,        
 @StartDate AS SMALLDATETIME,        
 @EndDate AS SMALLDATETIME
)        
AS        
BEGIN        
    SET NOCOUNT ON;
    
Select	ii.iiSerialNo,
		ips.AuditNumber,
		Case when ips.IsValidated = 1 Then 'Yes'
			Else 'No' End as IsValidated,
		rdi.ProductItemName,
		sp.GamingSession,
		rd.VoidedRegisterReceiptID,
		rr.GamingDate,
		s.FirstName + ' ' + s.LastName as StaffName,
		rr.DTStamp,
		p.FirstName + ' ' + p.LastName as PlayerName,
		pmc.MagneticCardNo
From InvPaperTrackingPackStatus ips
Join InventoryItem ii on ips.InventoryItemID = ii.iiInventoryItemID
Join RegisterDetailItems rdi on ips.RegisterDetailItemId = rdi.RegisterDetailItemID
Join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
Join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Join Staff s on rr.StaffID = s.StaffID
Left Join Player p on rr.PlayerID = p.PlayerID
Left Join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
Where rr.OperatorID = @OperatorID
And RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And rr.SaleSuccess = 1
And rd.VoidedRegisterReceiptID is null
Group By rr.GamingDate, sp.GamingSession, rdi.ProductItemName, ips.InventoryItemID, ii.iiSerialNo, ips.AuditNumber, ips.IsValidated, s.LastName, s.FirstName, pmc.MagneticCardNo,
p.LastName, p.FirstName, rr.DTStamp, rd.VoidedRegisterReceiptID 

End



GO

