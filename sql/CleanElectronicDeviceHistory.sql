-- CleanElectronicDeviceHistory.sql   
-- US1839: remove it first then readd it.  This is required to add the new report param.

use daily;
go

declare @reporttypeid int; set @reporttypeid=null;
declare @reportid int; set @reportid=null;
declare @reportlocalid int; set @reportlocalid=null;
declare @reportparamid int; set @reportparamid=null;

select @reportid = ReportID from Reports where ReportFileName = 'ElectronicDeviceHistoryReport.rpt';

delete from ReportDefinitions where ReportID = @reportid;
delete from ReportLocalizations where ReportID = @reportid;
delete from Reports where ReportID = @reportid;

select * from Reports where ReportID = @reportid;
select * from ReportDefinitions where ReportID = @reportid;
select * from ReportLocalizations where ReportID = @reportid;

select r.*, rd.*, rp.ParameterName, rl.*, rt.TypeName
from reports r
join ReportDefinitions rd on r.ReportID = rd.ReportID
join ReportParameters rp on rd.ReportParameterID = rp.ReportParameterID
join ReportLocalizations rl on r.ReportID = rl.ReportID
join ReportTypes rt on rt.ReportTypeID = r.ReportTypeID
where ReportFileName like 'ElectronicDeviceHistoryReport.rpt';

