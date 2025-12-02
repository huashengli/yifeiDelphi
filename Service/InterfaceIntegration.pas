unit InterfaceIntegration;

interface

uses
  SysUtils, Classes, DB, ADODB, DbConService, WeComService, OAService, SuperObject;

type
  TInterfaceManager = class
  private
    FWeCom: TWeComService;
    FOA: TOAService;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SyncNewOrdersToWeCom;
    procedure SyncPurchaseRequestsToOA;
  end;

implementation

{ TInterfaceManager }

constructor TInterfaceManager.Create;
begin
  // Initialize services.
  // In a real application, read these from a config file or DB
  FWeCom := TWeComService.Create(nil, 'CORP_ID', 'CORP_SECRET');
  FOA := TOAService.Create(nil, 'http://oa.example.com', 'API_KEY');
end;

destructor TInterfaceManager.Destroy;
begin
  FWeCom.Free;
  FOA.Free;
  inherited;
end;

procedure TInterfaceManager.SyncNewOrdersToWeCom;
var
  Qry: TADOQuery;
begin
  Qry := TADOQuery.Create(nil);
  try
    // Use the connection from DbConService (defined in the framework)
    Qry.Connection := ConService.conMain;

    // Adjusted to use standard YiFei ERP columns:
    // COPTG: Order Header Table
    // TG001: Order Type
    // TG002: Order No
    // TG003: Order Date
    // TG004: Customer ID
    // TG013: Total Amount (Pre-tax usually)
    // UDF01: Custom Field (User Defined Field) - used here as Sync Flag
    Qry.SQL.Text := 'SELECT TG001, TG002, TG004, TG013 FROM COPTG ' +
                    'WHERE TG003 = CONVERT(varchar, GETDATE(), 112) AND (UDF01 IS NULL OR UDF01 = '''')';
    try
      Qry.Open;

      while not Qry.Eof do
      begin
        // Send notification to WeCom
        if FWeCom.SendMessage('@all',
          Format('New Order Received: %s-%s, Customer: %s, Amount: %f',
          [Qry.FieldByName('TG001').AsString, Qry.FieldByName('TG002').AsString,
           Qry.FieldByName('TG004').AsString, Qry.FieldByName('TG013').AsFloat])) then
        begin
          // Mark as synced
          Qry.Connection.Execute(
            Format('UPDATE COPTG SET UDF01 = ''Y'' WHERE TG001 = ''%s'' AND TG002 = ''%s''',
            [Qry.FieldByName('TG001').AsString, Qry.FieldByName('TG002').AsString]));
        end;

        Qry.Next;
      end;
    except
      on E: Exception do
      begin
        // Log error (simple file logging for now)
        // In production, use a proper logging system
      end;
    end;
  finally
    Qry.Free;
  end;
end;

procedure TInterfaceManager.SyncPurchaseRequestsToOA;
var
  Qry: TADOQuery;
  FormData: ISuperObject;
begin
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := ConService.conMain;

    // Adjusted for YiFei Purchase Table (PURTA)
    // PURTA: Purchase Request Header
    // TA001: Request Type
    // TA002: Request No
    // TA012: Requester ID
    // TA018: Approval Status ('N' = Unapproved)
    // TA029: Total Amount
    // UDF02: Custom Flag
    Qry.SQL.Text := 'SELECT TA001, TA002, TA012, TA029 FROM PURTA ' +
                    'WHERE TA018 = ''N'' AND (UDF02 IS NULL OR UDF02 = '''')';
    try
      Qry.Open;

      while not Qry.Eof do
      begin
        FormData := SO();
        FormData.S['request_type'] := Qry.FieldByName('TA001').AsString;
        FormData.S['request_no'] := Qry.FieldByName('TA002').AsString;
        FormData.D['amount'] := Qry.FieldByName('TA029').AsFloat;

        // Call OA API
        FOA.CreateWorkflow(
          'Purchase Approval: ' + Qry.FieldByName('TA001').AsString + '-' + Qry.FieldByName('TA002').AsString,
          Qry.FieldByName('TA012').AsString,
          FormData.AsJSon
        );

        // Update flag
        Qry.Connection.Execute(
          Format('UPDATE PURTA SET UDF02 = ''Sent'' WHERE TA001 = ''%s'' AND TA002 = ''%s''',
          [Qry.FieldByName('TA001').AsString, Qry.FieldByName('TA002').AsString]));

        Qry.Next;
      end;
    except
      on E: Exception do
      begin
        // Log error
      end;
    end;
  finally
    Qry.Free;
  end;
end;

end.
