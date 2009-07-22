<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- parameters -->
  <xsl:param name="doc_attrs" select="1"/>    <!-- bool: output document attributes as DTA::CAB format comments? -->
  <xsl:param name="s_attrs"   select="1"/>    <!-- bool: output sentence attributes as DTA::CAB format comments? -->
  <xsl:param name="w_loc"     select="1"/>    <!-- bool: output token locations as DTA::CAB analyses? -->
  <xsl:param name="w_cab"     select="1"/>    <!-- bool: output DTA::CAB format analyses? -->
  <xsl:param name="w_a"       select="1"/>    <!-- bool: output other (tokenizer) analyses? -->

  <xsl:param name="w_loc_prefix" select="''"/>           <!-- location analysis prefix string -->
  <xsl:param name="w_id_prefix"  select="'[xmlid] '"/>   <!-- xml:id analysis prefix string -->
  <xsl:param name="w_c_prefix"   select="'[chars] '"/>   <!-- character-id-list analysis prefix string -->
  <xsl:param name="w_a_prefix"   select="''"/>           <!-- default analysis prefix string -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <xsl:strip-space elements="sentences s w a"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Mode: main -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: root: traverse -->
  <xsl:template match="/*">
    <xsl:if test="$doc_attrs">
      <xsl:text>%% File auto-generated by dtatw-txml2t.xsl&#10;</xsl:text>
      <xsl:text>%% xml:base=</xsl:text><xsl:value-of select="@xml:base"/><xsl:text>&#10;&#10;</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="./s"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: s -->
  <xsl:template match="s">
    <xsl:if test="$s_attrs">
      <xsl:text>%% Sentence </xsl:text><xsl:value-of select="@xml:id"/><xsl:text>&#10;</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="./w"/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: w -->
  <xsl:template match="w">
    <xsl:value-of select="@t"/>
    <xsl:if test="$w_loc or $w_cab">
      <!-- loc -->
      <xsl:text>&#09;</xsl:text>
      <xsl:value-of select="$w_loc_prefix"/>
      <xsl:value-of select="@b"/>
    </xsl:if>
    <xsl:if test="$w_cab">
      <!-- xml:id -->
      <xsl:text>&#09;</xsl:text>
      <xsl:value-of select="$w_id_prefix"/>
      <xsl:value-of select="@xml:id"/>
      <!-- characters -->
      <xsl:text>&#09;</xsl:text>
      <xsl:value-of select="$w_c_prefix"/>
      <xsl:value-of select="@c"/>
    </xsl:if>
    <xsl:apply-templates select="*"/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: xlit -->
  <xsl:template match="w/xlit">
    <xsl:if test="$w_cab">
      <xsl:text>&#09;[xlit]</xsl:text>
      <xsl:text> l1=</xsl:text>
      <xsl:value-of select="@isLatin1"/>
      <xsl:text> lx=</xsl:text>
      <xsl:value-of select="@isLatinExt"/>
      <xsl:text> l1s=</xsl:text>
      <xsl:value-of select="@t"/>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: lts -->
  <xsl:template match="w/lts/a">
    <xsl:if test="$w_cab">
      <xsl:text>&#09;[lts] </xsl:text>
      <xsl:value-of select="@hi"/>
      <xsl:text> &lt;</xsl:text>
      <xsl:value-of select="@w"/>
      <xsl:text>&gt;</xsl:text>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: eqpho -->
  <xsl:template match="w/eqpho/a">
    <xsl:if test="$w_cab">
      <xsl:text>&#09;[eqpho] </xsl:text>
      <xsl:value-of select="@t"/>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: morph -->
  <xsl:template match="w/morph/a">
    <xsl:if test="$w_cab">
      <xsl:text>&#09;[morph] </xsl:text>
      <xsl:value-of select="@hi"/>
      <xsl:text> &lt;</xsl:text>
      <xsl:value-of select="@w"/>
      <xsl:text>&gt;</xsl:text>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: msafe -->
  <xsl:template match="w/msafe">
    <xsl:if test="$w_cab">
      <xsl:text>&#09;[morph/safe] </xsl:text>
      <xsl:value-of select="@safe"/>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: rewrite -->
  <xsl:template match="w/rewrite/a">
    <xsl:if test="$w_cab">
      <xsl:text>&#09;[rw] </xsl:text>
      <xsl:value-of select="@hi"/>
      <xsl:text> &lt;</xsl:text>
      <xsl:value-of select="@w"/>
      <xsl:text>&gt;</xsl:text>
      <xsl:apply-templates select="*"/>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: rw/lts -->
  <xsl:template match="w/rewrite/a/lts/a">
    <xsl:if test="$w_cab">
      <xsl:text>&#09;[rw/lts] </xsl:text>
      <xsl:value-of select="@hi"/>
      <xsl:text> &lt;</xsl:text>
      <xsl:value-of select="@w"/>
      <xsl:text>&gt;</xsl:text>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: morph -->
  <xsl:template match="w/rewrite/a/morph/a">
    <xsl:if test="$w_cab">
      <xsl:text>&#09;[rw/morph] </xsl:text>
      <xsl:value-of select="@hi"/>
      <xsl:text> &lt;</xsl:text>
      <xsl:value-of select="@w"/>
      <xsl:text>&gt;</xsl:text>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: w/a (fallback) -->
  <xsl:template match="w/a">
    <xsl:if test="$w_a">
      <xsl:text>&#09;</xsl:text>
      <xsl:value-of select="$w_a_prefix"/>
      <xsl:value-of select="text()"/>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: default: just recurse -->
  <xsl:template match="*|@*|text()|processing-instruction()|comment()" priority="-1">
    <xsl:apply-templates select="*"/>
  </xsl:template>

</xsl:stylesheet>