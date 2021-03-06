-module(snarl_role_vnode).
-behaviour(riak_core_vnode).
-behaviour(riak_core_aae_vnode).
-include("snarl.hrl").
-include_lib("riak_core/include/riak_core_vnode.hrl").

-export([start_vnode/1,
         init/1,
         terminate/2,
         handle_command/3,
         is_empty/1,
         delete/1,
         handle_handoff_command/3,
         handoff_starting/2,
         handoff_cancelled/1,
         handoff_finished/2,
         handle_handoff_data/2,
         encode_handoff_item/2,
         handle_coverage/4,
         handle_exit/3,
         handle_info/2]).

-export([
         master/0,
         aae_repair/2,
         hash_object/2
        ]).

%% Reads
-export([get/3]).

%% Writes
-export([add/4,
         set_metadata/4,
         import/4,
         delete/3,
         grant/4,
         repair/4, sync_repair/4,
         revoke/4,
         revoke_prefix/4]).

-ignore_xref([
              start_vnode/1,
              get/3,
              add/4,
              delete/3,
              grant/4,
              set_metadata/4,
              import/4,
              repair/4, sync_repair/4,
              revoke/4,
              revoke_prefix/4,
              handle_info/2
             ]).

-define(SERVICE, snarl_role).

-define(MASTER, snarl_role_vnode_master).

%%%===================================================================
%%% AAE
%%%===================================================================

master() ->
    ?MASTER.

hash_object(Key, Obj) ->
    snarl_vnode:hash_object(Key, Obj).

aae_repair(Realm, Key) ->
    lager:debug("AAE Repair: ~p", [Key]),
    snarl_role:get(Realm, Key).

%%%===================================================================
%%% API
%%%===================================================================

start_vnode(I) ->
    riak_core_vnode_master:get_vnode_pid(I, ?MODULE).


repair(IdxNode, Role, VClock, Obj) ->
    riak_core_vnode_master:command(IdxNode,
                                   {repair, Role, VClock, Obj},
                                   ignore,
                                   ?MASTER).

%%%===================================================================
%%% API - reads
%%%===================================================================

get(Preflist, ReqID, Role) ->
    riak_core_vnode_master:command(Preflist,
                                   {get, ReqID, Role},
                                   {fsm, undefined, self()},
                                   ?MASTER).

%%%===================================================================
%%% API - writes
%%%===================================================================

sync_repair(Preflist, ReqID, UUID, Obj) ->
    riak_core_vnode_master:command(Preflist,
                                   {sync_repair, ReqID, UUID, Obj},
                                   {fsm, undefined, self()},
                                   ?MASTER).

set_metadata(Preflist, ReqID, UUID, Attributes) ->
    riak_core_vnode_master:command(Preflist,
                                   {set_metadata, ReqID, UUID, Attributes},
                                   {fsm, undefined, self()},
                                   ?MASTER).

import(Preflist, ReqID, UUID, Import) ->
    riak_core_vnode_master:command(Preflist,
                                   {import, ReqID, UUID, Import},
                                   {fsm, undefined, self()},
                                   ?MASTER).

add(Preflist, ReqID, UUID, Role) ->
    riak_core_vnode_master:command(Preflist,
                                   {add, ReqID, UUID, Role},
                                   {fsm, undefined, self()},
                                   ?MASTER).

delete(Preflist, ReqID, Role) ->
    riak_core_vnode_master:command(Preflist,
                                   {delete, ReqID, Role},
                                   {fsm, undefined, self()},
                                   ?MASTER).

grant(Preflist, ReqID, Role, Val) ->
    riak_core_vnode_master:command(Preflist,
                                   {grant, ReqID, Role, Val},
                                   {fsm, undefined, self()},
                                   ?MASTER).

revoke(Preflist, ReqID, Role, Val) ->
    riak_core_vnode_master:command(Preflist,
                                   {revoke, ReqID, Role, Val},
                                   {fsm, undefined, self()},
                                   ?MASTER).

revoke_prefix(Preflist, ReqID, Role, Val) ->
    riak_core_vnode_master:command(Preflist,
                                   {revoke_prefix, ReqID, Role, Val},
                                   {fsm, undefined, self()},
                                   ?MASTER).
%%%===================================================================
%%% VNode
%%%===================================================================
init([Part]) ->
    snarl_vnode:init(Part, <<"group">>, ?SERVICE, ?MODULE, ft_role).

%%%===================================================================
%%% General
%%%===================================================================

handle_command({add, {ReqID, Coordinator} = ID, {Realm, UUID}, Role}, _Sender, State) ->
    Role0 = ft_role:new(ID),
    Role1 = ft_role:name(ID, Role, Role0),
    Role2 = ft_role:uuid(ID, UUID, Role1),
    RoleObj = ft_obj:new(Role2, Coordinator),
    snarl_vnode:put(Realm, UUID, RoleObj, State),
    {reply, {ok, ReqID}, State};

handle_command(Message, Sender, State) ->
    snarl_vnode:handle_command(Message, Sender, State).

handle_handoff_command(?FOLD_REQ{} = FR, Sender, State) ->
    handle_command(FR, Sender, State);

handle_handoff_command({get, _ReqID, _Vm} = Req, Sender, State) ->
    handle_command(Req, Sender, State);

handle_handoff_command(Req, Sender, State) ->
    S1 = case handle_command(Req, Sender, State) of
             {noreply, NewState} ->
                 NewState;
             {reply, _, NewState} ->
                 NewState
         end,
    {forward, S1}.

handoff_starting(TargetNode, State) ->
    lager:warning("Starting handof to: ~p", [TargetNode]),
    {true, State}.

handoff_cancelled(State) ->
    {ok, State}.

handoff_finished(_TargetNode, State) ->
    {ok, State}.

handle_handoff_data(Data, State) ->
    snarl_vnode:handle_handoff_data(Data, State).


encode_handoff_item(Role, Data) ->
    term_to_binary({Role, Data}).

is_empty(State) ->
    snarl_vnode:is_empty(State).

delete(State) ->
    snarl_vnode:delete(State).

handle_coverage(Req, KeySpaces, Sender, State) ->
    snarl_vnode:handle_coverage(Req, KeySpaces, Sender, State).

handle_exit(_Pid, _Reason, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

handle_info(Msg, State) ->
    snarl_vnode:handle_info(Msg, State).
