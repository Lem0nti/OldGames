unit ikAnimation_FR;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, ABL.VS.VSTypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, ikAnimation_Cl;

type
  TAnimationFR = class(TFrame)
    Image: TImage;
    bOk: TButton;
    Timer: TTimer;
    procedure TimerTimer(Sender: TObject);
    procedure bOkClick(Sender: TObject);
  private
    { Private declarations }
    Animation: TAnimation;
  public
    { Public declarations }
    function InitAnimation(StringList: TStringList): TNotifyEvent;
  end;

implementation

{$R *.dfm}

{ TFrame1 }

procedure TAnimationFR.bOkClick(Sender: TObject);
begin
  if not Timer.Enabled then
  begin
    Timer.Enabled:=true;
    Timer.Tag:=0;
  end;
end;

function TAnimationFR.InitAnimation(StringList: TStringList): TNotifyEvent;
begin
  Animation:=TAnimation.Create(StringList);
  Height:=Animation.MaxHeight+12;
  result:=bOkClick;
end;

procedure TAnimationFR.TimerTimer(Sender: TObject);
{var
  ImageDataHeader: PImageDataHeader;
  bmp: TBitmap;
  y: integer;
  ByteArrayFrom,ByteArrayTo: PByteArray;
  tmpPointer: Pointer;       }
begin
{  ImageDataHeader:=Animation.Frames[Timer.Tag];
  if assigned(ImageDataHeader) then
  begin
    bmp:=TBitmap.Create;
    try
      bmp.PixelFormat:=pf24bit;
      bmp.SetSize(ImageDataHeader.Width+ImageDataHeader.Left,ImageDataHeader.Height+ImageDataHeader.Top);
      bmp.Canvas.Brush.Color:=clBlack;
      bmp.Canvas.FillRect(Rect(0,0,bmp.Width,bmp.Height));
      ByteArrayFrom:=ImageDataHeader.Data;
      for y := 0 to ImageDataHeader.Height-1 do
      begin
        ByteArrayTo:=bmp.ScanLine[y+ImageDataHeader.Top];
        Move(ByteArrayFrom[y*ImageDataHeader.Width*3],ByteArrayTo[ImageDataHeader.Left*3],ImageDataHeader.Width*3);
      end;
      Image.Picture.Assign(bmp);
    finally
      FreeAndNil(bmp);
    end;
  end;
  Timer.Tag:=Timer.Tag+1;
  if Timer.Tag>=Animation.Frames.Count then
    Timer.Enabled:=false;       }
    //Timer.Tag:=0;
end;

end.
