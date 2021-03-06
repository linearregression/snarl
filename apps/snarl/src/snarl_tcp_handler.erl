-module(snarl_tcp_handler).

-include("snarl.hrl").

-include("snarl_version.hrl").

-include_lib("snarl_oauth/include/snarl_oauth.hrl").

-export([init/2, message/2]).

-ignore_xref([init/2, message/2]).

-record(state, {port}).

init(Prot, []) ->
    {ok, #state{port = Prot}}.

%%%===================================================================
%%% General Functions
%%%===================================================================

-type message() ::
        fifo:snarl_message() |
        fifo:snarl_user_message() |
        fifo:snarl_org_message() |
        fifo:snarl_role_message() |
        fifo:snarl_token_message().

-spec message(message(), #state{}) ->
                     {noreply, #state{}} |
                     {reply, term(), #state{}}.

message(version, State) ->
    {reply, {ok, ?VERSION}, State};

%%%===================================================================
%%% Org Functions
%%%===================================================================

message({org, list, Realm}, State) ->
    {reply, snarl_org:list(Realm), State};

message({org, list, Realm, Requirements, Full}, State) ->
    {reply, snarl_org:list(Realm, Requirements, Full), State};

message({org, get, Realm, Org}, State) ->
    {reply, snarl_org:get(Realm, Org), State};

message({org, set_metadata, Realm, Org, Attributes}, State) when
      is_binary(Org) ->
    {reply,
     snarl_org:set_metadata(Realm, Org, Attributes),
     State};

message({org, resource_action, Realm, Org, Resource, TimeStamp, Action, Opts},
        State) when
      is_binary(Realm), is_binary(Org), is_atom(Action), is_list(Opts),
      is_integer(TimeStamp), TimeStamp > 0 ->
    {reply,
     snarl_org:resource_action(Realm, Org, Resource, TimeStamp, Action, Opts),
     State};

message({org, add, Realm, Org}, State) ->
    {reply, snarl_org:add(Realm, Org), State};

message({org, delete, Realm, Org}, State) ->
    {reply, snarl_org:delete(Realm, Org), State};

message({org, trigger, add, Realm, Org, Trigger}, State) ->
    {reply, snarl_org:add_trigger(Realm, Org, Trigger), State};

message({org, trigger, remove, Realm, Org, Trigger}, State) ->
    {reply, snarl_org:remove_trigger(Realm, Org, Trigger), State};

message({org, trigger, execute, Realm, Org, Event, Payload}, State) ->
    {reply, snarl_org:trigger(Realm, Org, Event, Payload), State};

%%%===================================================================
%%% User Functions
%%%===================================================================

message({user, list, Realm}, State) ->
    {reply, snarl_user:list(Realm), State};

message({user, list, Realm, Requirements, Full}, State) ->
    {reply, snarl_user:list(Realm, Requirements, Full), State};

message({user, get, Realm, {token, Token}}, State) ->
    case snarl_token:get(Realm, Token) of
        not_found ->
            {reply, not_found, State};
        {ok, User} ->
            message({user, get, Realm, User}, State)
    end;

message({user, get, Realm, User}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:get(Realm, User),
     State};

message({user, token, Realm, User}, State) when
    is_binary(User) ->
    {reply,
     snarl_token:add(Realm, User),
     State};

message({user, keys, find, Realm, KeyID}, State) when
      is_binary(KeyID) ->
    {reply,
     snarl_user:find_key(Realm, KeyID),
     State};

message({user, keys, get, Realm, User}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:keys(Realm, User),
     State};

message({user, keys, add, Realm, User, KeyId, Key}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:add_key(Realm, User, KeyId, Key),
     State};

message({user, keys, revoke, Realm, User, KeyId}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:revoke_key(Realm, User, KeyId),
     State};


message({user, yubikeys, get, Realm, User}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:yubikeys(Realm, User),
     State};

message({user, yubikeys, add, Realm, User, OTP}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:add_yubikey(Realm, User, OTP),
     State};

message({user, yubikeys, remove, Realm, User, KeyId}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:remove_yubikey(Realm, User, KeyId),
     State};

message({user, set_metadata, Realm, User, Attributes}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:set_metadata(Realm, User, Attributes),
     State};

message({user, lookup, Realm, User}, State) when is_binary(User) ->
    {reply,
     snarl_user:lookup(Realm, User),
     State};

message({user, cache, Realm, {token, Token}}, State = #state{}) ->
    case snarl_token:get(Realm, Token) of
        not_found ->
            {reply, not_found, State};
        {ok, User} ->
            message({user, cache, Realm, User}, State)
    end;

message({user, cache, Realm, User}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:cache(Realm, User),
     State};

message({user, add, Realm, User}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:add(Realm, User),
     State};

message({user, add, Realm, Creator, User}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:add(Realm, Creator, User),
     State};

message({user, auth, Realm, User, Pass}, State) when
      is_binary(User),
      is_binary(Pass) ->
    message({user, auth, Realm, User, Pass, <<>>}, State);

message({user, auth, Realm, User, Pass, basic}, State) when
      is_binary(User),
      is_binary(Pass) ->
    Res = case snarl_user:auth(Realm, User, Pass, basic) of
              not_found ->
                  {error, not_found};
              {ok, UUID}  ->
                  {ok, UUID}
          end,
    {reply,
     Res,
     State};

message({user, auth, Realm, User, Pass, OTP}, State) when
      is_binary(User),
      is_binary(Pass),
      is_binary(OTP) ->
    Res = case snarl_user:auth(Realm, User, Pass, OTP) of
              not_found ->
                  {error, not_found};
              {ok, UUID}  ->
                  {ok, Token} = snarl_token:add(Realm, UUID),
                  {ok, {token, Token}}
          end,
    {reply,
     Res,
     State};

message({user, allowed, Realm, {token, Token}, Permission}, State) ->
    case snarl_token:get(Realm, Token) of
        not_found ->
            {reply, false, State};
        {ok, User} ->
            {reply,
             snarl_user:allowed(Realm, User, Permission),
             State}
    end;

message({user, allowed, Realm, User, Permission}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:allowed(Realm, User, Permission),
     State};

message({user, delete, Realm, User}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:delete(Realm, User),
     State};

message({user, passwd, Realm, User, Pass}, State) when
      is_binary(User),
      is_binary(Pass) ->
    {reply,
     snarl_user:passwd(Realm, User, Pass),
     State};

message({user, join, Realm, User, Role}, State) when
      is_binary(User),
      is_binary(Role) ->
    {reply, snarl_user:join(Realm, User, Role), State};

message({user, leave, Realm, User, Role}, State) when
      is_binary(User),
      is_binary(Role) ->
    {reply, snarl_user:leave(Realm, User, Role), State};

message({user, grant, Realm, User, Permission}, State) when
      is_binary(User) ->
    {reply, snarl_user:grant(Realm, User, Permission), State};

message({user, revoke, Realm, User, Permission}, State) when
      is_binary(User) ->
    {reply, snarl_user:revoke(Realm, User, Permission), State};

message({user, revoke_prefix, Realm, User, Prefix}, State) when
      is_binary(User) ->
    {reply, snarl_user:revoke_prefix(Realm, User, Prefix), State};

message({token, delete, Realm, Token}, State) when
      is_binary(Token) ->
    {reply, snarl_token:delete(Realm, Token), State};

message({user, org, get, Realm, User}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:orgs(Realm, User),
     State};

message({user, org, active, Realm, User}, State) when
      is_binary(User) ->
    {reply,
     snarl_user:active(Realm, User),
     State};

message({user, org, join, Realm, User, Org}, State) when
      is_binary(User),
      is_binary(Org) ->
    {reply, snarl_user:join_org(Realm, User, Org), State};

message({user, org, leave, Realm, User, Org}, State) when
      is_binary(User),
      is_binary(Org) ->
    {reply, snarl_user:leave_org(Realm, User, Org), State};

message({user, org, select, Realm, User, Org}, State) when
      is_binary(User),
      is_binary(Org) ->
    {reply, snarl_user:select_org(Realm, User, Org), State};


%%%===================================================================
%%% Client Functions
%%%===================================================================

message({client, list, Realm}, State) ->
    {reply, snarl_client:list(Realm), State};

message({client, list, Realm, Requirements, Full}, State) ->
    {reply, snarl_client:list(Realm, Requirements, Full), State};

message({client, get, Realm, Client}, State) when
      is_binary(Client) ->
    {reply, snarl_client:get(Realm, Client), State};


message({client, name, Realm, Client, Name}, State) when
      is_binary(Client),
      is_binary(Name) ->
    {reply, snarl_client:name(Realm, Client, Name), State};


message({client, token, Realm, Client}, State) when
    is_binary(Client) ->
    {reply, snarl_token:add(Realm, Client), State};

message({client, uris, get, Realm, Client}, State) when
      is_binary(Client) ->
    {reply, snarl_client:uris(Realm, Client), State};

message({client, uris, add, Realm, Client, OTP}, State) when
      is_binary(Client) ->
    {reply, snarl_client:add_uri(Realm, Client, OTP), State};

message({client, uris, remove, Realm, Client, KeyId}, State) when
      is_binary(Client) ->
    {reply, snarl_client:remove_uri(Realm, Client, KeyId), State};

message({client, set_metadata, Realm, Client, Attributes}, State) when
      is_binary(Client) ->
    {reply, snarl_client:set_metadata(Realm, Client, Attributes), State};

message({client, lookup, Realm, Client}, State) when is_binary(Client) ->
    {reply, snarl_client:lookup(Realm, Client), State};

message({client, add, Realm, Client}, State) when
      is_binary(Client) ->
    {reply, snarl_client:add(Realm, Client), State};

message({client, add, Realm, Creator, Client}, State) when
      is_binary(Client) ->
    {reply, snarl_client:add(Realm, Creator, Client), State};

message({client, auth, Realm, Client, Secret}, State) when
      is_binary(Client),
      is_binary(Secret) ->
    {reply, snarl_client:auth(Realm, Client, Secret), State};

message({client, allowed, Realm, {token, Token}, Permission}, State) ->
    case snarl_token:get(Realm, Token) of
        not_found ->
            {reply, false, State};
        {ok, Client} ->
            {reply, snarl_client:allowed(Realm, Client, Permission), State}
    end;

message({client, allowed, Realm, Client, Permission}, State) when
      is_binary(Client) ->
    {reply, snarl_client:allowed(Realm, Client, Permission), State};

message({client, delete, Realm, Client}, State) when
      is_binary(Client) ->
    {reply, snarl_client:delete(Realm, Client), State};

message({client, secret, Realm, Client, Secret}, State) when
      is_binary(Client),
      is_binary(Secret) ->
    {reply, snarl_client:secret(Realm, Client, Secret), State};

message({client, join, Realm, Client, Role}, State) when
      is_binary(Client),
      is_binary(Role) ->
    {reply, snarl_client:join(Realm, Client, Role), State};

message({client, leave, Realm, Client, Role}, State) when
      is_binary(Client),
      is_binary(Role) ->
    {reply, snarl_client:leave(Realm, Client, Role), State};

message({client, grant, Realm, Client, Permission}, State) when
      is_binary(Client) ->
    {reply, snarl_client:grant(Realm, Client, Permission), State};

message({client, revoke, Realm, Client, Permission}, State) when
      is_binary(Client) ->
    {reply, snarl_client:revoke(Realm, Client, Permission), State};

message({client, revoke_prefix, Realm, Client, Prefix}, State) when
      is_binary(Client) ->
    {reply, snarl_client:revoke_prefix(Realm, Client, Prefix), State};

%%%===================================================================
%%% Role Functions
%%%===================================================================

message({role, list, Realm}, State) ->
    {reply, snarl_role:list(Realm), State};

message({role, list, Realm, Requirements, Full}, State) ->
    {reply, snarl_role:list(Realm, Requirements, Full), State};

message({role, get, Realm, Role}, State) ->
    {reply, snarl_role:get(Realm, Role), State};

message({role, set_metadata, Realm, Role, Attributes}, State) when
      is_binary(Role) ->
    {reply,
     snarl_role:set_metadata(Realm, Role, Attributes),
     State};

message({role, add, Realm, Role}, State) ->
    {reply, snarl_role:add(Realm, Role), State};

message({role, delete, Realm, Role}, State) ->
    {reply, snarl_role:delete(Realm, Role), State};

message({role, grant, Realm, Role, Permission}, State) when
      is_binary(Role),
      is_list(Permission)->
    {reply, snarl_role:grant(Realm, Role, Permission), State};

message({role, revoke, Realm, Role, Permission}, State) ->
    {reply, snarl_role:revoke(Realm, Role, Permission), State};

message({role, revoke_prefix, Realm, Role, Prefix}, State) ->
    {reply, snarl_role:revoke_prefix(Realm, Role, Prefix), State};


%%%===================================================================
%%% OAuth2 Functions
%%%===================================================================

message({oauth2, scope, Realm}, State) ->
    {reply,
     snarl_oauth:scope(Realm),
     State};

message({oauth2, scope, Realm, Subscope}, State) ->
    {reply,
     snarl_oauth:scope(Realm, Subscope),
     State};

%%-export([authorize_password/3]).
message(
  {oauth2, authorize_password, Realm, User, Scope}, State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:authorize_password(User, Scope, Ctx)),
     State};
%%-export([authorize_password/4]).
message(
  {oauth2, authorize_password, Realm, User, Client, Scope}, State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:authorize_password(User, Client, Scope, Ctx)),
     State};

%%-export([authorize_password/5]).
message(
  {oauth2, authorize_password, Realm, User, Client, RedirUri, Scope},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:authorize_password(User, Client, RedirUri, Scope, Ctx)),
     State};

%% -export([authorize_client_credentials/3]).
message(
  {oauth2, authorize_client_credentials, Realm, Client, Scope},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:authorize_client_credentials(Client, Scope, Ctx)),
     State};

%% -export([authorize_code_grant/4]).
message(
  {oauth2, authorize_code_grant, Realm, Client, Code, RedirUri},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:authorize_code_grant(Client, Code, RedirUri, Ctx)),
     State};

%% -export([authorize_code_request/5]).
message(
  {oauth2, authorize_code_request, Realm, User, Client, RedirUri, Scope},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:authorize_code_request(User, Client, RedirUri, Scope, Ctx)),
     State};

%% -export([issue_code/2]).
message(
  {oauth2, issue_code, Realm, Auth},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:issue_code(Auth, Ctx)),
     State};

%% -export([issue_token/2]).
message(
  {oauth2, issue_token, Realm, Auth},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:issue_token(Auth, Ctx)),
     State};

%% -export([issue_token_and_refresh/2]).
message(
  {oauth2, issue_token_and_refresh, Realm, Auth},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:issue_token_and_refresh(Auth, Ctx)),
     State};

%% -export([verify_access_token/2]).
message(
  {oauth2, verify_access_token, Realm, Token},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:verify_access_token(Token, Ctx)),
     State};

%% -export([verify_access_code/2]).
message(
  {oauth2, verify_access_code, Realm, AccessCode},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:verify_access_code(AccessCode, Ctx)),
     State};

%% -export([verify_access_code/3]).
message(
  {oauth2, verify_access_code, Realm, AccessCode, Client},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:verify_access_code(AccessCode, Client, Ctx)),
     State};

%% -export([refresh_access_token/4]).
message(
  {oauth2, refresh_access_token, Realm, Client, RefreshToken, Scope},
  State) ->
    Ctx = #oauth_state{realm = Realm},
    {reply,
     oauth_reply(oauth2:refresh_access_token(Client, RefreshToken, Scope, Ctx)),
     State};


%%%===================================================================
%%% Internal
%%%===================================================================

message({cloud, status}, State) ->
    {reply,
     status(),
     State};

message(Message, State) ->
    lager:warning("Unsuppored TCP message: ~p", [Message]),
    {noreply, State}.

status() ->
    Warnings = case riak_core_status:transfers() of
                   {[], []} ->
                       [];
                   {[], L} ->
                       W = jsxd:from_list(
                             [{<<"category">>, <<"snarl">>},
                              {<<"element">>, <<"handoff">>},
                              {<<"type">>, <<"info">>},
                              {<<"message">>, bin_fmt("~b handofs pending.",
                                                      [length(L)])}]),
                       [W];
                   {S, []} ->
                       server_errors(S);
                   {S, L} ->
                       W = jsxd:from_list(
                             [{<<"category">>, <<"snarl">>},
                              {<<"element">>, <<"handoff">>},
                              {<<"type">>, <<"info">>},
                              {<<"message">>, bin_fmt("~b handofs pending.",
                                                      [length(L)])}]),
                       [W | server_errors(S)]
               end,
    {ok, {[], ordsets:from_list(Warnings)}}.


server_errors(Servers) ->
    lists:map(fun (Server) ->
                      jsxd:from_list(
                        [{<<"category">>, <<"snarl">>},
                         {<<"element">>, list_to_binary(atom_to_list(Server))},
                         {<<"type">>, <<"critical">>},
                         {<<"message">>, bin_fmt("Snarl server ~s down.", [Server])}])
              end, Servers).

bin_fmt(F, L) ->
    list_to_binary(io_lib:format(F, L)).

oauth_reply({ok, {_, Reply}}) ->
    {ok, Reply};
oauth_reply(Reply) ->
    Reply.
