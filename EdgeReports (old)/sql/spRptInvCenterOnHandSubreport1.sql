USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvCenterOnHandSubreport1]    Script Date: 09/07/2012 12:37:23 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInvCenterOnHandSubreport1]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInvCenterOnHandSubreport1]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvCenterOnHandSubreport1]    Script Date: 09/07/2012 12:37:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spRptInvCenterOnHandSubreport1]
(	@OperatorID as int
)	
	 
AS

SET NOCOUNT ON;	

create table #InventoryItems
(
    ProdName    nvarchar(64),
    CurrCount   bigint 
);

Begin
    Insert into #InventoryItems
    (  
     ProdName
     , CurrCount
    )
	select 
	  p.ItemName    
	  , ii.iiCurrentCount    
	from InventoryItem ii
	join productitem p on ii.iiproductitemid = p.productitemid
	join InvLocations il on ii.iiStartLocationID = il.ilInvlocationID
	Where 
	(p.OperatorID = @OperatorID or @OperatorID = 0)
	AND ii.iiRetiredDate IS NULL
	AND p.ProductTypeID != '17'; --Removed Pull Tabs from the report to only report Paper products.
end;

-- Return resultset to the report
select ProdName, COUNT(ProdName)  NumberofSets, SUM(CurrCount) NumberofPacks
from #InventoryItems
group by 
ProdName

Drop Table #InventoryItems;



GO

