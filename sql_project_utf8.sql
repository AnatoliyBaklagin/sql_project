-- 0. create tables
CREATE TABLE [dbo].[certificates](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[company_id] [int] NOT NULL,
	[section_id] [int] NULL,
	[series_id] [int] NOT NULL,
	[number] [varchar](5) NOT NULL,
	[type_id] [int] NOT NULL,
	[date_of_issue] [date] NULL,
	[validity] [date] NULL,
 CONSTRAINT [PK_certificates] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

CREATE TABLE [dbo].[company](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [varchar](255) NOT NULL,
 CONSTRAINT [PK_company] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

CREATE TABLE [dbo].[section](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [varchar](255) NOT NULL,
 CONSTRAINT [PK_section] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

CREATE TABLE [dbo].[series](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [varchar](3) NOT NULL,
 CONSTRAINT [PK_series] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

CREATE TABLE [dbo].[type](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [varchar](2) NOT NULL,
 CONSTRAINT [PK_type] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [dbo].[certificates]  WITH CHECK ADD  CONSTRAINT [FK_certificates_company] FOREIGN KEY([company_id])
REFERENCES [dbo].[company] ([id])

ALTER TABLE [dbo].[certificates] CHECK CONSTRAINT [FK_certificates_company]

ALTER TABLE [dbo].[certificates]  WITH CHECK ADD  CONSTRAINT [FK_certificates_section] FOREIGN KEY([section_id])
REFERENCES [dbo].[section] ([id])

ALTER TABLE [dbo].[certificates] CHECK CONSTRAINT [FK_certificates_section]

ALTER TABLE [dbo].[certificates]  WITH CHECK ADD  CONSTRAINT [FK_certificates_series] FOREIGN KEY([series_id])
REFERENCES [dbo].[series] ([id])

ALTER TABLE [dbo].[certificates] CHECK CONSTRAINT [FK_certificates_series]

ALTER TABLE [dbo].[certificates]  WITH CHECK ADD  CONSTRAINT [FK_certificates_type] FOREIGN KEY([type_id])
REFERENCES [dbo].[type] ([id])

ALTER TABLE [dbo].[certificates] CHECK CONSTRAINT [FK_certificates_type]

-- 1. insert company name into a table compant
INSERT INTO [dbo].[company] ([name]) 
SELECT DISTINCT [Компания] 
FROM [dbo].[source_data]
WHERE [Компания] NOT IN (SELECT [name] FROM [dbo].[company])
ORDER BY [Компания]

-- 2. insert preliminary data into a temporary table 
IF OBJECT_ID('tempdb..#t') IS NULL CREATE TABLE #t ([name] VARCHAR(MAX)) ELSE DELETE FROM #t;
DECLARE @sql VARCHAR(MAX) = ''
SELECT @sql = @sql + ';' + REPLACE(LTRIM(RTRIM([Список участков])),'; ', ';') FROM [dbo].[source_data]
SET @sql = 'INSERT INTO #t (name) SELECT '''+ REPLACE(@sql, ';', ''' AS Section UNION ALL SELECT ''')+''''
EXEC (@sql)

-- 3. insert section name into a table section 
INSERT INTO [dbo].[section]
SELECT DISTINCT SUBSTRING([name], 1, CHARINDEX('/', [name]) - 2) [name] 
FROM #t 
WHERE [name] like '%/%'
AND SUBSTRING([name], 1, CHARINDEX('/', [name]) - 2) NOT IN (SELECT [name] FROM [dbo].[section])
ORDER BY [name]

-- 4. insert series, number and type into a temporary 2 table
if OBJECT_ID('tempdb..#t2') IS NULL CREATE TABLE #t2 (name VARCHAR(MAX)) ELSE DELETE FROM #t2;
INSERT INTO #t2
SELECT DISTINCT SUBSTRING([name], CHARINDEX('/', [name]) + 2, 10) [name] 
FROM #t 
WHERE [name] LIKE '%/%'
UNION 
SELECT DISTINCT [name]
FROM #t 
WHERE [name] NOT LIKE '%/%' AND [name] <> ''
ORDER BY [name]

-- 5. insert series into a table series
INSERT INTO [series] (name)
SELECT DISTINCT substring([name], 1, 3) [name] 
FROM #t2 WHERE substring([name], 1, 3) NOT IN (SELECT [name] FROM [dbo].[series])

-- 6. insert Type into a table type
INSERT INTO [type] (name)
SELECT DISTINCT substring([name], 9, 10) [name] 
FROM #t2 WHERE substring([name], 9, 10) NOT IN (SELECT [name] FROM [dbo].[type])

-- 7. insert certificates into a table certificates
INSERT INTO [certificates] ([company_id], [section_id],[series_id],[number],[type_id])
SELECT
c.id AS [company_id],
s.id AS [section_id],
s1.id AS [series_id],
CASE WHEN LEN(t.[name]) = 10 THEN SUBSTRING(t.[name], 4, 5) ELSE SUBSTRING(t.[name], CHARINDEX('/', t.[name]) + 5, 5) END [number],
t1.id AS [type_id]
FROM #t t
JOIN [dbo].[source_data] sd ON sd.[Список участков] LIKE '%' + t.[name] + '%'
JOIN [dbo].[company] c ON sd.[Компания] LIKE c.[name]
LEFT JOIN [dbo].[section] s ON t.[name] LIKE s.[name] + '%/%'
JOIN [dbo].[series] s1 ON (t.[name] LIKE s1.[name] + '%' AND LEN (t.[name]) = 10) OR (t.[name] LIKE '%/%' + s1.[name] + '%' AND LEN (t.[name]) > 10)
JOIN [dbo].[type] t1 ON (t.[name] LIKE '%' + t1.[name] AND LEN (t.[name]) = 10) OR (t.[name] LIKE '%/%' + t1.[name] AND LEN (t.[name]) > 10)
WHERE t.[name] <> ''
ORDER BY 1, 2, 3, 4, 5

-- 8. generate random date_of_issue 
DECLARE @max_id INT, @id INT = 1
DECLARE @FromDate DATE = '2000-01-01'
DECLARE @ToDate DATE = '2010-12-31'
DECLARE @RandomDate DATE
SET @id = (SELECT MIN([id]) FROM [certificates])
SET @max_id = (SELECT MAX([id]) FROM [certificates])
WHILE @id <= @max_id
	BEGIN
		SET @RandomDate = DATEADD(DAY, RAND(CHECKSUM(NEWID())) * (1 + DATEDIFF(DAY, @FromDate, @ToDate)), @FromDate)
		UPDATE [dbo].[certificates]
		SET [date_of_issue] = @RandomDate
		WHERE [id] = @id
		SET @id += 1
	END

-- 8. generate random validity
DECLARE @DateOfIssue DATE
SET @id = (SELECT MIN([id]) FROM [certificates])
SET @max_id = (SELECT MAX([id]) FROM [certificates])
WHILE @id <= @max_id
	BEGIN
		SET @DateOfIssue = (SELECT [date_of_issue] FROM [dbo].[certificates] WHERE [id] = @id)
		SET @FromDate = DATEADD(YEAR, 5, @DateOfIssue)
		SET @ToDate = DATEADD(YEAR, 10, @DateOfIssue)
		SET @RandomDate = DATEADD(DAY, RAND(CHECKSUM(NEWID())) * (1 + DATEDIFF(DAY, @FromDate, @ToDate)), @FromDate)
		
		IF (@DateOfIssue IS NOT NULL) AND (@DateOfIssue <= '01.01.2010')
		BEGIN
			UPDATE [dbo].[certificates]
			SET [validity] = @RandomDate
			WHERE [id] = @id
		END

		SET @id += 1
	END

-- 9. verification of added data
SELECT
com.[name] AS [Компания],
ISNULL(s.[name], '') AS [Название ЛУ],
ser.[name] AS [Серия],
c.[number] AS [Номер],
t.[name] AS [Вид],
ISNULL(CONVERT(VARCHAR, c.[date_of_issue], 104), '') AS [Срок действия],
ISNULL(CONVERT(VARCHAR, c.[validity], 104), 'бессрочная') AS [Дата выдачи]
FROM [dbo].[certificates] c
JOIN [dbo].[company] com ON com.[id] = c.[company_id]
LEFT JOIN [dbo].[section] s ON s.[id] = c.[section_id]
JOIN [dbo].[series] ser ON ser.[id] = c.[series_id]
JOIN [dbo].[type] t ON t.[id] = c.[type_id]