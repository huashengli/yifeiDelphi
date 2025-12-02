unit WeComService;

interface

uses
  SysUtils, Classes, IdHTTP, IdSSLOpenSSL, SuperObject;

type
  TWeComService = class(TDataModule)
    IdHTTP1: TIdHTTP;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    FCorpId: string;
    FCorpSecret: string;
    FAccessToken: string;
    FTokenExpireTime: TDateTime;
    function GetAccessToken: string;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent; CorpId, CorpSecret: string); reintroduce;
    function SendMessage(UserIds: string; MsgContent: string): Boolean;
  end;

var
  WeComSvc: TWeComService;

implementation

{$R *.dfm}

{ TWeComService }

constructor TWeComService.Create(AOwner: TComponent; CorpId, CorpSecret: string);
begin
  inherited Create(AOwner);
  FCorpId := CorpId;
  FCorpSecret := CorpSecret;
end;

procedure TWeComService.DataModuleCreate(Sender: TObject);
begin
  // Set up SSL Handler for HTTPS
  // Note: Ensure libeay32.dll and ssleay32.dll are in the application directory
  IdHTTP1.IOHandler := TIdSSLIOHandlerSocketOpenSSL.Create(IdHTTP1);
  TIdSSLIOHandlerSocketOpenSSL(IdHTTP1.IOHandler).SSLOptions.Method := sslvTLSv1_2;

  IdHTTP1.HandleRedirects := True;
  IdHTTP1.Request.ContentType := 'application/json';
end;

function TWeComService.GetAccessToken: string;
var
  Url: string;
  Resp: string;
  Json: ISuperObject;
begin
  if (FAccessToken <> '') and (Now < FTokenExpireTime) then
  begin
    Result := FAccessToken;
    Exit;
  end;

  Url := Format('https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=%s&corpsecret=%s', [FCorpId, FCorpSecret]);
  try
    Resp := IdHTTP1.Get(Url);
    Json := SO(Resp);
    if Json.I['errcode'] = 0 then
    begin
      FAccessToken := Json.S['access_token'];
      // Set expire time (7200 seconds, but we subtract 200s for safety)
      FTokenExpireTime := Now + ((Json.I['expires_in'] - 200) / 86400);
      Result := FAccessToken;
    end
    else
      Result := '';
  except
    Result := '';
  end;
end;

function TWeComService.SendMessage(UserIds: string; MsgContent: string): Boolean;
var
  Token: string;
  Url: string;
  Json: ISuperObject;
  Resp: string;
  RespJson: ISuperObject;
  StringStream: TStringStream;
begin
  Result := False;
  Token := GetAccessToken;
  if Token = '' then Exit;

  Url := Format('https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=%s', [Token]);

  Json := SO();
  Json.S['touser'] := UserIds;
  Json.S['msgtype'] := 'text';
  Json.I['agentid'] := 1000001; // Ideally pass AgentID in constructor too
  Json.O['text'] := SO();
  Json.O['text'].S['content'] := MsgContent;

  StringStream := TStringStream.Create(Json.AsJSon, TEncoding.UTF8);
  try
    try
      Resp := IdHTTP1.Post(Url, StringStream);
      RespJson := SO(Resp);
      if RespJson.I['errcode'] = 0 then
        Result := True;
    except
      Result := False;
    end;
  finally
    StringStream.Free;
  end;
end;

end.
