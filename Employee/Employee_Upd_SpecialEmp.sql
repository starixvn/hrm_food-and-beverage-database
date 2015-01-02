USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[MealOrder_Get_MenuBySysID]    Script Date: 10/27/2014 4:55:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Employee_Upd_SpecialEmp]
	@SysId INT
	,@DepartmentID SMALLINT
	,@Code nvarchar(20)
	,@NickName nvarchar(50)
	,@FullName nvarchar(50)=''
	,@CardNumber varchar(50)
	,@EmployeeTypeID SMALLINT	
	,@IsActive BIT = 1

	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2014-8-25
Task: This function is used to edit the special employees.
DB: FBM
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS(
		SELECT TOP 1 1 FROM [dbo].[Employee] WITH(NOLOCK)
			WHERE SysId <> @SysId AND (ISNULL(Code,'')  = ISNULL(@Code,'')
				)
			)
	BEGIN
			SELECT @ErrCode = 100
				,@ErrMsg = 'Code ' + ISNULL(@Code,'') + ' already exists.'
		RETURN
	END
	
	--IF EXISTS(
	--	SELECT TOP 1 1 FROM [dbo].[Employee] WITH(NOLOCK)
	--		WHERE SysId <> @SysId AND (ISNULL(FullName,'')  = ISNULL(@FullName,'')
	--			)
	--		)
	--BEGIN
	--		SELECT @ErrCode = 101
	--			,@ErrMsg = 'Employee Name ' + ISNULL(@FullName,'') + ' already exists.'
	--	RETURN
	--END
		
	IF ISNULL(@CardNumber,'') <> ''
	BEGIN
		IF EXISTS(
			SELECT TOP 1 1 FROM [dbo].[Employee] WITH(NOLOCK)
				WHERE SysId <> @SysId AND (ISNULL(CardNumber,'')  = ISNULL(@CardNumber,'')
					)
				)
		BEGIN
				SELECT @ErrCode = 102
					,@ErrMsg = 'Card Number ' + ISNULL(@CardNumber,'') + ' already exists.'
			RETURN
		END
	END
		
	IF (@DepartmentID IN (1,3) AND @EmployeeTypeID NOT IN (4,5))
		OR (@DepartmentID IN (2) AND @EmployeeTypeID NOT IN (1,2,3))
	BEGIN
		SELECT @ErrCode = 103
					,@ErrMsg = 'EmployeeType invalid.'
			RETURN
	END

	IF ISNULL(@FullName,'')  = ''
		SET @FullName  = @NickName 

	UPDATE [dbo].[Employee]
	   SET [DepartmentID] = @DepartmentID		
		  ,[Code] = @Code
		  ,[DomainUsername] = CASE WHEN @DepartmentID = 1 THEN 'spvn\' ELSE '' END + @Code 
		  ,[FullName] = @FullName
		  ,[NickName] = @NickName
		  ,[Enabled] = @IsActive		  
		  ,[EmpCategoryID] = @EmployeeTypeID
		  ,[IsLocal] = CASE WHEN @DepartmentID = 2 AND @EmployeeTypeID = 1 THEN 0
			WHEN @DepartmentID = 2 AND @EmployeeTypeID = 2 THEN 1
			WHEN @DepartmentID = 2 AND @EmployeeTypeID = 3 THEN 1
			WHEN @DepartmentID = 1 AND @EmployeeTypeID = 4  THEN 0
			WHEN @DepartmentID = 1 AND @EmployeeTypeID = 5  THEN 1
			WHEN @EmployeeTypeID = 5 THEN 1 END
		  ,[CardNumber] = ISNULL(@CardNumber,'')
	 WHERE SysId = @SysId 

	SELECT @ErrCode = 0, @ErrMsg = ''
END