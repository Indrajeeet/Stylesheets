<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xsd="http://www.w3.org/2001/XMLSchema" version="1.0">
    <xsl:output indent="yes" method="html" omit-xml-declaration="yes" />
    
    <xsl:template match="/">
        <html>
            <head>
                <title>Entities</title>
                <style type="text/css">
                    
                    
                    
                    table{
                    font-family: Arial, Helvetica, sans-serif;
                    border-collapse: collapse;
                    width: 100%;
                    }
                    
                    td{
                    border: 1px solid #ddd;
                    
                    }
                    
                    h3,p{display: inline-block;}
                    
                    
                    tr:hover {background-color: #ddd;}
                    
                    th {
                    
                    text-align: center;
                    background-color: #4682B4;
                    color: white;
                    }
                    
                    h3{
                    width: 500px;background-color:#F5F5F5 ;
                    border: 1px; text-align: center;
                    }
                    
                    
                    
                </style>
            </head>
            <body>
                <div class="container">
                    <xsl:apply-templates />
                </div>
            </body>
        </html>
    </xsl:template>
    
    <xsl:template match="xsd:element">
        <tr>
            <td><xsl:value-of select="@name" /></td>
            <td><xsl:value-of select="@type" /></td>
            <td>
                <xsl:choose>
                    <xsl:when test="@minOccurs">
                        <xsl:value-of select="@minOccurs" />
                    </xsl:when>
                    <xsl:otherwise>
                        1
                    </xsl:otherwise>
                </xsl:choose>
                ..
                <xsl:choose>
                    <xsl:when test="@maxOccurs">
                        <xsl:value-of select="@maxOccurs" />
                    </xsl:when>
                    <xsl:otherwise>
                        1
                    </xsl:otherwise>
                </xsl:choose>
            </td>
            
            <td>
                <xsl:value-of select="xsd:element/xsd:simpleType/xsd:restriction" />
            </td>
            
            
            <td>
                <xsl:copy-of select="xsd:annotation/xsd:documentation" />
            </td>
        </tr>
    </xsl:template>
    
    <xsl:template match="xsd:complexType">
        <h3><xsl:value-of select="@name"></xsl:value-of></h3>
        <p><xsl:value-of select="xsd:annotation/xsd:documentation" /></p>
        <table class="table table-striped table-bordered table-hover">
            <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Cardinality</th>
                <th>Restriction</th>
                <th>Description</th>
            </tr>
            
            <xsl:apply-templates select="xsd:sequence|xsd:complexContent|xsd:simpleType|xsd:choice|xsd:all" />
        </table>
    </xsl:template>
    
</xsl:stylesheet>
