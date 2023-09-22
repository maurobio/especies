{===============================================================================}
{                             B i o W S   Library                               }
{                                                                               }
{       A General-Purpose Library of Routines for Fetching Data From Several    }
{                       Online Biodiversity Databases                           }
{                                                                               }
{                            Version 1.0, July 2023                             }
{                            Version 2.0, August 2023                           }
{                                                                               }
{             Author: Mauro J. Cavalcanti, Rio de Janeiro, BRASIL               }
{                          E-mail: <maurobio@gmail.com>                         }
{                                                                               }
{  This program is free software; you can redistribute it and/or modify         }
{  it under the terms of the GNU General Public License as published by         }
{  the Free Software Foundation; either version 3 of the License, or            }
{  (at your option) any later version.                                          }
{                                                                               }
{  This program is distributed in the hope that it will be useful,              }
{  but WITHOUT ANY WARRANTY; without even the implied warranty of               }
{  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the                 }
{  GNU General Public License for more details.                                 }
{                                                                               }
{  You should have received a copy of the GNU General Public License            }
{  along with this program. If not, see <http://www.gnu.org/licenses/>.         }
{===============================================================================}
unit BioWS;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, fpjson, jsonparser, DOM, XMLRead, XPath, LPDNetU,
  base64;

type

  { TGBIFSearch }

  TGBIFSearch = class(TObject) { Search GBIF (http://www.gbif.org) }
  private
    Fauthorship: string;
    Fclasse: string;
    Ffamily: string;
    Fkey: integer;
    Fkingdom: string;
    Forder: string;
    Fphylum: string;
    Fscientificname: string;
    Fstatus: string;
    Fvalid_name: string;
  public
    GBIF_URL: string;
    constructor Create;
    function Search(const searchStr: string): boolean;
    function Count(key: integer): integer;
    property key: integer read Fkey write Fkey;
    property scientificname: string read Fscientificname write Fscientificname;
    property authorship: string read Fauthorship write Fauthorship;
    property status: string read Fstatus write Fstatus;
    property valid_name: string read Fvalid_name write Fvalid_name;
    property kingdom: string read Fkingdom write Fkingdom;
    property phylum: string read Fphylum write Fphylum;
    property classe: string read Fclasse write Fclasse;
    property order: string read Forder write Forder;
    property family: string read Ffamily write Ffamily;
  end;

  { TNCBISearch }

  TNCBISearch = class(TObject)
    { Search NCBI's Entrez taxonomy database (http://www.ncbi.nlm.nih.gov/Entrez) }
  private
    Fcommonname: string;
    Fdivision: string;
    Fid: integer;
    FnucNum: integer;
    FprotNum: integer;
    Fscientificname: string;
  public
    NCBI_URL: string;
    linklist: TStringList;
    constructor Create;
    destructor Destroy; override;
    function Summary(const searchStr: string): boolean;
    function Links(id: integer): TStringList;
    property id: integer read Fid write Fid;
    property division: string read Fdivision write Fdivision;
    property scientificname: string read Fscientificname write Fscientificname;
    property commonname: string read Fcommonname write Fcommonname;
    property nucNum: integer read FnucNum write FnucNum;
    property protNum: integer read FprotNum write FprotNum;
  end;

  TWikiSearch = class(TObject) { Search Wikipedia (http://en.wikipedia.org) articles }
  public
    WIKIPEDIA_URL: string;
    WIKIMEDIA_URL: string;
    WIKIPEDIA_REDIRECT_URL: string;
    candidates: TStringList;
    constructor Create;
    destructor Destroy; override;
    function Snippet(const searchStr: string): string;
    function Images(const searchStr: string; limit: integer = 10): TStringList;
  end;

  TFFSearch = class(TObject) { Search FiveFilters }
  public
    FF_URL: string;
    Lines: TStringList;
    constructor Create;
    destructor Destroy; override;
    function termExtract(const contextStr: string; limit: integer = 10): TStringList;
  end;

  TPubMedSearch = class(TObject) { Search PubMed }
  public
    PUBMED_URL: string;
    references: TStringList;
    constructor Create;
    destructor Destroy; override;
    function Search(const searchStr: string; limit: integer = 10): TStringList;
  end;

implementation

{ TGBIFSearch methods }

constructor TGBIFSearch.Create;
begin
  GBIF_URL := 'http://api.gbif.org/v1';
  Fauthorship := '';
  Fclasse := '';
  Ffamily := '';
  Fkey := 0;
  Fkingdom := '';
  Forder := '';
  Fphylum := '';
  Fscientificname := '';
  Fstatus := '';
  Fvalid_name := '';
end;

function TGBIFSearch.Search(const searchStr: string): boolean;
var
  jd: TJSONData;
  jo: TJSONObject;
  json: string;
  Client: THttpClient;
  i: integer;
begin
  Result := False;
  Client := THttpClient.Create;
  if Client.Get(GBIF_URL + '/species/?name=' +
    StringReplace(searchStr, ' ', '%20', [rfReplaceAll]), json) and (json <> '') then
  begin
    jd := GetJson(json);
    if (jd.FindPath('results') = nil) or
      (TJSONArray(jd.FindPath('results')).Count = 0) then
    begin
      jd.Free;
      exit;
    end;
    jo := TJSONObject(TJSONArray(jd.FindPath('results')).Items[0]);
    for i := 0 to jo.Count - 1 do
    begin
      case jo.Names[i] of
        'key': Fkey := jo.Items[i].AsInteger;
        'canonicalName': Fscientificname := jo.Items[i].AsString;
        'authorship': Fauthorship := jo.Items[i].AsString;
        'taxonomicStatus':
        begin
          Fstatus := LowerCase(StringReplace(jo.Items[i].AsString,
            '_', ' ', [rfReplaceAll]));
          if Fstatus <> 'accepted' then
            Fvalid_name := jo.Items[jo.IndexOfName('species')].AsString;
        end;
        'kingdom': Fkingdom := jo.Items[i].AsString;
        'phylum': Fphylum := jo.Items[i].AsString;
        'class': Fclasse := jo.Items[i].AsString;
        'order': Forder := jo.Items[i].AsString;
        'family': Ffamily := jo.Items[i].AsString;
      end;
    end;
    jd.Free;
    Result := True;
  end;
  Client.Free;
end;

function TGBIFSearch.Count(key: integer): integer;
var
  jd: TJSONData;
  json: string;
  Client: THttpClient;
begin
  Result := -1;
  Client := THttpClient.Create;
  if Client.Get(GBIF_URL + '/occurrence/search?taxonKey=' + IntToStr(key), json) and
    (json <> '') then
  begin
    jd := GetJson(json);
    if jd.FindPath('count') <> nil then
      Result := jd.FindPath('count').AsInteger;
    jd.Free;
  end;
  Client.Free;
end;

{ TNCBISearch methods }

constructor TNCBISearch.Create;
begin
  NCBI_URL := 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/';
  linklist := TStringList.Create;
  linklist.NameValueSeparator := '|';
  Fcommonname := '';
  Fdivision := '';
  Fid := 0;
  FnucNum := 0;
  FprotNum := 0;
  Fscientificname := '';
end;

destructor TNCBISearch.Destroy;
begin
  linklist.Free;
  inherited Destroy;
end;

function TNCBISearch.Summary(const searchStr: string): boolean;
var
  XmlData: ansistring;
  Doc: TXMLDocument;
  Client: THttpClient;
  ms: TMemoryStream;
begin
  Result := False;
  Client := THttpClient.Create;
  ms := TMemoryStream.Create;
  { Get taxon id }
  if Client.Get(NCBI_URL + 'esearch.fcgi?db=taxonomy&term=' +
    StringReplace(searchStr, ' ', '+', [rfReplaceAll]), ms) and (ms.Size > 0) then
  begin
    ms.Position := 0;
    ReadXMLFile(Doc, ms);
    with EvaluateXPathExpression('/eSearchResult/IdList/Id', Doc.DocumentElement) do
    begin
      TryStrToInt(AsText, Fid);
      Free;
    end;
    Doc.Free;
  end;
  { Get summary data }
  ms.Clear;
  Client.Clear;
  if Client.Get(NCBI_URL + 'esummary.fcgi?db=taxonomy&id=' + IntToStr(Fid) +
    '&retmode=xml', ms) and (ms.Size > 0) then
  begin
    ms.Position := 0;
    ReadXMLFile(Doc, ms);
    with EvaluateXPathExpression('/eSummaryResult/DocSum/Item[@Name="Division"]',
        Doc.DocumentElement) do
    begin
      Fdivision := AsText;
      Free;
    end;
    with EvaluateXPathExpression('/eSummaryResult/DocSum/Item[@Name="ScientificName"]',
        Doc.DocumentElement) do
    begin
      Fscientificname := AsText;
      Free;
    end;
    with EvaluateXPathExpression('/eSummaryResult/DocSum/Item[@Name="CommonName"]',
        Doc.DocumentElement) do
    begin
      Fcommonname := AsText;
      Free;
    end;
    Doc.Free;
  end;
  { Get nucleotide sequences }
  ms.Clear;
  Client.Clear;
  if Client.Get(NCBI_URL + 'esearch.fcgi?db=nucleotide&term=' +
    StringReplace(searchStr, ' ', '+', [rfReplaceAll]), ms) and (ms.Size > 0) then
  begin
    ms.Position := 0;
    ReadXMLFile(Doc, ms);
    with EvaluateXPathExpression('/eSearchResult/Count', Doc.DocumentElement) do
    begin
      TryStrToInt(AsText, FnucNum);
      Free;
    end;
    Doc.Free;
  end;
  { Get protein sequences }
  ms.Clear;
  Client.Clear;
  if Client.Get(NCBI_URL + 'esearch.fcgi?db=protein&term=' +
    StringReplace(searchStr, ' ', '+', [rfReplaceAll]), ms) and (ms.Size > 0) then
  begin
    ms.Position := 0;
    ReadXMLFile(Doc, ms);
    with EvaluateXPathExpression('/eSearchResult/Count', Doc.DocumentElement) do
    begin
      TryStrToInt(AsText, FprotNum);
      Free;
    end;
    Doc.Free;
  end;
  Client.Free;
  ms.Free;
  Result := Fid <> 0;
end;

function TNCBISearch.Links(id: integer): TStringList;
var
  Doc: TXMLDocument;
  Result1, Result2: TXPathVariable;
  NodeSet1, NodeSet2: TNodeSet;
  i: integer;
  Client: THttpClient;
  ms: TMemoryStream;
begin
  linklist.Clear;
  Client := THttpClient.Create;
  ms := TMemoryStream.Create;
  { Get list of links }
  if Client.Get(NCBI_URL + 'elink.fcgi?dbfrom=taxonomy&id=' +
    IntToStr(id) + '&cmd=llinkslib', ms) and (ms.Size > 0) then
  begin
    ms.Position := 0;
    ReadXMLFile(Doc, ms);
    Result1 := EvaluateXPathExpression('//ObjUrl/Url', Doc.DocumentElement);
    Result2 := EvaluateXPathExpression('//ObjUrl/Provider/Name', Doc.DocumentElement);
    NodeSet1 := Result1.AsNodeSet;
    NodeSet2 := Result2.AsNodeSet;
    for i := 0 to NodeSet1.Count - 1 do
      linklist.Add(TDomElement(NodeSet1.Items[i]).TextContent + '|' +
        TDomElement(NodeSet2.Items[i]).TextContent);
    Result1.Free;
    Result2.Free;
    Doc.Free;
  end;
  Client.Free;
  ms.Free;
  Result := linklist;
end;

{ TWikiSearch methods }

constructor TWikiSearch.Create;
begin
  WIKIPEDIA_URL := 'https://en.wikipedia.org/api/rest_v1/page/summary/';
  WIKIMEDIA_URL := 'https://en.wikipedia.org/api/rest_v1/page/media-list/';
  WIKIPEDIA_REDIRECT_URL := 'https://en.wikipedia.org/w/api.php?action=query&titles=';
  candidates := TStringList.Create;
end;

destructor TWikiSearch.Destroy;
begin
  candidates.Free;
  inherited Destroy;
end;

function TWikiSearch.Snippet(const searchStr: string): string;
var
  jd: TJSONData;
  json, queryStr: string;
  Client: THttpClient;
begin
  Result := '';
  Client := THttpClient.Create;
  { Allow redirections }
  if Client.Get(WIKIPEDIA_REDIRECT_URL + StringReplace(searchStr, ' ',
    '+', [rfReplaceAll]) + '&redirects&format=json', json) and (json <> '') then
  begin
    jd := GetJson(json);
    if jd.FindPath('query.redirects[0].to') <> nil then
      queryStr := jd.FindPath('query.redirects[0].to').AsString
    else
      queryStr := searchStr;
    jd.Free;
  end;
  json := '';
  client.Clear;
  if Client.Get(WIKIPEDIA_URL + StringReplace(queryStr, ' ', '_', [rfReplaceAll]),
    json) and (json <> '') then
  begin
    jd := GetJson(json);
    if jd.FindPath('extract') <> nil then
      Result := jd.FindPath('extract').AsUnicodeString;
    jd.Free;
  end;
  Client.Free;
end;

function TWikiSearch.Images(const searchStr: string; limit: integer = 10): TStringList;
var
  jd: TJsonData;
  ja: TJSONArray;
  jo: TJSONObject;
  i, Count: integer;
  json, queryStr, ext: string;
  Client: THttpClient;
begin
  candidates.Clear;
  Client := THttpClient.Create;
  { Allow redirections }
  if Client.Get(WIKIPEDIA_REDIRECT_URL + StringReplace(searchStr, ' ',
    '+', [rfReplaceAll]) + '&redirects&format=json', json) and (json <> '') then
  begin
    jd := GetJson(json);
    if jd.FindPath('query.redirects[0].to') <> nil then
      queryStr := jd.FindPath('query.redirects[0].to').AsString
    else
      queryStr := searchStr;
    jd.Free;
  end;
  Count := 0;
  Client.Clear;
  json := '';
  if Client.Get(WIKIMEDIA_URL + StringReplace(queryStr, ' ', '_', [rfReplaceAll]),
    json) and (json <> '') then
  begin
    jd := GetJson(json);
    if jd.FindPath('items') <> nil then
    begin
      ja := TJSONArray(jd.FindPath('items'));
      for i := 0 to ja.Count - 1 do
      begin
        jo := TJSONObject(ja.Items[i]);
        if jo.FindPath('title') <> nil then
        begin
          ext := LowerCase(ExtractFileExt(jo.FindPath('title').AsString));
          if (ext = '.jpg') then
          begin
            candidates.Add(jo.FindPath('title').AsString);
            Inc(Count);
            if Count >= limit then
              break;
          end;
        end;
      end;
    end;
    jd.Free;
  end;
  Client.Free;
  Result := candidates;
end;

{ TFFSearch methods }

constructor TFFSearch.Create;
begin
  FF_URL := 'http://termextract.fivefilters.org/';
  Lines := TStringList.Create;
end;

destructor TFFSearch.Destroy;
begin
  Lines.Free;
  inherited Destroy;
end;

{ Provides a list of significant words or phrases extracted from a larger content from FiveFilters Web service }

function TFFSearch.termExtract(const contextStr: string;
  limit: integer = 10): TStringList;
var
  TextData: ansistring;
  Client: THttpClient;
begin
  Lines.Clear;
  Client := THttpClient.Create;
  if Client.Get(FF_URL + 'extract.php?text=' +
    StringReplace(contextStr, ' ', '+', [rfReplaceAll]) + '&output=txt&max=' +
    IntToStr(limit), textdata) and (textdata <> '') then
    Lines.Text := StringReplace(TextData, '\n', LineEnding,
      [rfReplaceAll, rfIgnoreCase]);
  Client.Free;
  Result := Lines;
end;

{ TPubMedSearch methods }

constructor TPubMedSearch.Create;
begin
  PUBMED_URL := 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/';
  references := TStringList.Create;
end;

destructor TPubMedSearch.Destroy;
begin
  references.Free;
  inherited Destroy;
end;

function TPubMedSearch.Search(const searchStr: string; limit: integer = 10): TStringList;
var
  Doc: TXMLDocument;
  Result1, Result2: TXPathVariable;
  NodeSet1, NodeSet2, Ids: TNodeSet;
  id: string;
  i: integer;
  Client: THttpClient;
  ms: TMemoryStream;
begin
  references.Clear;
  Client := THttpClient.Create;
  ms := TMemoryStream.Create;
  { Get reference ids }
  if Client.Get(PUBMED_URL + 'esearch.fcgi?db=pubmed&retmax=' +
    IntToStr(limit) + '&sort=relevance&term=' +
    StringReplace(searchStr, ' ', '+', [rfReplaceAll]), ms) and (ms.Size > 0) then
  begin
    ms.Position := 0;
    ReadXMLFile(Doc, ms);
    Result1 := EvaluateXPathExpression('/eSearchResult/IdList/Id', Doc.DocumentElement);
    Ids := Result1.AsNodeSet;
    id := '';
    for i := 0 to Ids.Count - 1 do
      id := id + TDomElement(Ids.Items[i]).TextContent + ',';
    Result1.Free;
    Doc.Free;
  end;
  { Get list of references }
  ms.Clear;
  Client.Clear;
  if Client.Get(PUBMED_URL + 'efetch.fcgi?db=pubmed&id=' + id + '&retmode=xml', ms) and
    (ms.Size > 0) then
  begin
    ms.Position := 0;
    ReadXMLFile(Doc, ms);
    Result1 := EvaluateXPathExpression('//Article/ArticleTitle', Doc.DocumentElement);
    Result2 := EvaluateXPathExpression(
      '//PubmedData/ArticleIdList/ArticleId[@IdType="doi"]', Doc.DocumentElement);
    NodeSet1 := Result1.AsNodeSet;
    NodeSet2 := Result2.AsNodeSet;
    if NodeSet1.Count > 0 then
    begin
      for i := 0 to NodeSet1.Count - 1 do
        try
          references.Add(TDomElement(NodeSet1.Items[i]).TextContent +
            '=' + TDomElement(NodeSet2.Items[i]).TextContent);
        except
          continue;
        end;
    end;
    Result1.Free;
    Result2.Free;
    Doc.Free;
  end;
  Client.Free;
  ms.Free;
  Result := references;
end;

end.
