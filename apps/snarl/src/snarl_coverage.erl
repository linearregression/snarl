-module(snarl_coverage).

-include("snarl.hrl").

-behaviour(riak_core_coverage_fsm).

-export([
         init/2,
         process_results/2,
         finish/2,
         start/3
        ]).

-ignore_xref([start/3]).

-record(state, {replies, r, reqid, from}).

start(VNodeMaster, NodeCheckService, Request) ->
    ReqID = mk_reqid(),
    snarl_entity_coverage_fsm_sup:start_coverage(
      ?MODULE, {self(), ReqID, something_else},
      {VNodeMaster, NodeCheckService, Request}),
    receive
        ok ->
            ok;
        {ok, Result} ->
            {ok, Result}
       after 10000 ->
            {error, timeout}
    end.

%% The first is the vnode service used
init({From, ReqID, _}, {VNodeMaster, NodeCheckService, Request}) ->
    %% all - full coverage; allup - partial coverage
    R = ?R,
    NVal = ?N,
    VNodeSelector = allup,
    %% Same as R value here, TODO: Make this dynamic
    PrimaryVNodeCoverage = R,
    %% We timeout after 5s
    Timeout = 5000,
    State = #state{replies = dict:new(), r = R,
                   from = From, reqid = ReqID},
    {Request, VNodeSelector, NVal, PrimaryVNodeCoverage,
     NodeCheckService, VNodeMaster, Timeout, State}.

process_results({ok, _ReqID, _IdxNode, Obj},
                State = #state{replies = Replies}) ->
    Replies1 = lists:foldl(fun (Key, D) ->
                                   dict:update_counter(Key, 1, D)
                           end, Replies, Obj),
    {done, State#state{replies = Replies1}};

process_results(Result, State) ->
    lager:error("Unknown process results call: ~p ~p", [Result, State]),
    {done, State}.

finish(clean, State = #state{replies = Replies,
                             from = From, r = R}) ->
    MergedReplies = dict:fold(fun(_Key, Count, Keys) when Count < R->
                                      Keys;
                                 (Key, _Count, Keys) ->
                                      [Key | Keys]
                              end, [], Replies),
    From ! {ok, MergedReplies},
    {stop, normal, State};

finish(How, State) ->
    lager:error("Unknown process results call: ~p ~p", [How, State]),
    {error, failed}.

%%%===================================================================
%%% Internal Functions
%%%===================================================================

mk_reqid() ->
    {MegaSecs,Secs,MicroSecs} = erlang:now(),
    (MegaSecs*1000000 + Secs)*1000000 + MicroSecs.
