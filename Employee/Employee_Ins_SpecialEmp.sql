USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[MealOrder_Get_MenuBySysID]    Script Date: 10/27/2014 4:55:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Employee_Ins_SpecialEmp]
	@SysId INT=NULL OUTPUT
	,@DepartmentID SMALLINT
	,@Code nvarchar(20)
	,@NickName nvarchar(50)
	,@FullName nvarchar(200)=''
	,@CardNumber varchar(50)
	,@EmployeeTypeID SMALLINT	
	,@IsActive BIT = 1

	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2014-8-25
Task: This function is used to Create the special employees.
DB: FBM
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @DisableSync bit = 1
		,@Roles varchar(20) = ''
		,@EmpId INT
	
	IF EXISTS(
		SELECT TOP 1 1 FROM [dbo].[Employee] WITH(NOLOCK)
			WHERE (ISNULL(Code,'')  = ISNULL(@Code,'')
				)
			)
	BEGIN
			SELECT @ErrCode = 100
				,@ErrMsg = 'Code ' + ISNULL(@Code,'') + ' already exists.'
		RETURN
	END
	
	--IF EXISTS(
	--	SELECT TOP 1 1 FROM [dbo].[Employee] WITH(NOLOCK)
	--		WHERE (ISNULL(FullName,'')  = ISNULL(@NickName,'')
	--			)
	--		)
	--BEGIN
	--		SELECT @ErrCode = 101
	--			,@ErrMsg = 'Employee Name ' + ISNULL(@NickName,'') + ' already exists.'
	--	RETURN
	--END
		
	IF ISNULL(@CardNumber,'') <> ''
	BEGIN
		IF EXISTS(
			SELECT TOP 1 1 FROM [dbo].[Employee] WITH(NOLOCK)
				WHERE (ISNULL(CardNumber,'')  = ISNULL(@CardNumber,'')
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

	SELECT @EmpId = MAX(EmpId)+1 FROM [dbo].[Employee] WITH(NOLOCK) WHERE EmpId>=99990

	DECLARE @Password NVARCHAR(500)=N'hI/qAKGkHXu7UAzKE1t5p1n9xp0/koiy2W5L1g=='

	IF ISNULL(@FullName,'') = ''
		SELECT @FullName = @NickName

	IF ISNULL(@NickName,'') = ''
		SELECT @NickName = @FullName

	INSERT INTO [dbo].[Employee]
           ([EmpId]
           ,[DepartmentID]
           ,[DomainUsername]
           ,[Code]
           ,[FullName]
           ,[NickName]
           ,[Enabled]
           ,[Password]
           ,[isDeleted]
           ,[EmpCategoryID]
           ,[IsLocal]
           ,[Roles]
           ,[JoinedDate]
           ,[DisableSync]
           ,[TeamID]
           ,[ModifiedDate]
           ,[SynDate]
           ,[Phone]
           ,[CardNumber])

	SELECT @EmpId  [EmpId]
		  ,@DepartmentID [DepartmentID]
		  ,CASE WHEN @DepartmentID = 1 THEN 'spvn\' ELSE '' END + @Code [DomainUsername]
		  ,@Code [Code]
		  ,@FullName [FullName]
		  ,@NickName [NickName]
		  ,@IsActive [Enabled]
		  ,@Password [Password]
		  ,0 [isDeleted]
		  ,@EmployeeTypeID [EmpCategoryID]
		  ,CASE WHEN @DepartmentID = 2 AND @EmployeeTypeID = 1 THEN 0
			WHEN @DepartmentID = 2 AND @EmployeeTypeID = 2 THEN 1
			WHEN @DepartmentID = 2 AND @EmployeeTypeID = 3 THEN 1
			WHEN @DepartmentID = 1 AND @EmployeeTypeID = 4  THEN 0
			WHEN @DepartmentID = 1 AND @EmployeeTypeID = 5  THEN 1
			WHEN @EmployeeTypeID = 5 THEN 1
			ELSE 1 END [IsLocal]
		  ,@Roles [Roles]
		  ,GETDATE() [JoinedDate]
		  ,@DisableSync [DisableSync]
		  ,-1 [TeamID]
		  ,NULL [ModifiedDate]
		  ,NULL [SynDate]
		  ,'' [Phone]
		  ,@CardNumber [CardNumber]	
	
	SELECT @SysID = CAST(SCOPE_IDENTITY() AS SMALLINT)
	
	INSERT INTO [dbo].[EmpRole](SysID,RoleId)
	SELECT FB.SysID, 4  RoleId
	FROM (SELECT @SysID SysID) FB 
	LEFT JOIN [dbo].[EmpRole] ER
		ON FB.SysID = ER.SysId
				AND ER.RoleId = 4
	WHERE ER.SysId IS NULL 


	SELECT @ErrCode = 0, @ErrMsg = ''
END