USE [Daily]
GO

/****** Object:  Table [dbo].[OperatorContent]    Script Date: 10/17/2011 09:55:05 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[OperatorContent]') AND type in (N'U'))
DROP TABLE [dbo].[OperatorContent]
GO

USE [Daily]
GO

/****** Object:  Table [dbo].[OperatorContent]    Script Date: 10/17/2011 09:55:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[OperatorContent](
	[OpContentID] [int] IDENTITY(1,1) NOT NULL,
	[OperatorID] [int] NOT NULL,
	[Name] [nvarchar](32) NULL,
	[Content] [image] NULL,
 CONSTRAINT [PK_OperatorContent] PRIMARY KEY CLUSTERED 
(
	[OpContentID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Primary Key.  Allow multiple images per operator.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'OperatorContent', @level2type=N'COLUMN',@level2name=N'OpContentID'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Foreign Key to Operator.  1:n relationship.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'OperatorContent', @level2type=N'COLUMN',@level2name=N'OperatorID'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Name of this blob.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'OperatorContent', @level2type=N'COLUMN',@level2name=N'Name'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Blob to be used for images, sounds, etc.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'OperatorContent', @level2type=N'COLUMN',@level2name=N'Content'
GO


