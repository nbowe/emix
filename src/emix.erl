%% Copyright (c) 2010 Nikolas Bowe <nikolas.bowe@gmail.com>
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.

-module(emix).
-license("Apache License Version 2.0").
-include_lib("eunit/include/eunit.hrl").

-export([track/2, track_async/2, 
	track_funnel/4, track_funnel_async/4,
	unixtime/0]).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Public API
	
track(Event, Props) ->
	Data = get_data(Event,Props),
	Response = request("GET", "api.mixpanel.com", "/track/", [{data, Data}] ),
	{ok, Http_Code, _HeaderPropList, Resp_Body} = decode_response(Response),
	case {Http_Code, Resp_Body} of
		{200, <<"1">>} ->
			true;
		_ ->
			false
	end.
	
% track_async
track_async(Event, Props) ->
	spawn( fun() -> 
		track(Event, Props)
	end ).

track_funnel(Funnel, Step, Goal, Props) ->
	FunnelProps = [{"funnel",Funnel},{"step",Step},{"goal",Goal}],
	FinalProps = upropmerge(FunnelProps,Props),
	track("mp_funnel", FinalProps).

% track_funnel_async
track_funnel_async(Funnel, Step, Goal, Props) ->
	spawn(fun() ->
		track_funnel(Funnel, Step, Goal, Props)
	end).

% returns unix time in UTC.
unixtime() ->
	DateTimeGregorian = calendar:datetime_to_gregorian_seconds(erlang:universaltime()),
	UnixEpochGregorian = calendar:datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}}),
	DateTimeGregorian - UnixEpochGregorian.
	
	
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
get_data(Event,Props) ->
	JSON = {struct, [ {"event", Event}, {"properties",  {struct, Props}} ]},
	JSONString = mochijson:encode( JSON ),
	base64:encode( list_to_binary(JSONString) ).
	
	
request(Method, Host, URI, DataProplist) ->
	{ok, Socket} = gen_tcp:connect(Host, 80, [binary, {active, false}, {packet, 0}]),
	Req = build_request(Method, Host, URI, DataProplist),
	gen_tcp:send(Socket, Req),
	{ok, Resp} = recv(Socket, []),
	gen_tcp:close(Socket),
	Resp.
    

build_request(Method, Host, URI, DataProplist) ->
	URIQS = [URI, "?", mochiweb_util:urlencode(DataProplist)],
	Request = [Method, " ", URIQS, <<" HTTP/1.0\r\n">>,
		<<"Content-Type: application/json\r\n">>,
		<<"User-Agent: emix\r\n">>,
		<<"Host: ">>, Host, <<"\r\n">>,
		<<"Accept: */*\r\n">>,
		<<"\r\n">>],
	erlang:iolist_to_binary(Request).

% standard http 1.0 recv loop
recv(Socket, Acc) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, B} ->
            recv(Socket, [Acc | B]);
        _ ->
            {ok, Acc}
    end.
	
% standard http response decoding.
%% {ok, Http_Code, HeaderPropList, Resp_Body}
decode_response(Response) ->
	{ok, ResponseCode, Rest} = decode_response_code(erlang:iolist_to_binary(Response)),
	{ok, Headers, Body} = decode_headers(Rest),
	{ok, ResponseCode, Headers, Body}.
decode_response_code(Response) ->
	{ok, HttpResponse, ResponseBody} = erlang:decode_packet(http, Response, []),
	{http_response, _, ResponseCode, _} = HttpResponse,
	{ok, ResponseCode, ResponseBody}.
decode_headers(Data) ->
	decode_headers(Data, []).
decode_headers(Data, Headers) ->
	{ok, Packet, Rest} = erlang:decode_packet(httph_bin, Data, []),
	case Packet of
		{http_header, _, K, _, V} ->
			decode_headers(Rest, [{K,V} | Headers]);
		http_eoh ->
			{ok, Headers, Rest}
	end.

% merge 2 property lists. 
% if an item appears in both the one in List1 is taken.
% if an item appears more than once in a list only 1 value is taken.
upropmerge(List1,List2) ->
	lists:ukeymerge(1, lists:ukeysort(1,List1), lists:ukeysort(1,List2)).
	
