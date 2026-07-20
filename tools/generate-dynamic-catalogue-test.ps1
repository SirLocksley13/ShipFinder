param(
    [ValidateSet("Test", "Public")]
    [string]$Target = "Test"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$pageSize = 4

if ($Target -eq "Public") {
    $outputRoot = Join-Path $repoRoot "addons\ship-finder-alphabetical-catalogue"
    $guidBase = 2003000
    $lineIdBase = 2003000000
    $shortcutKey = "Control;Alt;F"
    $shortcutIdentifier = "ShipFinderAlphabeticalCatalogueShortcut"
    $variablePrefix = "ShipFinderAlphabeticalDynamic"
    $luaRelativePath = "data/script/shipfinder/select-dynamic-catalogue-ship.lua"
    $requestText = "Ship Finder - Alphabetical Catalogue"
    $indexHeadline = "Alphabetical ship finder"
    $storyName = "Ship Finder Dynamic Alphabetical Storyline"
    $rootName = "Ship Finder Dynamic Alphabetical Root"
    $logPrefix = "Ship Finder Dynamic Catalogue"
}
else {
    $outputRoot = Join-Path $repoRoot "personal\ship-finder-dynamic-text-test"
    $guidBase = 2020000
    $lineIdBase = 2005000000
    $shortcutKey = "Control;Alt;T"
    $shortcutIdentifier = "ShipFinderDynamicTextTestShortcut"
    $variablePrefix = "ShipFinderDynamic"
    $luaRelativePath = "data/script/shipfinder/select-dynamic-test-ship.lua"
    $requestText = "Ship Finder dynamic catalogue test"
    $indexHeadline = "Dynamic alphabetical ship finder"
    $storyName = "Dynamic Ship Finder Test Storyline"
    $rootName = "Dynamic Ship Finder Test Root"
    $logPrefix = "Ship Finder Dynamic Test"
}

$groupVariable = $variablePrefix + "Group"
$pageVariable = $variablePrefix + "Page"
$slotVariable = $variablePrefix + "Slot"
$storyGuid = $guidBase
$rootGuid = $guidBase + 1
$groupSequenceBase = $guidBase + 100
$previousPageSequenceGuid = $guidBase + 130
$nextPageSequenceGuid = $guidBase + 131
$shipSequenceBase = $guidBase + 140

$assetsPath = Join-Path $outputRoot "data\base\config\export\assets.xml"
$textsPath = Join-Path $outputRoot "data\base\config\gui\texts_english.xml"
$luaPath = Join-Path $outputRoot $luaRelativePath.Replace("/", "\")

$script:texts = New-Object System.Collections.Generic.List[object]
$script:nextLineId = $lineIdBase
$script:assets = New-Object System.Collections.Generic.List[string]
$previousSymbol = [char]0x25C0
$nextSymbol = [char]0x25B6

function ConvertTo-XmlText([string]$value) {
    return [System.Security.SecurityElement]::Escape($value)
}

function Add-Text([string]$value) {
    $lineId = $script:nextLineId
    $script:nextLineId++
    [void]$script:texts.Add([pscustomobject]@{ LineId = $lineId; Value = $value })
    return $lineId
}

function New-Option([int]$textId, [int]$target = 0) {
    return [pscustomobject]@{ TextId = $textId; Target = $target }
}

function Add-Decision([int]$guid, [string]$name, [int]$headlineId, [int]$bodyId, [object[]]$options) {
    if ($options.Count -gt 7) {
        throw "Decision $guid has $($options.Count) options; the tested visible maximum is 7."
    }

    $optionXml = foreach ($option in $options) {
        "          <Item><OptionText>$($option.TextId)</OptionText></Item>"
    }
    $outputXml = foreach ($option in $options) {
        if ($option.Target -eq 0) {
            "          <Item />"
        }
        else {
            "          <Item><SuccessOutput><Item><Component>$($option.Target)</Component></Item></SuccessOutput></Item>"
        }
    }

    $escapedName = ConvertTo-XmlText $name
    [void]$script:assets.Add(@"
  <Asset>
    <Template>Decision</Template>
    <Values>
      <Standard><GUID>$guid</GUID><Name>$escapedName</Name></Standard>
      <Decision>
        <DecisionScreenConfig>
          <Headline>$headlineId</Headline>
          <Text>$bodyId</Text>
          <LeftParticipant>41</LeftParticipant>
        </DecisionScreenConfig>
        <DecisionOptions>
$($optionXml -join "`n")
        </DecisionOptions>
      </Decision>
      <QuestComponent />
      <DecisionComponent>
        <DecisionOutputs>
$($outputXml -join "`n")
        </DecisionOutputs>
      </DecisionComponent>
    </Values>
  </Asset>
"@)
}

function New-SetIntAction([string]$variableName, [int]$value, [string]$modifier = "") {
    $modifierXml = if ([string]::IsNullOrEmpty($modifier)) {
        ""
    } else {
        "                  <Modifier>$modifier</Modifier>`n"
    }
    return @"
          <Item>
            <Action>
              <Template>ActionModifyVariable</Template>
              <Values>
                <Action />
                <ActionModifyVariable>
                  <VariableName>$variableName</VariableName>
$modifierXml                  <ModifierVariable><Template>IntVariableOrValue</Template><Values><IntVariableOrValue><IntValue>$value</IntValue></IntVariableOrValue></Values></ModifierVariable>
                </ActionModifyVariable>
              </Values>
            </Action>
          </Item>
"@
}

function New-ExecuteScriptAction([string]$scriptFile) {
    return @"
          <Item>
            <Action>
              <Template>ActionExecuteScript</Template>
              <Values><Action /><ActionExecuteScript><ScriptFileName>$scriptFile</ScriptFileName></ActionExecuteScript></Values>
            </Action>
          </Item>
"@
}

function Add-Sequence([int]$guid, [string]$name, [string[]]$actions, [int]$output = 0) {
    $connector = if ($output -eq 0) {
        "      <QuestComponentConnector />"
    }
    else {
        "      <QuestComponentConnector><Output><Item><Component>$output</Component></Item></Output></QuestComponentConnector>"
    }

    [void]$script:assets.Add(@"
  <Asset>
    <Template>Sequence</Template>
    <Values>
      <Standard><GUID>$guid</GUID><Name>$(ConvertTo-XmlText $name)</Name></Standard>
      <Sequence><SequenceActions>
$($actions -join "`n")
      </SequenceActions></Sequence>
$connector
      <QuestComponent />
    </Values>
  </Asset>
"@)
}

$requestId = Add-Text $requestText
$indexHeadlineId = Add-Text $indexHeadline
$indexBodyId = Add-Text "Choose the first letter of a ship in the current province. Counts are live."
$shipHeadlineId = Add-Text $indexHeadline
$shipBodyId = Add-Text "Choose an exact ship. Blank rows mean that the current page has fewer ships."
$closeId = Add-Text "[X] Close"
$previousIndexId = Add-Text "$previousSymbol$previousSymbol Earlier letters"
$nextIndexId = Add-Text "Later letters $nextSymbol$nextSymbol"
$backToIndexId = Add-Text "[A-Z] Letter index"

$letterTextIds = @{}
for ($group = 1; $group -le 26; $group++) {
    $letter = [char](64 + $group)
    $expression = '{(function() local letter="__LETTER__"; local count=0; local objects=Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}; for _,object in pairs(objects) do if object.Nameable and string.upper(string.sub(tostring(object.Nameable.Name),1,1))==letter then count=count+1 end end; return letter.." ("..tostring(count)..")" end)()}'.Replace("__LETTER__", $letter)
    $letterTextIds[$group] = Add-Text $expression
}
$otherTextId = Add-Text '{(function() local count=0; local objects=Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}; for _,object in pairs(objects) do if object.Nameable then local first=string.upper(string.sub(tostring(object.Nameable.Name),1,1)); if not string.match(first,"^[A-Z]$") then count=count+1 end end end; return "Other ("..tostring(count)..")" end)()}'

$shipTextIds = @{}
for ($slot = 1; $slot -le $pageSize; $slot++) {
    $expression = '{(function() local group=Variables:GetVariable("__GROUP_VARIABLE__") or 0; local page=Variables:GetVariable("__PAGE_VARIABLE__") or 0; local sorted={}; local objects=Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}; for _,object in pairs(objects) do if object.Nameable then local first=string.upper(string.sub(tostring(object.Nameable.Name),1,1)); local matches=(group>=1 and group<=26 and first==string.char(64+group)) or (group==27 and not string.match(first,"^[A-Z]$")); if matches then table.insert(sorted,object) end end end; local function key(name) return string.gsub(string.lower(tostring(name)),"%d+",function(number) return string.format("%020d",tonumber(number)) end) end; table.sort(sorted,function(a,b) local ak,bk=key(a.Nameable.Name),key(b.Nameable.Name); if ak==bk then return a.ID<b.ID end; return ak<bk end); local object=sorted[(page*__PAGE_SIZE__)+__SLOT__]; return object and tostring(object.Nameable.Name) or "" end)()}'.Replace("__GROUP_VARIABLE__", $groupVariable).Replace("__PAGE_VARIABLE__", $pageVariable).Replace("__PAGE_SIZE__", [string]$pageSize).Replace("__SLOT__", [string]$slot)
    $shipTextIds[$slot] = Add-Text $expression
}

$previousPageId = Add-Text ('{(function() local page=Variables:GetVariable("__PAGE_VARIABLE__") or 0; return page>0 and "__PREVIOUS_SYMBOL__ Previous ships" or "" end)()}'.Replace("__PAGE_VARIABLE__", $pageVariable).Replace("__PREVIOUS_SYMBOL__", $previousSymbol))
$nextPageId = Add-Text ('{(function() local group=Variables:GetVariable("__GROUP_VARIABLE__") or 0; local page=Variables:GetVariable("__PAGE_VARIABLE__") or 0; local count=0; local objects=Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}; for _,object in pairs(objects) do if object.Nameable then local first=string.upper(string.sub(tostring(object.Nameable.Name),1,1)); local matches=(group>=1 and group<=26 and first==string.char(64+group)) or (group==27 and not string.match(first,"^[A-Z]$")); if matches then count=count+1 end end end; return count>((page+1)*__PAGE_SIZE__) and "More ships __NEXT_SYMBOL__" or "" end)()}'.Replace("__GROUP_VARIABLE__", $groupVariable).Replace("__PAGE_VARIABLE__", $pageVariable).Replace("__PAGE_SIZE__", [string]$pageSize).Replace("__NEXT_SYMBOL__", $nextSymbol))

$indexDecisionGuids = @(0..6 | ForEach-Object { $guidBase + 10 + $_ })
$shipDecisionGuid = $guidBase + 20

for ($group = 1; $group -le 27; $group++) {
    $sequenceGuid = $groupSequenceBase + $group
    $actions = @(
        (New-SetIntAction $groupVariable $group),
        (New-SetIntAction $pageVariable 0)
    )
    Add-Sequence $sequenceGuid "Open dynamic ship group $group" $actions $shipDecisionGuid
}

Add-Sequence $previousPageSequenceGuid "Previous dynamic ship page" @((New-SetIntAction $pageVariable 1 "Subtract")) $shipDecisionGuid
Add-Sequence $nextPageSequenceGuid "Next dynamic ship page" @((New-SetIntAction $pageVariable 1 "Add")) $shipDecisionGuid

for ($slot = 1; $slot -le $pageSize; $slot++) {
    Add-Sequence ($shipSequenceBase + $slot) "Select dynamic ship row $slot" @(
        (New-SetIntAction $slotVariable $slot),
        (New-ExecuteScriptAction $luaRelativePath)
    )
}

$pageOne = New-Object System.Collections.Generic.List[object]
foreach ($group in 1..5) { [void]$pageOne.Add((New-Option $letterTextIds[$group] ($groupSequenceBase + $group))) }
[void]$pageOne.Add((New-Option $nextIndexId $indexDecisionGuids[1]))
[void]$pageOne.Add((New-Option $closeId))
Add-Decision $indexDecisionGuids[0] "Alphabet index A-E" $indexHeadlineId $indexBodyId $pageOne.ToArray()

$pageTwo = New-Object System.Collections.Generic.List[object]
foreach ($group in 6..9) { [void]$pageTwo.Add((New-Option $letterTextIds[$group] ($groupSequenceBase + $group))) }
[void]$pageTwo.Add((New-Option $previousIndexId $indexDecisionGuids[0]))
[void]$pageTwo.Add((New-Option $nextIndexId $indexDecisionGuids[2]))
[void]$pageTwo.Add((New-Option $closeId))
Add-Decision $indexDecisionGuids[1] "Alphabet index F-I" $indexHeadlineId $indexBodyId $pageTwo.ToArray()

$pageThree = New-Object System.Collections.Generic.List[object]
foreach ($group in 10..13) { [void]$pageThree.Add((New-Option $letterTextIds[$group] ($groupSequenceBase + $group))) }
[void]$pageThree.Add((New-Option $previousIndexId $indexDecisionGuids[1]))
[void]$pageThree.Add((New-Option $nextIndexId $indexDecisionGuids[3]))
[void]$pageThree.Add((New-Option $closeId))
Add-Decision $indexDecisionGuids[2] "Alphabet index J-M" $indexHeadlineId $indexBodyId $pageThree.ToArray()

$pageFour = New-Object System.Collections.Generic.List[object]
foreach ($group in 14..17) { [void]$pageFour.Add((New-Option $letterTextIds[$group] ($groupSequenceBase + $group))) }
[void]$pageFour.Add((New-Option $previousIndexId $indexDecisionGuids[2]))
[void]$pageFour.Add((New-Option $nextIndexId $indexDecisionGuids[4]))
[void]$pageFour.Add((New-Option $closeId))
Add-Decision $indexDecisionGuids[3] "Alphabet index N-Q" $indexHeadlineId $indexBodyId $pageFour.ToArray()

$pageFive = New-Object System.Collections.Generic.List[object]
foreach ($group in 18..21) { [void]$pageFive.Add((New-Option $letterTextIds[$group] ($groupSequenceBase + $group))) }
[void]$pageFive.Add((New-Option $previousIndexId $indexDecisionGuids[3]))
[void]$pageFive.Add((New-Option $nextIndexId $indexDecisionGuids[5]))
[void]$pageFive.Add((New-Option $closeId))
Add-Decision $indexDecisionGuids[4] "Alphabet index R-U" $indexHeadlineId $indexBodyId $pageFive.ToArray()

$pageSix = New-Object System.Collections.Generic.List[object]
foreach ($group in 22..25) { [void]$pageSix.Add((New-Option $letterTextIds[$group] ($groupSequenceBase + $group))) }
[void]$pageSix.Add((New-Option $previousIndexId $indexDecisionGuids[4]))
[void]$pageSix.Add((New-Option $nextIndexId $indexDecisionGuids[6]))
[void]$pageSix.Add((New-Option $closeId))
Add-Decision $indexDecisionGuids[5] "Alphabet index V-Y" $indexHeadlineId $indexBodyId $pageSix.ToArray()

$pageSeven = New-Object System.Collections.Generic.List[object]
[void]$pageSeven.Add((New-Option $letterTextIds[26] ($groupSequenceBase + 26)))
[void]$pageSeven.Add((New-Option $otherTextId ($groupSequenceBase + 27)))
[void]$pageSeven.Add((New-Option $previousIndexId $indexDecisionGuids[5]))
[void]$pageSeven.Add((New-Option $closeId))
Add-Decision $indexDecisionGuids[6] "Alphabet index Z and other" $indexHeadlineId $indexBodyId $pageSeven.ToArray()

$shipOptions = New-Object System.Collections.Generic.List[object]
foreach ($slot in 1..$pageSize) { [void]$shipOptions.Add((New-Option $shipTextIds[$slot] ($shipSequenceBase + $slot))) }
[void]$shipOptions.Add((New-Option $previousPageId $previousPageSequenceGuid))
[void]$shipOptions.Add((New-Option $nextPageId $nextPageSequenceGuid))
[void]$shipOptions.Add((New-Option $backToIndexId $indexDecisionGuids[0]))
Add-Decision $shipDecisionGuid "Live ship page" $shipHeadlineId $shipBodyId $shipOptions.ToArray()

$assetsHeader = @"
<ModOps>
  <ModOp Type="add" GUID="2001271" Path="/Values/ShortcutConfig/InputBindings">
    <Item>
      <Command>GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet($storyGuid)</Command>
      <Active>Session</Active>
      <Identifier>$shortcutIdentifier</Identifier>
      <AvailableOnPlatforms>PC</AvailableOnPlatforms>
      <InputTypes><Modern><KeyType>$shortcutKey</KeyType></Modern><Legacy><KeyType>$shortcutKey</KeyType></Legacy></InputTypes>
    </Item>
  </ModOp>
  <ModOp Type="add" GUID="23779" Path="/Values/ConditionVariableConfiguration/IntVariables">
    <Item><Name>$groupVariable</Name><StartValue>0</StartValue><Comment>Selected alphabetical group</Comment></Item>
    <Item><Name>$pageVariable</Name><StartValue>0</StartValue><Comment>Zero-based page in selected group</Comment></Item>
    <Item><Name>$slotVariable</Name><StartValue>0</StartValue><Comment>One-based row on current page</Comment></Item>
  </ModOp>
  <ModOp Add="/AssetList/Groups[last()]"><Group><Assets /></Group></ModOp>
  <Asset>
    <Template>StoryLine</Template>
    <Values><Standard><GUID>$storyGuid</GUID><Name>$storyName</Name></Standard><StoryLine><StartConnector><Item><Component>$rootGuid</Component></Item></StartConnector></StoryLine><QuestComponent /><QuestComponentConnector /></Values>
  </Asset>
  <Asset>
    <Template>DecisionRoot</Template>
    <Values>
      <Standard><GUID>$rootGuid</GUID><Name>$rootName</Name></Standard>
      <DecisionRoot>
        <DecisionRootOutput><Item /><Item /><Item /></DecisionRootOutput>
        <DecisionRootStartComponent>$($indexDecisionGuids[0])</DecisionRootStartComponent>
        <DecisionGovernorRequest><IsBaseAutoCreateAsset>1</IsBaseAutoCreateAsset><Values><GovernorRequest><RequestDescription>$requestId</RequestDescription><RequestPriority>100</RequestPriority><RequestTimeout>600000</RequestTimeout><RequestIcon>130037</RequestIcon><RequestParticipant>41</RequestParticipant><IsRequestMandatory>0</IsRequestMandatory></GovernorRequest></Values></DecisionGovernorRequest>
        <UIType>Popup</UIType>
      </DecisionRoot>
      <QuestComponent />
    </Values>
  </Asset>
"@

$assetsXml = $assetsHeader + "`n" + ($script:assets -join "`n") + "`n</ModOps>`n"

$textEntries = foreach ($text in $script:texts) {
    "    <Text><Text>$(ConvertTo-XmlText $text.Value)</Text><LineId>$($text.LineId)</LineId></Text>"
}
$textsXml = "<ModOps>`n  <ModOp Add=`"/TextExport/Texts[1]`">`n" + ($textEntries -join "`n") + "`n  </ModOp>`n</ModOps>`n"

$lua = @"
-- Generated dynamic-catalogue click handler. Labels and selection use identical filtering and sorting.
local group = Variables:GetVariable("$groupVariable") or 0
local page = Variables:GetVariable("$pageVariable") or 0
local slot = Variables:GetVariable("$slotVariable") or 0
local objects = Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
local ships = {}

local function isInSelectedGroup(object)
    if object.Nameable == nil then
        return false
    end

    local first = string.upper(string.sub(tostring(object.Nameable.Name), 1, 1))
    if group >= 1 and group <= 26 then
        return first == string.char(64 + group)
    end

    return group == 27 and not string.match(first, "^[A-Z]$")
end

for _, object in pairs(objects) do
    if isInSelectedGroup(object) then
        table.insert(ships, object)
    end
end

local function naturalSortKey(name)
    return string.gsub(string.lower(tostring(name)), "%d+", function(number)
        return string.format("%020d", tonumber(number))
    end)
end

table.sort(ships, function(left, right)
    local leftKey = naturalSortKey(left.Nameable.Name)
    local rightKey = naturalSortKey(right.Nameable.Name)
    if leftKey == rightKey then
        return left.ID < right.ID
    end
    return leftKey < rightKey
end)

local index = (page * $pageSize) + slot
local ship = ships[index]
if ship == nil then
    system.log(
        "[$logPrefix] Empty row selected"
        .. " | Group: " .. tostring(group)
        .. " | Page: " .. tostring(page)
        .. " | Slot: " .. tostring(slot)
    )
    return
end

system.log(
    "[$logPrefix] Selecting live catalogue ship"
    .. " | Group: " .. tostring(group)
    .. " | Page: " .. tostring(page)
    .. " | Slot: " .. tostring(slot)
    .. " | Name: " .. tostring(ship.Nameable.Name)
    .. " | ID: " .. tostring(ship.ID)
)

Selection:SelectByID(ship.ID)
Scripts:JumpToObject(ship.ID)
"@

foreach ($path in @($assetsPath, $textsPath, $luaPath)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($assetsPath, $assetsXml, $utf8NoBom)
[System.IO.File]::WriteAllText($textsPath, $textsXml, $utf8NoBom)
[System.IO.File]::WriteAllText($luaPath, $lua + "`n", $utf8NoBom)

Write-Host "Generated $Target dynamic catalogue"
Write-Host "  Assets: $assetsPath"
Write-Host "  Texts:  $textsPath"
Write-Host "  Lua:    $luaPath"
