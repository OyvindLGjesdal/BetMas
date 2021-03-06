<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:t="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="#all" version="2.0">
    <xsl:template match="t:title">
        <xsl:choose>
            <xsl:when test="@ref">
                <xsl:variable name="filename">
                    <xsl:choose>
                        <xsl:when test="contains(@ref, '#')">
                            <xsl:value-of select="substring-before(@ref, '#')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@ref"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:choose>
                    <xsl:when test="text()">
                        <xsl:apply-templates/>
                        <a xmlns="http://www.w3.org/1999/xhtml" href="{@ref}">
                            <xsl:text> (</xsl:text>
                            <a href="{@ref}" class="MainTitle" data-value="{@ref}">
                                <xsl:text>CAe </xsl:text>
                                <xsl:value-of select="substring($filename, 4, 4)"/>
                                <xsl:text> </xsl:text>
                                <xsl:value-of select="substring-after(@ref, '#')"/>
                            </a>
                            <xsl:text>) </xsl:text>
                            <span class="fa fa-share"/>
                        </a>
                    </xsl:when>
                    <xsl:otherwise>
                        <a xmlns="http://www.w3.org/1999/xhtml" href="{@ref}" class="MainTitle" data-value="{@ref}">
                            <xsl:text>CAe </xsl:text>
                            <xsl:value-of select="substring($filename, 4, 4)"/>
                            <xsl:text> </xsl:text>
                            <xsl:value-of select="substring-after(@ref, '#')"/>
                        </a>
                    </xsl:otherwise>
                </xsl:choose>
                
                
                <xsl:variable name="id" select="generate-id()"/>
                <span xmlns="http://www.w3.org/1999/xhtml" id="{$id}Ent{$filename}relations" class="popup">
                    <xsl:text>  </xsl:text>
                    <span class="fa fa-hand-o-left"/>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="@evidence"> (<xsl:value-of select="@evidence"/>)</xsl:if>
        <xsl:if test="@cert = 'low'">
            <xsl:text> ? </xsl:text>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="t:title" mode="nolink">
        
        <xsl:choose>
            <xsl:when test="@ref">
                <xsl:variable name="filename">
                    <xsl:choose>
                        <xsl:when test="contains(@ref, '#')">
                            <xsl:value-of select="substring-before(@ref, '#')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@ref"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="text()">
                        <xsl:variable name="enteredTitle">
                            <xsl:apply-templates mode="nolink"/>
                        </xsl:variable>
                        <span property="http://purl.org/dc/terms/hasPart">
                        <xsl:choose>
                            <xsl:when test="string-length($enteredTitle) gt 30">
                                <xsl:value-of select="concat(substring($enteredTitle, 1, 30), '...')"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$enteredTitle"/>
                            </xsl:otherwise>
                        </xsl:choose>
                        </span>
                    </xsl:when>
                    <xsl:otherwise>
                        <span xmlns="http://www.w3.org/1999/xhtml" class="MainTitle" data-value="{@ref}">
                            <xsl:if test="parent::t:msItem">
                                <xsl:attribute name="property">
                                    <xsl:value-of select="'http://purl.org/dc/terms/hasPart'"/>
                                </xsl:attribute>
                                <xsl:attribute name="resource">
                                    <xsl:value-of select="concat('http://betamasaheft.eu/',$filename)"/>
                                </xsl:attribute>
                            </xsl:if>
                            <xsl:value-of select="@ref"/>
                        </span>
                    </xsl:otherwise>
                </xsl:choose>
                
            </xsl:when>
            <xsl:when test="not(text()) and not(@ref)"> No title </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="enteredTitle">
                    <xsl:apply-templates mode="nolink"/>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="string-length($enteredTitle) gt 30">
                        <xsl:value-of select="concat(substring($enteredTitle, 1, 30), '...')"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$enteredTitle"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="@evidence"> (<xsl:value-of select="@evidence"/>)</xsl:if>
        <xsl:if test="@cert = 'low'">
            <xsl:text> ? </xsl:text>
        </xsl:if>
        <xsl:text> / </xsl:text>
    </xsl:template>
</xsl:stylesheet>