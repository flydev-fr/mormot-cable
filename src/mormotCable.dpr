program httpServerRaw;

{.$define PUREMORMOT2} // to be set application wide

{$I mormot.defines.inc}

{$ifdef OSWINDOWS}
  {$apptype console}
  {$R mormot.win.default.manifest.res}
{$endif OSWINDOWS}

uses
  sysutils,
  classes,
  mormot.core.log,
  cable_server in 'cable_server.pas',
  init in 'init.pas',
  ws_handler in 'ws_handler.pas',
  token in 'token\token.pas',
  ws_const in 'http_server\ws_const.pas',
  ws_server in 'http_server\ws_server.pas',
  base in 'channel\base.pas',
  broadcasting in 'channel\broadcasting.pas',
  callbacks in 'channel\callbacks.pas',
  naming in 'channel\naming.pas',
  periodic_timers in 'channel\periodic_timers.pas',
  streams in 'channel\streams.pas',
  chat_channel in 'chat_channel.pas',
  channel_base in 'channel\channel_base.pas';

var
  LogFamily: TSynLogFamily;
  //simpleServer: TActionCableServer; 

begin
  LogFamily := TSynLog.Family;
  LogFamily.Level := LOG_VERBOSE;
  LogFamily.PerThreadLog := ptIdentifiedInOneFile;
  LogFamily.AutoFlushTimeOut := 5;
  LogFamily.HighResolutionTimestamp := true;
  LogFamily.EchoToConsole := LOG_VERBOSE;
  
  LogFamily.NoFile := true; // no file

  {$I-}

end.
