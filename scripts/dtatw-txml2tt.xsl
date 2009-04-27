<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- parameters -->
  <xsl:param name="locations" select="0"/> <!-- whether to output locations -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <xsl:strip-space elements="sentences s w a"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Mode: main -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: root: traverse -->
  <xsl:template match="/*">
    <xsl:text>%% File auto-generated by dtatw-txml2t.xsl&#10;</xsl:text>
    <xsl:text>%% xml:base=</xsl:text><xsl:value-of select="@xml:base"/><xsl:text>&#10;&#10;</xsl:text>
    <xsl:apply-templates select="./s"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: s -->
  <xsl:template match="s">
    <xsl:text>%% Sentence </xsl:text><xsl:value-of select="@xml:id"/><xsl:text>&#10;</xsl:text>
    <xsl:apply-templates select="./w"/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: w -->
  <xsl:template match="w">
    <xsl:value-of select="@t"/>
    <xsl:if test="$locations">
      <xsl:text>&#09;</xsl:text><xsl:value-of select="@b"/>
    </xsl:if>
    <xsl:apply-templates select="./a"/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: a -->
  <xsl:template match="a">
    <xsl:text>&#09;</xsl:text>
    <xsl:value-of select="text()"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: default: just recurse -->
  <xsl:template match="*|@*|text()|processing-instruction()|comment()" priority="-1">
    <xsl:apply-templates select="*"/>
  </xsl:template>

</xsl:stylesheet>
