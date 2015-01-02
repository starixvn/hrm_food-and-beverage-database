USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[Location_EditByLocationID]    Script Date: 10/27/2014 4:55:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Location_EditActiveByLocationID] 
	@LocationID SMALLINT
     ,@IsActive bit

	 ,@ModifiedBy INT=NULL
	 ,@ModifiedDate DATETIME=NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
	Created: Tom.Vo@2014-8-25
	Task: Edit Location
	DB: [FBM]
	Original: 

	Revisions:    
	Param's Explanation:

	*/
BEGIN
	SET NOCOUNT ON;

	IF @IsActive = 0
	BEGIN
		IF EXISTS(SELECT TOP 1 1 FROM dbo.[Order] WITH(NOLOCK) WHERE LocationID = @LocationID AND CurrentStatusID IN (1) )
		BEGIN
			SELECT @ErrCode = 100, @ErrMsg = 'Orders in status New with the same Delivery area exist. Please Accept or Reject all of those orders before deactivate the Delivery Area.'
			RETURN
		END
	END

	UPDATE [dbo].[Location] WITH(ROWLOCK,UPDLOCK)
	SET [IsActive] = @IsActive
			
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()
    WHERE @LocationID = LocationID
	 
	SELECT @ErrCode = 0, @ErrMsg = ''

END


