--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'CashActivitySummaryReport.rpt')
begin
    insert into Reports values (4, 1, 'CashActivitySummaryReport.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();
    
    -- Insert Report Parameters

    insert into ReportDefinitions values (1, @ReturnValue);			-- Operator Id

    insert into ReportDefinitions values (3, @ReturnValue);			-- Start Date

    insert into ReportDefinitions values (4, @ReturnValue);			-- End Date

    insert into ReportDefinitions values (5, @ReturnValue);			-- Session 
    
    insert into ReportDefinitions values (6, @ReturnValue);			-- Staff

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Cash Activity Summary');
end