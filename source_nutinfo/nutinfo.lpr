program nutinfo;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, tachartlazaruspkg, mainwindow
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Title:='NUTinfo';
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TFmainw, Fmainw);
  Application.Run;
end.

