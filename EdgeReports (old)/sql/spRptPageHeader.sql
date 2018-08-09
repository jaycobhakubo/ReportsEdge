USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPageHeader]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPageHeader]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spRptPageHeader] 
-- =============================================
-- Author:		Barry J. Silver
-- Description:	Show custom logo in page header.
--
-- 2011.10.17 bjs:  New report
-- 2011.11.07 bsb: Removed the operator content for time being.
-- =============================================
	@OperatorID	as int
AS
SET NOCOUNT ON

-- By default, show the custom image if it exists. If not show the Edge logo.
declare @count int; set @count = 0;
select @count = COUNT(OpContentID) from OperatorContent where (OperatorID = @OperatorID) and (Name = 'PageHeaderCustom');
print @count;

select
        o.OperatorName,
        o.NonGameTechLicense,
	    a.Address1,
	    a.Address2,
	    a.City,
	    a.State,
	    a.Zip,
		'' as Content	  
    from Operator o    
    join Address a on (o.AddressID = a.AddressID)
	where 
        (o.OperatorID = @OperatorID)

/*
if(@count = 0)
begin
    -- Db is missing the customer's logo, use the Edge logo instead.
    select
        o.OperatorName,
        o.NonGameTechLicense,
	    a.Address1,
	    a.Address2,
	    a.City,
	    a.State,
	    a.Zip,
	    oc.Content
    from Operator o
    join OperatorContent oc on (o.OperatorID = oc.OperatorID)
    join Address a on (o.AddressID = a.AddressID)
    where 
        (o.OperatorID = @OperatorID)
        and oc.Name = 'PageHeader';
end
else
begin
    -- This customer has a legitimate logo, use it!
    select
        o.OperatorName,
        o.NonGameTechLicense,
	    a.Address1,
	    a.Address2,
	    a.City,
	    a.State,
	    a.Zip,
	    oc.Content
    from Operator o
    join OperatorContent oc on (o.OperatorID = oc.OperatorID)
    join Address a on (o.AddressID = a.AddressID)
    where 
        (o.OperatorID = @OperatorID)
        and oc.Name = 'PageHeaderCustom';

end;
*/


SET NOCOUNT OFF;


GO


