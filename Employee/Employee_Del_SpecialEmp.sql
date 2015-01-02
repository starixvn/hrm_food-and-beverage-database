USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[MealOrder_Get_MenuBySysID]    Script Date: 10/27/2014 4:55:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Employee_Del_SpecialEmp]
	@SysId INT OUTPUT

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
		SELECT TOP 1 1 FROM [dbo].[Order] WITH(NOLOCK)
			WHERE SysId = @SysId				
			)
	BEGIN
			SELECT @ErrCode = 100
				,@ErrMsg = 'Cannot remove a member who has already ordered meal.'
		RETURN
	END
	
	IF EXISTS(
		SELECT TOP 1 1 FROM [dbo].[OrderDetail] WITH(NOLOCK)
			WHERE SysId = @SysId 
			)
	BEGIN
			SELECT @ErrCode = 101
				,@ErrMsg = 'Cannot remove a member who has already ordered meal.'
		RETURN
	END
	
	IF EXISTS(
		SELECT TOP 1 1 FROM [dbo].[OrderOptional] WITH(NOLOCK)
			WHERE SysId = @SysId 
			)
	BEGIN
			SELECT @ErrCode = 101
				,@ErrMsg = 'Cannot remove a member who has already ordered meal.'
		RETURN
	END
	
	IF EXISTS(
		SELECT TOP 1 1 FROM [dbo].[OrderAlterNative] WITH(NOLOCK)
			WHERE SysId = @SysId 
			)
	BEGIN
			SELECT @ErrCode = 101
				,@ErrMsg = 'Cannot remove a member who has already ordered meal.'
		RETURN
	END

	UPDATE [dbo].[Employee]
	   SET [isDeleted] = 1
		,CardNumber = ''
	 WHERE SysId = @SysId 

	DELETE GroupOrderAdminDetail 
	WHERE SysId = @SysId

	DELETE GroupOrderUserDetail 
	WHERE SysId = @SysId 

	SELECT @ErrCode = 0, @ErrMsg = ''
END