unit naming;

interface

uses
  SysUtils;

type
  TNaming = class
  public
    class function ChannelName(AChannelClass: TClass): string;
  end;

implementation

class function TNaming.ChannelName(AChannelClass: TClass): string;
begin
  Result := AChannelClass.ClassName.Replace('Channel', '').Replace('::', ':').ToLower;
end;

end.

