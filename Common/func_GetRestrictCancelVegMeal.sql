USE [FBM]
GO
/****** Object:  UserDefinedFunction [dbo].[func_GetRestrictOtherCompany]    Script Date: 11/21/2014 1:06:07 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[func_GetRestrictCancelVegMeal] ()
RETURNS INT
AS
BEGIN
	
	DECLARE @Restrict INT
	
	SELECT @Restrict=[Value]  FROM [dbo].[LookupData] WITH(NOLOCK) WHERE LookupId = 8 AND Code='Cancel'

	IF NOT ISNUMERIC(@Restrict)=1 
	BEGIN
		SET @Restrict = 0
	END	
	
	RETURN @Restrict
END
 


