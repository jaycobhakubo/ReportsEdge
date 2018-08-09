USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesSummaryByDateSessionStaff]    Script Date: 06/12/2014 15:24:34 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBarcodedPaperSalesSummaryByDateSessionStaff]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBarcodedPaperSalesSummaryByDateSessionStaff]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBarcodedPaperSalesSummaryByDateSessionStaff]    Script Date: 06/12/2014 15:24:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



       
CREATE PROCEDURE  [dbo].[spRptBarcodedPaperSalesSummaryByDateSessionStaff]         
(        
 --=============================================        
 ----Author:  FortuNet (US3497)       
 ----Description: Reports barcoded paper sales over a date range by date, by session and by staff.
 --=============================================        
 @OperatorID AS INT,        
 @StartDate AS SMALLDATETIME,        
 @EndDate AS SMALLDATETIME
)        
AS        
BEGIN        
    SET NOCOUNT ON;
    
Select	ii.iiSerialNo,
		Count(ips.AuditNumber) as Quantity,
		Case when ips.IsValidated = 1 Then 'Yes'
			Else 'No' End as IsValidated,
		rdi.ProductItemName,
		rr.GamingDate,
		sp.GamingSession,
		s.FirstName + ' ' + s.LastName as StaffName
From InvPaperTrackingPackStatus ips
Join InventoryItem ii on ips.InventoryItemID = ii.iiInventoryItemID
Join RegisterDetailItems rdi on ips.RegisterDetailItemId = rdi.RegisterDetailItemID
Join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
Join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
Join Staff s on rr.StaffID = s.StaffID
Where rr.OperatorID = @OperatorID
And RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And rr.SaleSuccess = 1
And rd.VoidedRegisterReceiptID is null
Group By rr.GamingDate, sp.GamingSession, rr.StaffID, ips.InventoryItemID, ii.iiSerialNo, ips.IsValidated, rdi.ProductItemName, s.LastName, s.FirstName
Order By s.FirstName, rdi.ProductItemName, ii.iiSerialNo, ips.IsValidated, Quantity

End




GO

