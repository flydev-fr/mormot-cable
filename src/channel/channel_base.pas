unit channel_base;

interface

uses 
  mormot.core.base,
  mormot.core.collections;

type
  TChannelBase = class
  public
    procedure PerformAction(const Action: string; const Data: IKeyValue<RawUtf8, Variant>); virtual; abstract;
  end;

implementation

end.

