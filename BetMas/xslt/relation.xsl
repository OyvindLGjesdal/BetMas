<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:t="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="#all" version="2.0">
    <xsl:template match="t:relation">
       <xsl:if test="@active = $mainID">
           <xsl:variable name="passive">
            <xsl:choose>
                <xsl:when test="contains(@passive, ' ')">
                    <xsl:value-of select="tokenize(normalize-space(@passive), ' ')"/>
                </xsl:when>
                <xsl:otherwise><xsl:value-of select="@passive"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
           <xsl:for-each select="$passive">
        <span property="http://purl.org/dc/elements/1.1/relation" resource="http://betamasaheft.eu/{current()}"/>
        </xsl:for-each>
       </xsl:if>
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="t:desc">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:include href="VARIAsmall.xsl"/><!--includes many templates which don't do much but are all used-->
    <xsl:include href="locus.xsl"/>
    <xsl:include href="bibl.xsl"/>
    <xsl:include href="origin.xsl"/>
    <xsl:include href="date.xsl"/>
    <xsl:include href="ref.xsl"/>
    <xsl:include href="persName.xsl"/>
    <xsl:include href="placeName.xsl"/>
    <xsl:include href="title.xsl"/>
</xsl:stylesheet>