USE [FBM]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].RPT_DailySideDish
	@fromDate DATE
	,@toDate DATE
	,@DepartmentID VARCHAR(100) = NULL
	,@EmployeeTypeID VARCHAR(100) = NULL
	,@TeamID VARCHAR(100) = NULL
	,@isDebug BIT = 0
	,@IsLocal INT = NULL
	,@Sysid int = null
AS
/*
Created: Tom.Vo@2014-11-1
Task: Daily Main Dish Report - Price Per Meal
DB: [FBM]
Original: 

Revisions:    
Param's Explanation: 
*/
BEGIN
	SET NOCOUNT ON

	SELECT @DepartmentID = ISNULL(@DepartmentID, '')
		,@EmployeeTypeID = ISNULL(@EmployeeTypeID, '')
		,@TeamID = ISNULL(@TeamID, '')
	
	DECLARE @Restrict BIT
	SET @Restrict = dbo.func_GetRestrictOtherCompany() 

	IF OBJECT_ID('tempdb..#Department') IS NOT NULL
	BEGIN
		DROP TABLE #Department
	END

	CREATE TABLE #Department (DepartmentID SMALLINT)

	IF ISNULL(@DepartmentID,'')=''
	BEGIN
		INSERT INTO #Department(DepartmentID)
		SELECT DepartmentID FROM [dbo].[Department] dp WITH(NOLOCK) 
		WHERE (@Restrict = 0 OR dp.HeadDepartment = 1)

		SELECT @DepartmentID='1'
	END
	ELSE IF ISNULL(@DepartmentID, '') <> ''
	BEGIN
		INSERT INTO #Department (DepartmentID)
		SELECT val
		FROM fnc_strSplit(@DepartmentID, ',')fnc
		INNER JOIN [dbo].[Department] dp WITH(NOLOCK) 
			ON fnc.val = dp.DepartmentID
		WHERE (@Restrict = 0 OR dp.HeadDepartment = 1)
	END

	IF OBJECT_ID('tempdb..#Team') IS NOT NULL
	BEGIN
		DROP TABLE #Team
	END

	CREATE TABLE #Team (
		DepartmentID SMALLINT
		,EmpTeamID SMALLINT
		)

	IF ISNULL(@DepartmentID, '') <> ''
		AND ISNULL(@TeamID, '') <> ''
	BEGIN
		INSERT INTO #Team (
			DepartmentID
			,EmpTeamID
			)
		SELECT et.DepartmentID
			,et.EmpTeamID
		FROM fnc_strSplit(@TeamID, ',') fnc
			INNER JOIN [dbo].[EmpTeam] et WITH (NOLOCK)
			ON fnc.val = et.EmpTeamID
			INNER JOIN #Department tmp
			ON tmp.DepartmentID = et.DepartmentID
	END

	IF OBJECT_ID('tempdb..#EmployeeType') IS NOT NULL
	BEGIN
		DROP TABLE #EmployeeType
	END

	CREATE TABLE #EmployeeType (EmployeeTypeID SMALLINT)

	IF ISNULL(@EmployeeTypeID, '') <> ''
	BEGIN
		INSERT INTO #EmployeeType (EmployeeTypeID)
		SELECT val
		FROM fnc_strSplit(@EmployeeTypeID, ',')
	END

	IF OBJECT_ID('tempdb..#Employee') IS NOT NULL
	BEGIN
		DROP TABLE #Employee
	END

	CREATE TABLE #Employee (SysID INT)

	DECLARE @SQL NVARCHAR(MAX)

	SELECT @SQL ='INSERT INTO #Employee(SysID) 
				SELECT ee.[SysID]
				FROM [dbo].[Employee] ee WITH (NOLOCK) '
				+ CASE WHEN ISNULL(@DepartmentID,'')<>'' THEN 
						CHAR(13) +' INNER JOIN #Department tmpDe ON tmpDe.DepartmentID = ee.DepartmentID' 
						ELSE '' END
				+ CASE WHEN ISNULL(@DepartmentID,'')<>'' AND ISNULL(@TeamID,'')<>'' THEN 
						CHAR(13) +' INNER JOIN #Team et ON et.DepartmentID = ee.DepartmentID
							AND et.EmpTeamID = ee.TeamID'
						ELSE '' END
				+ CASE WHEN ISNULL(@EmployeeTypeID,'')<>'' THEN 
						+CHAR(13) +' INNER JOIN #EmployeeType tmpEmpType ON tmpEmpType.[EmployeeTypeID] = ee.[EmpCategoryID] '
						ELSE '' END
				--+CHAR(13) + 'WHERE ee.isDeleted = 0 AND ee.Enabled = 1'
				+CHAR(13) + 'WHERE 1=1 '

				+CHAR(13) +  CASE WHEN @IsLocal IS NOT NULL  THEN 'AND ee.IsLocal = '+CONVERT(NVARCHAR(1),ISNULL(@IsLocal,1)) ELSE '' END

				+CHAR(13) +  CASE WHEN @Sysid IS NOT NULL  THEN 'AND ee.SysID = '+CONVERT(NVARCHAR(100),ISNULL(@Sysid,1))  ELSE '' END
	
	IF @isDebug = 1 PRINT @SQL
	EXECUTE sp_executesql @SQL

	DECLARE @Days VARCHAR(1000)
		,@colsName VARCHAR(2000)

		,@totalDays INT		
		,@temptbl NVARCHAR(4000)
		,@updtbl NVARCHAR(4000)
		,@query NVARCHAR(4000)
	
	SET @totalDays = DAY(@ToDate)
	
	IF OBJECT_ID('tempdb..#OrderQty') IS NOT NULL
	BEGIN
		DROP TABLE #OrderQty
	END

	CREATE TABLE #OrderQty (
		WorkDate DATE
		,SysID INT
		,FoodID INT
		,Price  MONEY
		,Qty INT
		,Amount MONEY
		)

	INSERT INTO #OrderQty (
		WorkDate
		,SysID
		,FoodID
		,Price
		,Qty
		,Amount
		)
	SELECT ord.OnDate
		,ordd.SysID
		,ordd.FoodID
		,ordd.Price
		,ordd.Qty
		,ordd.Price*ordd.Qty Amount		 
	FROM [dbo].[Order] ord WITH (NOLOCK)
		INNER JOIN [dbo].[OrderOptional] ordd WITH (NOLOCK)
		ON ord.OrderID = ordd.OrderID
			AND ordd.IsDeleted = 0
		INNER JOIN dbo.employee e WITH (NOLOCK)
		ON ordd.SysId = e.SysID
		INNER JOIN #Employee tmpEmp
		ON e.SysID = tmpEmp.SysID
	WHERE ord.OnDate BETWEEN @fromDate AND @toDate
		AND [CurrentStatusID] IN (4, 5) 
		 
	SELECT
		d.[DepartmentID]
		,d.NAME [DepartmentName]

		,et.EmpTeamID EmpTeamID
		,et.[Code] EmpTeamCode
		,et.[Name] EmpTeamName

		,tmpCal.WorkDate
		,epc.ShiftId
		
		,COALESCE(eps.Code,
				CASE WHEN ISNULL(epc.IsHoliday,0)=0 and epc.ShiftId is null and isOffday = 1  THEN 'Off day' 
					WHEN ISNULL(epc.IsHoliday,0)=1 AND (epc.ShiftId is null ) THEN 'PH' 
					ELSE '' END					
					,''
					
					) ShiftCode
		,ee.[DomainUsername]
		,ee.[Code]
		,ee.[FullName]
		,ee.[NickName]
		,ee.[SysID]
		
		,f.[FoodID]
		,f.ENGName FoodEngName
		,f.VNMName FoodVNMName
		,tmpCal.Price
		,tmpCal.Qty
		,tmpCal.Amount
	FROM #OrderQty tmpCal
		INNER JOIN dbo.Employee ee WITH(NOLOCK)
			ON tmpCal.SysID = ee.SysID
		LEFT  JOIN dbo.EmpCategory empCat WITH(NOLOCK)
			ON ee.EmpCategoryID = empCat.EmpCategoryID
		LEFT  JOIN [dbo].[Department] d WITH (NOLOCK) 
			ON ee.DepartmentID = d.DepartmentID					
		LEFT JOIN [dbo].[EmpTeam] et WITH (NOLOCK) 
			ON ee.DepartmentID = et.DepartmentID
			AND ee.TeamID = et.EmpTeamID
		LEFT JOIN dbo.EmpCalendar epc WITH (NOLOCK) 
			ON ee.DepartmentID = epc.DepartmentID 
			AND ee.EmpId = epc.EmpId
			AND tmpCal.WorkDate = epc.WorkDate
		LEFT JOIN dbo.EmpShift eps WITH (NOLOCK) 
			ON eps.DepartmentID = epc.DepartmentID 
			AND eps.ShiftId = epc.ShiftId
		LEFT JOIN dbo.Food f  WITH (NOLOCK) 
		ON tmpCal.FoodID = f.FoodID
			AND tmpCal.FoodID = f.FoodID
	ORDER BY 
		d.[DepartmentID]
		,et.Name
		,ee.[NickName]	

	DROP TABLE #OrderQty 
	DROP TABLE #Department
	DROP TABLE #Team 
	DROP TABLE #Employee 
END

 