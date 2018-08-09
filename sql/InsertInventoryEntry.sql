--- Insert Report Script
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'InventoryEntry.rpt')
begin
    insert into Reports values (13, 1, 'InventoryEntry.rpt');   -- Set Report Group and Set IsActive

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();
    
    -- Insert Report Parameters

    insert into ReportDefinitions values (1, @ReturnValue);         -- @OperatorID

    insert into ReportDefinitions values (3, @ReturnValue);			-- @StartDate

    insert into ReportDefinitions values (4, @ReturnValue);			-- @EndDate

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Inventory Entry');
end