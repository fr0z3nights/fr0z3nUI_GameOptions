param(
  [string]$AddonRoot = (Resolve-Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path)
)

$mediaDir = Join-Path $AddonRoot 'textures'
$outFile  = Join-Path $mediaDir 'textures.lua'

if (-not (Test-Path $mediaDir)) {
  throw "Textures folder not found: $mediaDir"
}

function Escape-LuaString {
  param([string]$Value)
  if ($null -eq $Value) { return '' }
  $slash = '\\'
  $doubleSlash = '\\\\'
  $quote = [string][char]34
  $escapedQuote = $slash + $quote
  return $Value.Replace($slash, $doubleSlash).Replace($quote, $escapedQuote)
}

$items = Get-ChildItem -Path $mediaDir -Filter '*.tga' -File | Sort-Object Name

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('---@diagnostic disable: undefined-global')
$lines.Add('')
$lines.Add('-- Auto-generated helper list for the UI texture picker.')
$lines.Add('-- WoW addons cannot enumerate files at runtime; regenerate when media changes.')
$lines.Add('')
$lines.Add('local addonName, ns = ...')
$lines.Add('if type(ns) ~= "table" then ns = {} end')
$lines.Add('')
$lines.Add('ns.TexturesMediaTextures = {')

foreach ($f in $items) {
  $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $label = $name
  if ($label -match '^PB\d+_') {
    $label = $label -replace '^PB\d+_', ''
  }

  $luaLabel = Escape-LuaString -Value $label
  $luaValue = Escape-LuaString -Value $name
  $lines.Add('  { "' + $luaLabel + '", "' + $luaValue + '" },')
}

$lines.Add('}')
$lines.Add('')

Set-Content -Path $outFile -Value $lines -Encoding UTF8
Write-Host "Wrote $($items.Count) textures to $outFile"
