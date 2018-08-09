--- Insert Inventory Issue Summary By Product Report
use Daily;

if not exists (select 1 from Reports where ReportFileName = 'InventoryIssueSummaryByProduct.rpt')
begin
    insert into Reports values (13, 1, 'InventoryIssueSummaryByProduct.rpt');

    declare @ReturnValue int;

    select @ReturnValue = Scope_Identity ();

    insert into ReportDefinitions values (1, @ReturnValue);

    insert into ReportDefinitions values (3, @ReturnValue);

    insert into ReportDefinitions values (4, @ReturnValue);

    insert into ReportDefinitions values (5, @ReturnValue);

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Inventory Issue Summary By Product');
end
