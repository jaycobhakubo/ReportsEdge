use [daily]
go

if object_id('dbo.OccasionScheduleType') is not null
begin
	drop table [dbo].[OccasionScheduleType];
end
go

set ansi_nulls on
go

set quoted_identifier on
go

create table [dbo].[OccasionScheduleType](
	[OccasionScheduleTypeID] [int] identity(1,1) not null,
	[Type] [nvarchar](32) null,
 constraint [PK_OccasionScheduleType] primary key clustered 
(
	[OccasionScheduleTypeID] asc
)with (pad_index = off, statistics_norecompute = off, ignore_dup_key = off, allow_row_locks = on, allow_page_locks = on) on [primary]
) on [primary];

go


