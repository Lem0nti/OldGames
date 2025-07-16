program VideoSport;

uses
  Vcl.Forms,
  vsMain_FM in 'vsMain_FM.pas' {MainFM},
  vsGameRender_TH in 'vsGameRender_TH.pas',
  vsScore_Cl in 'vsScore_Cl.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainFM, MainFM);
  Application.Run;
end.
