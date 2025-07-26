program InterKarate;

uses
  Vcl.Forms,
  ikMain_FM in 'ikMain_FM.pas' {MainFM},
  ikAnimation_Cl in 'ikAnimation_Cl.pas',
  ikGameRender_TH in 'ikGameRender_TH.pas',
  bass in 'bass.pas',
  ikComListen_TH in 'ikComListen_TH.pas',
  ikMatchTimer_TH in 'ikMatchTimer_TH.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainFM, MainFM);
  Application.Run;
end.
