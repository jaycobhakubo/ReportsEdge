USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvCenterOnHandSubreport2]    Script Date: 09/07/2012 12:37:42 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInvCenterOnHandSubreport2]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInvCenterOnHandSubreport2]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvCenterOnHandSubreport2]    Script Date: 09/07/2012 12:37:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spRptInvCenterOnHandSubreport2]
(	@OperatorID as int
)	
	 
AS

SET NOCOUNT ON;

create table #InventoryItems
(
    --OperatorId  int,
    --ManufId     int,
    --VendorId    int,
    --ProdItemId  int,
    --ManufName   nvarchar(30),
    --VendorName  nvarchar(30),
    --ProdName    nvarchar(30),
    --InvLoc      nvarchar(30),
    --InvNbr      nvarchar(30),
    --SerialNbr   nvarchar(30),
    --RangeStart  int,
    --RangeEnd    int,
    --FirstIssued datetime,
    --LastIssued  datetime,
    --Retired     datetime,
    --TaxId       nvarchar(30),
      CardCut     nvarchar(30)
    , Up          int
--    StartCount  int,
    --Damaged     int,
    --Skipped     int,
    , CurrCount   int
    --Price       money,
    --InvCost     money
);


Begin
    Insert into #InventoryItems
    (  
       CardCut, Up, CurrCount
    )
	select     
      cc.ccCardCutName
    , ii.iiUp   
    , ii.iiCurrentCount 
    
	from InventoryItem ii
	join productitem p on ii.iiproductitemid = p.productitemid
	left join CardCuts cc on ii.iiCardCutID = cc.ccCardCutID
	Where 
	(p.OperatorID = @OperatorID or @OperatorID = 0)
	AND ii.iiRetiredDate IS NULL
	And p.ProductTypeID != '17'; --Removed Pull Tabs from the report to only report Paper products.
end;

select CardCut, Up, COUNT(*) NumberofSets, SUM(CurrCount) NumberofPacks
from #InventoryItems where CardCut is not null and Up is not null
group by CardCut, Up;

Drop Table #InventoryItems;



GO

