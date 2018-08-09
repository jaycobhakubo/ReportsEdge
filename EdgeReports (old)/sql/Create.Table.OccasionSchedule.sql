use [Daily]
go

if object_id('dbo.OccasionSchedule') is not null
begin
	drop table [dbo].[OccasionSchedule];
end
go

set ansi_nulls on;
go

set quoted_identifier on;
go

create table [dbo].[OccasionSchedule](
	[OccasionScheduleID] [int] IDENTITY(1,1) NOT NULL,
	[OperatorID] int not null,
	[StaffId] [int] not null,
	[Occasion] [int] NULL,
	[Date] [datetime] NULL,
	[DTStamp] [datetime] NULL,
	[IsDeleted] [bit] NULL
 constraint [PK_OccasionSchedule] primary key clustered 
(
	[OccasionScheduleID] asc
)with (pad_index = off, statistics_norecompute = off, ignore_dup_key = off, allow_row_locks = on, allow_page_locks = on) on [primary]
) on [primary];

go

alter table [dbo].[OccasionSchedule]  with check add  constraint [FK_OccasionSchedule_Operator] foreign key([OperatorID])
references [dbo].[Operator] ([OperatorID]);
go

alter table [dbo].[OccasionSchedule]  with check add  constraint [FK_OccasionSchedule_Staff] foreign key([StaffID])
references [dbo].[Staff] ([StaffID]);



