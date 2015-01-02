USE [FBM]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER FUNCTION [dbo].[f_EncodeXMLValue](@value NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
 
BEGIN
	/*
		# &amp; refers to an ampersand (&) 
		# &lt; refers to a less-than symbol (<) 
		# &gt; refers to a greater-than symbol (>) 
		# &quot; refers to a double-quote mark (") 
		# &apos; refers to an apostrophe (')	
	*/

	SET @value = REPLACE(@value, '&', '&amp;')
	--SET @value = REPLACE(@value, '<', '&lt;')
	--SET @value = REPLACE(@value, '>', '&gt;')
	--SET @value = REPLACE(@value, '"', '&quot;')
	--SET @value = REPLACE(@value, '', '&apos;')
	
	RETURN @value
END