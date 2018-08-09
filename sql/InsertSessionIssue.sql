--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'SessionIssue.rpt')
begin
    -- Report Type and Set IsActive
    
    insert into Reports values (13, 1, 'SessionIssue.rpt');   -- Inventory

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();
    
    -- Insert Report Parameters

    insert into ReportDefinitions values (1, @ReturnValue);		-- OperatorID

    insert into ReportDefinitions values (3, @ReturnValue);		-- StartDate

    insert into ReportDefinitions values (5, @ReturnValue);		-- Session

    insert into ReportDefinitions values (6, @ReturnValue);		-- StaffID

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Session Issue');
end