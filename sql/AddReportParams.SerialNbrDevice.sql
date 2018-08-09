-- AddReportParams.SerialNbrDevice.sql

use Daily;
go

--select * from ReportParameters;

declare @reportparamid int;
select @reportparamid = ReportParameterID from ReportParameters where ParameterName = '@SerialNbrDevice';

if(@reportparamid is null)
begin
    print 'Adding';
    insert into ReportParameters (ParameterName) values ('@SerialNbrDevice');
    print 'Done';

--    select * from ReportParameters;
end
else
begin
    print 'Parameter already exists!';
end;


