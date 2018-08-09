USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperIssueSummaryByStaff]    Script Date: 02/14/2012 14:25:11 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPaperIssueSummaryByStaff]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPaperIssueSummaryByStaff]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperIssueSummaryByStaff]    Script Date: 02/14/2012 14:25:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE procedure [dbo].[spRptPaperIssueSummaryByStaff]
-- =============================================
-- Author:		Satish Anju
-- Description:	Paper Issue Summary By Staff.
--
-- 2012.02.03 SA: New report
-- 2012.02.14 TP: DE10088 (Added date field)
-- =============================================
@OperatorID		int,
@StartDate		datetime,
@EndDate		datetime,
@Session		int,
@StaffID		int

as
begin
declare @Results table
( 
     Product				nvarchar(64)
    ,TransactionID			int
    ,MasterTransactionID    int
    ,TransactionTypeID		int
	,SerialNumber			nvarchar(30)
	,GamingDate				smalldatetime --DE10088
	,GamingSession			int	
	,Price					money
	,StartNumber			int
	,EndNumber				int
	,ReturnCount			int
	,Quantity				int
	--,Value					money
	,IssuedToStaffName		nvarchar(64)
	,IssuedByStaffName		nvarchar(64)
	
)
insert into @Results

select 
       PDI.ItemName
      ,IVT.ivtInvTransactionID
      ,case when IVT.ivtMasterTransactionID is null then  IVT.ivtInvTransactionID else IVT.ivtMasterTransactionID end
      ,IVT.ivtTransactionTypeID
      ,II.iiSerialNo
      ,IVT.ivtGamingDate --DE10088
      ,IVT.ivtGamingSession      
      ,IVT.ivtPrice
      ,IVT.ivtStartNumber
      ,IVT.ivtEndNumber
      ,ReturnCount=CASE ivtTransactionTypeID WHEN 3 THEN ivdDelta ELSE 0 END
      ,(IVT.ivtEndNumber-IVT.ivtStartNumber+1)
      --,IVT.ivtPrice * (IVT.ivtEndNumber-IVT.ivtStartNumber+1)     
      ,ITS.LastName + ', ' + ITS.FirstName + ' (' + convert(nvarchar(10), ITS.StaffID) + ')' as ITStaffName     
      ,IBS.LastName + ', ' + IBS.FirstName + ' (' + convert(nvarchar(10), IBS.StaffID) + ')' as IBStaffName
      
from  InvTransaction IVT
     join InventoryItem II on II.iiInventoryItemID=IVT.ivtInventoryItemID
     join ProductItem PDI on PDI.ProductItemID=II.iiProductItemID
     left join InvTransactionDetail IVD on IVD.ivdInvTransactionID=IVT.ivtInvTransactionID
     left join InvLocations INV on INV.ilInvLocationID=IVD.ivdInvLocationID
     left join Staff ITS on (ITS.StaffID=INV.ilStaffID)
     left join Staff IBS on IBS.StaffID=IVT.ivtStaffID
     
where IVT.ivtGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
and IVT.ivtGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)   
and PDI.ProductTypeID=16
--and IVT.ivtMasterTransactionID is null
and INV.ilStaffID <> 0
and PDI.OperatorID=@OperatorID
and (@Session = 0 or IVT.ivtGamingSession = @Session)
and (@StaffID=0 or INV.ilStaffID=@StaffID)

delete i1 from @Results as i1, @Results as i2
where i1.MasterTransactionID = i2.MasterTransactionID 
AND ((i1.TransactionTypeID = 25 AND i2.TransactionTypeID = 32 AND i1.TransactionID > i2.TransactionID)
OR i1.TransactionTypeID = 32)

select 
	  Product   
     ,MasterTransactionID      
	 ,SerialNumber
	 ,GamingDate   --DE10088
	 ,GamingSession		
	 ,Price			
	 ,StartNumber	
	 ,EndNumber		
	 ,ReturnCount=-1 * sum(ReturnCount)	
	 ,Quantity       
	 --,Value          
     ,IssuedToStaffName
	 ,IssuedByStaffName 
from  @Results
group by
      Product 
     ,MasterTransactionID       
	 ,SerialNumber
	 ,GamingDate   --DE10088
	 ,GamingSession	
	 ,Price			
	 ,StartNumber	
	 ,EndNumber				
	 ,Quantity       
	 --,Value        	
	 ,IssuedToStaffName
	 ,IssuedByStaffName 

end

GO