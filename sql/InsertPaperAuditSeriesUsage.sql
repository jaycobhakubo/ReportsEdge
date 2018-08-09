--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'PaperAuditSeriesUsage.rpt')
begin
    insert into Reports values (13, 1, 'PaperAuditSeriesUsage.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();

    insert into ReportDefinitions values (1, @ReturnValue);        -- Insert Report Parameters

    insert into ReportDefinitions values (38, @ReturnValue);       -- Serial Number

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Paper Audit Series Usage');
end