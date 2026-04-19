# Rainmeter

## [SquarePlayer](https://github.com/Meti0X7CB/SquarePlayer) 3.4

Coordinates: 1000 1260

<details>
<summary>SquarePlayer S4.ini</summary>

```ini
[Metadata]
Name = SquarePlayer
Author = Meti0X7CB
Information = "A sleek player widget for Win 11 to control all your media"
Version = 3.4
License = GNU General Public License v3.0

[RainMeter]
Update = 60
AccurateText = 1

;Change the Scale value to match your monitor scaling in windows (If Windows is 100% -> Scale = 1 , Windows = 150% -> Scale = 1.5)
;To change the text color, change Color/SubColor/Highlight value to desired R,G,B numbers (Color = 255,0,0 for example red)
;For transparent widget, change the FrostLevel and CornerType value to None
;For light windows themes, change the Theme value to Light1-5 (Theme = Light4 , Theme = Dark4 is the default dark theme value)

[Variables]
Scale = 1.3
Color = 240,240,240
SubColor = 199,199,199
Highlight = 254,105,105
FrostLevel = Acrylic
Theme = Dark
CornerType = Round
PlayerId = "Active"
@include = "#@#MeasureBandsS.inc"

[MeasureStatus]
Measure = Plugin
Plugin = WebNowPlaying
PlayerType = Status
PlayerId = #PlayerId#
IfCondition = MeasureStatus = 1
IfTrueAction = [!ShowFade][!ShowMeterGroup "Active"]
IfFalseAction = [!HideFade]

[MeasureCover]
Measure = Plugin
Plugin = WebNowPlaying
PlayerType = Cover
PlayerId = #PlayerId#
DefaultPath = #@#Default.png
DynamicVariables = 1
Group = Active

[FrostedGlass]
Measure = Plugin
Plugin = FrostedGlass
Type = #FrostLevel#
Border = None
Corner = #CornerType#
Backdrop = #Theme#
BorderVisible = 0
Group = Active

[MeterCanvas]
Meter = Shape
Shape = Rectangle 0,0,(420*#Scale#),(48*#Scale#),5 | Fill Color 0,0,0,1 | StrokeWidth 0
Group = Active

[MeterCoverContainer]
Meter = Shape
Shape = Rectangle 0,0,(32*#Scale#),(32*#Scale#),5 | Fill Color 0,0,0,255 | StrokeWidth 0
X = (10*#Scale#)
Y = (9*#Scale#)
Group = Active


[MeterCover]
Meter = Image
MeasureName = MeasureCover
W = (32*#Scale#)
H = (32*#Scale#)
Container = MeterCoverContainer
PreserveAspectRatio = 2
DynamicVariables = 1
IfTrueAction = [!Refresh]
Group = Active

[MeasureTitle]
Measure = Plugin
Plugin = WebNowPlaying
PlayerType = Title
PlayerId = #PlayerId#
DynamicVariables = 1
Substitute = "0":""
Group = Active

[MeterTitle]
Meter = String
MeasureName = MeasureTitle
X = (50*#Scale#)
Y = (8*#Scale#)
W = (100*#Scale#)
H = (16*#Scale#)
FontColor = #Color#
FontSize = (9*#Scale#)
FontFace = SF Pro Regular
IfTrueAction = [!ShowMeterGroup "Active"][!SetOption FrostedGlass Type "#FrostLevel#"][!UpdateMeasure FrostedGlass][!Refresh]
IfFalseAction = [!HideMeterGroup "Active"][!SetOption FrostedGlass Type "None"][!UpdateMeasure FrostedGlass][!Refresh]
FontWeight = 600
AntiAlias = 1
ClipString = 1
StringAlign = Left
DynamicVariables = 1
Group = Active

[MeasureArtist]
Measure = Plugin
Plugin = WebNowPlaying
PlayerType = Artist
PlayerId = #PlayerId#
DynamicVariables = 1
Substitute = "0":""
Group = Active

[MeterArtist]
Meter = String
MeasureName = MeasureArtist
X = (50*#Scale#)
Y = (24*#Scale#)
W = (100*#Scale#)
H = (16*#Scale#)
FontColor = #SubColor#
FontSize = (9*#Scale#)
FontFace = SF Pro Regular
FontWeight = 600
AntiAlias = 1
ClipString = 1
StringAlign = Left
DynamicVariables = 1
Group = Active

[MeasurePlayPause]
Measure = Plugin
Plugin = WebNowPlaying
PlayerType = State
PlayerId = #PlayerId#
Substitute = "0":"Play","1":"Pause","2":"Play","3":"Replay"
DynamicVariables = 1
Group = Active

[MeterPrev]
Meter = Image
ImageName = #@#Previous.png
X = (181*#Scale#)
Y = (17*#Scale#)
W = (17*#Scale#)
H = (17*#Scale#)
AntiAlias = 1
ImageTint = #Color#
LeftMouseDownAction = [!CommandMeasure MeasurePlayPause "Previous"][!SetOption MeterPrev ImageTint "#Highlight#"]
LeftMouseUpAction = [!SetOption MeterPrev ImageTint "#Color#"]
MouseOverAction = [!SetOption MeterPrev ImageAlpha "127"]
MouseLeaveAction = [!SetOption MeterPrev ImageAlpha "255"]
DynamicVariables = 1
Group = Active

[MeterPlayPause]
Meter = Image
ImageName = #@#[MeasurePlayPause].png
X = (206*#Scale#)
Y = (17*#Scale#)
W = (17*#Scale#)
H = (17*#Scale#)
AntiAlias = 1
ImageTint = #Color#
LeftMouseDownAction = [!CommandMeasure MeasurePlayPause "PlayPause"][!SetOption MeterPlayPause ImageTint "#Highlight#"]
LeftMouseUpAction = [!SetOption MeterPlayPause ImageTint "#Color#"]
MouseOverAction = [!SetOption MeterPlayPause ImageAlpha "127"]
MouseLeaveAction = [!SetOption MeterPlayPause ImageAlpha "255"]
DynamicVariables = 1
Group = Active

[MeterNext]
Meter = Image
ImageName = #@#Next.png
X = (231*#Scale#)
Y = (17*#Scale#)
W = (17*#Scale#)
H = (17*#Scale#)
AntiAlias = 1
ImageTint = #Color#
LeftMouseDownAction = [!CommandMeasure MeasurePlayPause "Next"][!SetOption MeterNext ImageTint "#Highlight#"]
LeftMouseUpAction = [!SetOption MeterNext ImageTint "#Color#"]
MouseOverAction = [!SetOption MeterNext ImageAlpha "127"]
MouseLeaveAction = [!SetOption MeterNext ImageAlpha "255"]
DynamicVariables = 1
Group = Active

[MeterBands]
Meter = Shape
Shape   = Rectangle ((330+(6*0))*#Scale#),(((24*[MeasureBand0]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand0]*#Scale#),0,0 | Extend Style
Shape2  = Rectangle ((330+(6*1))*#Scale#),(((24*[MeasureBand1]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand1]*#Scale#),0,0 | Extend Style
Shape3  = Rectangle ((330+(6*2))*#Scale#),(((24*[MeasureBand2]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand2]*#Scale#),0,0 | Extend Style
Shape4  = Rectangle ((330+(6*3))*#Scale#),(((24*[MeasureBand3]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand3]*#Scale#),0,0 | Extend Style
Shape5  = Rectangle ((330+(6*4))*#Scale#),(((24*[MeasureBand4]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand4]*#Scale#),0,0 | Extend Style
Shape6  = Rectangle ((330+(6*5))*#Scale#),(((24*[MeasureBand5]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand5]*#Scale#),0,0 | Extend Style
Shape7  = Rectangle ((330+(6*6))*#Scale#),(((24*[MeasureBand6]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand6]*#Scale#),0,0 | Extend Style
Shape8  = Rectangle ((330+(6*7))*#Scale#),(((24*[MeasureBand7]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand7]*#Scale#),0,0 | Extend Style
Shape9  = Rectangle ((330+(6*8))*#Scale#),(((24*[MeasureBand8]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand8]*#Scale#),0,0 | Extend Style
Shape10 = Rectangle ((330+(6*9))*#Scale#),(((24*[MeasureBand9]*#Scale#)/-2)+(48*#Scale#)/2),(2*#Scale#),(24*[MeasureBand9]*#Scale#),0,0 | Extend Style
Style = Fill Color #Color# | StrokeWidth 0
AntiAlias = 1
DynamicVariables = 1
Group = Active

```

</details>
