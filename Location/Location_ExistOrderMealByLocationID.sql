USE [FBM]
GO
/****** Object:  StoredProcedure [dbo].[Location_DeleteByLocationID]    Script Date: 10/27/2014 4:55:17 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Location_ExistOrderMealByLocationID] 
	@LocationID SMALLINT
	,@StatusID VARCHAR(100)

AS
/*
	Created: Tom.Vo@2014-8-25
	Task: ExistOrderMealByLocationID
	DB: [FBM]
	Original: 

	Revisions:    
	Param's Explanation:

	*/
BEGIN
	SET NOCOUNT ON;
	
	IF OBJECT_ID('tempdb..#StatusID') IS NOT NULL
	BEGIN
		DROP TABLE #StatusID
	END

	CREATE TABLE #StatusID (StatusID SMALLINT)

	IF ISNULL(@StatusID, '') <> ''
	BEGIN
		INSERT INTO #StatusID (StatusID)
		SELECT val
		FROM fnc_strSplit(@StatusID, ',')
	END


	IF EXISTS(SELECT TOP 1 1 FROM dbo.[Order] WITH(NOLOCK) WHERE LocationID = @LocationID AND CurrentStatusID IN (SELECT StatusID FROM #StatusID))
	BEGIN
		SELECT CONVERT(BIT,1 ) [IsExists]
	END
	ELSE
	BEGIN
		SELECT CONVERT(BIT,0 ) [IsExists]
	END

	DROP TABLE #StatusID

END


