--- Insert Inventory Issue Summary By Product Report
Use Daily;


if not exists (select 1 from Reports where ReportFileName = 'BankTransactions.rpt')
begin
    insert into Reports values (4, 1, 'BankTransactions.rpt');

    declare @ReturnValue int;

    select @ReturnValue = scope_identity ();

    insert into ReportDefinitions values (1, @ReturnValue); -- OperatorID

    insert into ReportDefinitions values (3, @ReturnValue); -- Start Date

    insert into ReportDefinitions values (5, @ReturnValue); -- Session

    insert into ReportLocalizations values (@ReturnValue, 1033, 'en-US', 'Bank Transactions');
end
