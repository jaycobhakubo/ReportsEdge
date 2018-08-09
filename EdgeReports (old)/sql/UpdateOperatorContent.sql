use Daily;
go

-- Cleanup
truncate table OperatorContent;

-- Each operator has posibility of personal graphic for pageheader
insert into OperatorContent (OperatorID, Name) select OperatorID, 'PageHeader' from Operator;

-- For now, add the Edge logo for each operator
update OperatorContent 
set Content = (select * from openrowset(bulk 'c:\gametech\common\EdgeLogo.png', single_blob) as a) 

-- Review!
select * from OperatorContent;


