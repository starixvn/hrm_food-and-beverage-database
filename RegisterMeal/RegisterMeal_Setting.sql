USE [FBM]

GO

ALTER PROCEDURE [dbo].[RegisterMeal_Setting]  
AS
/*
Created: Tom.Vo@2014-8-25
Task: [RegisterMeal_Setting]
DB: [FBM]
Original: 

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Order INT
	
	SELECT @Order=[Value]  FROM [dbo].[LookupData] WITH(NOLOCK) WHERE LookupId = 8  AND Code='Order'
	
	IF NOT ISNUMERIC(@Order)=1 
	BEGIN
		SET @Order = 0
	END	

	DECLARE @Cancel INT
	
	SELECT @Cancel=[Value]  FROM [dbo].[LookupData] WITH(NOLOCK) WHERE LookupId = 8  AND Code='Cancel'
	
	IF NOT ISNUMERIC(@Cancel)=1 
	BEGIN
		SET @Cancel = 0
	END	

	SELECT @Order [Order],@Cancel Cancel

END
 