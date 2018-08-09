--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'SalesByProductGrpDateSession.rpt')
begin
    insert into Reports values (1, 1, 'SalesByProductGrpDateSession.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();

-- Insert Report Parameters

    insert into ReportDefinitions values (1, @ReturnValue);         -- @OperatorID

    insert into ReportDefinitions values (3, @ReturnValue);			-- @StartDate

    insert into ReportDefinitions values (4, @ReturnValue);			-- @EndDate

    insert into ReportDefinitions values (5, @ReturnValue);			-- @Session

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Sales By Product - Date and Session ');
end