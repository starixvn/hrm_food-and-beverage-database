USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[GroupOrderUser_GetMember]    Script Date: 10/27/2014 4:55:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[GroupOrderAdmin_DeleteGroup]
	@GroupID [int]	 

	,@ModifiedBy INT=NULL
	,@ModifiedDate DATETIME=NULL	
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg nvarchar(200) = '' OUTPUT
AS
/* 
Created: Tom.Vo@2014-10-23
Task: delete group 
DB: [FBM]
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	DELETE 	[dbo].[GroupOrderAdmin] WHERE GroupOrderID = @GroupID

	DELETE 	[dbo].[GroupOrderAdminDetail] WHERE GroupOrderID = @GroupID
	
	SELECT @ErrCode = 0, @ErrMsg = ''
END

