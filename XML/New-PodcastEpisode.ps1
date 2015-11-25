function New-PodcastEpisode
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$RssFilePath,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Title,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Link,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Description,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Guid,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Duration,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$SubTitle,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Summary,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Keywords,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Author = 'Todd Klindt',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Explicit = 'no'
	)
	begin {
		$ErrorActionPreference = 'Stop'
		$xRss = New-Object -TypeName System.Xml.XmlDocument
		$xRss.Load($RssFilePath)
	}
	process {
		try
		{	
			$newItem = $xRss.CreateElement('Item')
			
			$subItems = @{
				'title' = $Title
				'link' = $Link
				'description' = $Description
				'author' = $Author
				'guid' = $Guid
				'enclosure' = ''
			}
			
			$iTunesNsItems = @{
				'author' = $Author
				'duration' = $Duration
				'explicit' = $Explicit
				'keywords' = $Keywords
				'subtitle' = $SubTitle
				'summary' = $Summary
			}
			
			foreach ($s in $subItems.GetEnumerator())
			{
				$nodeName = $s.Key
				$nodeVal = $s.Value
				$null = $newItem.AppendChild($xRss.CreateElement($nodeName))
				if ($nodeName -ne 'enclosure')
				{
					$newItem.$nodeName = $nodeVal
				}
			}
			
			$newItem.SelectSingleNode('enclosure').SetAttribute('url', 'test enc URL')
			$newItem.SelectSingleNode('enclosure').SetAttribute('length', '0000')
			$newItem.SelectSingleNode('enclosure').SetAttribute('type', 'audio/mp3')
			$newItem.SelectSingleNode('guid').SetAttribute('isPermaLink', 'true')
			
			$itunesNs = New-Object System.Xml.XmlNamespaceManager($xRss.nametable)
			$itunesNs.addnamespace('itunes', $xRss.rss.channel.GetNamespaceOfPrefix('itunes'))
			
			foreach ($s in $iTunesNsItems.GetEnumerator())
			{
				$nodeName = "itunes:$($s.Key)"
				$nodeVal = $s.Value
				$node = $xRss.CreateElement($nodeName, $itunesNs.LookupNamespace('itunes'))
				$null = $node.AppendChild($xRss.CreateTextNode($nodeVal))
				$null = $newItem.AppendChild($node)
			}
			
			$null = $xRss.SelectSingleNode('rss/channel').AppendChild($newItem)
			$xRss.Save($RssFilePath)
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}