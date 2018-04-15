program DelphiBuilder;

uses
  Vcl.Forms,
  DelphiBuilderS in 'DelphiBuilderS.pas' {MainForm},
  plCommandRedirect in 'plCommandRedirect.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
