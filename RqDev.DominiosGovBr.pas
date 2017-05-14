{
  DOMÍNIOS GOV.BR
  ( http://dados.gov.br/dataset/dominios-gov-br )

  = DESCRIÇÃO
  Informações sobre os domínios Gov.br registrados no
  [Registro.br](https://registro.br/) e autorizados pelo
  Ministério do Planejamento.
  Contém todos os domínios autorizados e seus respectivos responsáveis.
  Estão disponíveis as URL, o CNPJ e nome do Órgão, localidade, assim como
  as datas de registro e da última atualização dos dados de registro do
  domínio. =

  Desenvolvido por: https://github.com/riquedev/
}
unit RqDev.DominiosGovBr;

interface

uses
  IdHttp, SysUtils, superobject, Classes, EZCrypt, xmldom, XMLIntf, StdCtrls,
  msxmldom, XMLDoc;

const
  DGB_HOST = 'http://dados.gov.br/';
  DGB_PATH = 'api/action/datastore_search';
  DGB_METHOD = '?resource_id=';
  DGB_RESOURCE_ID = '197a0106-c93b-42fc-bb4e-c3095baee1a0';
  DGB_FILE_CRIPT_NAME = 'cript_DominiosGovBr.rq';
  DGB_FILE_NAME = 'DominiosGovBr.xml';

type
  TDominiosGovBr = class
    constructor Create(Path: string = '/DGB/'; Enc01: Word = 152;
      Enc02: Word = 156; Enc03: Word = 105);
  public
    function DecodeToXml(const CriptFile: string; const OutputFile: string;
      Enc01: Word = 152; Enc02: Word = 156; Enc03: Word = 105): Boolean;

  private
  protected
    TripleKey: TWordTriple;
    RUrl: string;
    OPath: string;
    procedure Download(const SFile: string);
    function OnlyLetters(const _Str: string): string;
  end;

implementation

{ TDominiosGovBr }

constructor TDominiosGovBr.Create(Path: string = '/DGB/'; Enc01: Word = 152;
  Enc02: Word = 156; Enc03: Word = 105);
begin
  // Link para atualização dos dados;
  Self.RUrl := DGB_HOST + DGB_PATH + DGB_METHOD + DGB_RESOURCE_ID;

  // Caminho de Download
  Path := ExtractFilePath(ParamStr(0)) + Path;
  Self.OPath := Path;
  // Código triplo de segurança
  Self.TripleKey[0] := Enc01;
  Self.TripleKey[1] := Enc02;
  Self.TripleKey[2] := Enc03;

  // Se o diretório não existir, será criado.
  if not DirectoryExists(Self.OPath) then
    MkDir(Self.OPath);

  // Se o arquivo não existir o download será realizad.
  if not FileExists(Self.OPath + '/' + DGB_FILE_CRIPT_NAME) then
    Self.Download(Self.OPath + '/' + DGB_FILE_NAME);

end;

function TDominiosGovBr.DecodeToXml(const CriptFile: string;
  const OutputFile: string; Enc01: Word = 152; Enc02: Word = 156;
  Enc03: Word = 105): Boolean;
begin
  try
    Self.TripleKey[0] := Enc01;
    Self.TripleKey[1] := Enc02;
    Self.TripleKey[2] := Enc03;
    Result := FileDecrypt(CriptFile, OutputFile, Self.TripleKey);
  except
    Result := False;
  end;
end;

procedure TDominiosGovBr.Download(const SFile: string);
const
  DocEncode = 'utf-8';
var
  tmpUrl: string;
  Channel: TIdHTTP;
  JSON, JRES: ISuperObject;
  JData: TSuperArray;
  HaveFields: Boolean;
  I: integer;
  XMLDoc: IXMLDocument;
  RootNode, FieldsNode, RecordsNode, CurNode: IXMLNode;
begin
  tmpUrl := Self.RUrl;
  XMLDoc := NewXMLDocument;
  XMLDoc.Encoding := DocEncode;
  XMLDoc.Options := [doNodeAutoIndent];
  RootNode := XMLDoc.AddChild('Dominios');
  FieldsNode := RootNode.AddChild('fields');
  RecordsNode := RootNode.AddChild('records');
  try
    while (True) do
    begin
      // Inicando Canal para requisção;
      Channel := TIdHTTP.Create(nil);
      try
        // Podemos ser redirecionados
        Channel.HandleRedirects := True;

        // Pega JSON
        JSON := SO(Channel.Get(tmpUrl));

        // Obtém resultados
        JRES := JSON.O['result'];

        // Já foram preenchido os campos?
        if not HaveFields then
        begin
          JData := JRES.A['fields'];
          for I := 0 to JData.Length - 1 do
          begin
            CurNode := FieldsNode.AddChild(Self.OnlyLetters(JData[I].S['id']));
            CurNode.Attributes['id'] := JData[I].S['id'];
            CurNode.Attributes['type'] := JData[I].S['type'];
          end;
          HaveFields := True;
        end;
        // Pegando dados
        JData := JRES.A['records'];
        // Se não houver dados, damos o fora
        if JData.Length = 0 then
          break
        else
        begin
          // Se tiver, vamos dar ctrl + c | ctrl + v
          for I := 0 to JData.Length - 1 do
          begin
            CurNode := RecordsNode.AddChild
              (Self.OnlyLetters(Trim(JData[I].S['dominio'])));
            CurNode.Attributes['id'] := JData[I].I['_id'];
            CurNode.Attributes['dominio'] := JData[I].S['dominio'];
            CurNode.Attributes['documento'] := JData[I].S['documento'];
            CurNode.Attributes['nome'] := JData[I].S['nome'];
            CurNode.Attributes['uf'] := JData[I].S['uf'];
            CurNode.Attributes['cidade'] := JData[I].S['cidade'];
            CurNode.Attributes['cep'] := JData[I].S['cep'];
            CurNode.Attributes['data_cadastro'] := JData[I].S['data_cadastro'];
            CurNode.Attributes['ultima_atualizacao'] :=
              JData[I].S['ultima_atualizacao'];
            CurNode.Attributes['ticket'] := JData[I].I['ticket'];
          end;

          // Próxima página
          JRES := JRES.O['_links'];

          // Url da próxima página
          tmpUrl := DGB_HOST + JRES.S['next'];

        end;

      finally
        // Fecha canal
        Channel.Disconnect;

        // Limpa o canal
        Channel.Free;
      end;
    end;
  finally
    // Salva nosso XML <3
    XMLDoc.SaveToFile(SFile);

    // Encripta ele, porque sim.
    if FileEncrypt(SFile, Self.OPath + '/' + DGB_FILE_CRIPT_NAME, Self.TripleKey)
    then
      DeleteFile(SFile); // Deleta o descriptografado.

  end;
end;

function TDominiosGovBr.OnlyLetters(const _Str: string): string;
var
  I: integer;
begin
  Result := '';
  for I := 1 to Length(_Str) do
    if _Str[I] in ['a' .. 'z', 'A' .. 'Z'] then
      Result := Result + _Str[I];

end;

end.
