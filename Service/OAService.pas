unit OAService;

interface

uses
  SysUtils, Classes, IdHTTP, SuperObject;

type
  TOAService = class(TDataModule)
    IdHTTP1: TIdHTTP;
  private
    { Private declarations }
    FBaseUrl: string;
    FApiKey: string;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent; BaseUrl, ApiKey: string); reintroduce;
    function CreateWorkflow(Title, Creator, FormData: string): string;
  end;

var
  OASvc: TOAService;

implementation

{$R *.dfm}

{ TOAService }

constructor TOAService.Create(AOwner: TComponent; BaseUrl, ApiKey: string);
begin
  inherited Create(AOwner);
  FBaseUrl := BaseUrl;
  FApiKey := ApiKey;
end;

function TOAService.CreateWorkflow(Title, Creator, FormData: string): string;
var
  Url: string;
  Json: ISuperObject;
  StringStream: TStringStream;
  Resp: string;
begin
  Result := '';
  Url := FBaseUrl + '/api/workflow/create';

  Json := SO();
  Json.S['api_key'] := FApiKey;
  Json.S['title'] := Title;
  Json.S['creator'] := Creator;
  Json.S['data'] := FormData;

  StringStream := TStringStream.Create(Json.AsJSon, TEncoding.UTF8);
  try
    try
      IdHTTP1.Request.ContentType := 'application/json';
      Resp := IdHTTP1.Post(Url, StringStream);
      Result := Resp; // Return raw response or parse ID
    except
      on E: Exception do
        Result := 'Error: ' + E.Message;
    end;
  finally
    StringStream.Free;
  end;
end;

end.
