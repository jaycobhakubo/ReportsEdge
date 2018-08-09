--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'OccasionReportByPackage.rpt')
begin
    insert into Reports values (16, 1, 'OccasionReportByPackage.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();
    
    -- Insert Report Parameters

    insert into ReportDefinitions values (1, @ReturnValue);			-- OperatorID

    insert into ReportDefinitions values (3, @ReturnValue);			-- StartDate

    insert into ReportDefinitions values (5, @ReturnValue);			-- Session

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Occasion Report by Package');
end