%%--------------------------------------------------------------------
%% Copyright (c) 2020-2021 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_authz_api_mnesia).

-behavior(minirest_api).

-include("emqx_authz.hrl").
-include_lib("emqx/include/logger.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(EXAMPLE_USERNAME, #{type => username,
                            key => user1,
                            rules => [ #{topic => <<"test/toopic/1">>,
                                         permission => <<"allow">>,
                                         action => <<"publish">>
                                        }
                                     , #{topic => <<"test/toopic/2">>,
                                         permission => <<"allow">>,
                                         action => <<"subscribe">>
                                        }
                                     , #{topic => <<"eq test/#">>,
                                         permission => <<"deny">>,
                                         action => <<"all">>
                                        }
                                     ]
                           }).
-define(EXAMPLE_CLIENTID, #{type => clientid,
                            key => client1,
                            rules => [ #{topic => <<"test/toopic/1">>,
                                         permission => <<"allow">>,
                                         action => <<"publish">>
                                        }
                                     , #{topic => <<"test/toopic/2">>,
                                         permission => <<"allow">>,
                                         action => <<"subscribe">>
                                        }
                                     , #{topic => <<"eq test/#">>,
                                         permission => <<"deny">>,
                                         action => <<"all">>
                                        }
                                     ]
                           }).
-define(EXAMPLE_ALL ,     #{type => all,
                            rules => [ #{topic => <<"test/toopic/1">>,
                                         permission => <<"allow">>,
                                         action => <<"publish">>
                                        }
                                     , #{topic => <<"test/toopic/2">>,
                                         permission => <<"allow">>,
                                         action => <<"subscribe">>
                                        }
                                     , #{topic => <<"eq test/#">>,
                                         permission => <<"deny">>,
                                         action => <<"all">>
                                        }
                                     ]
                           }).

-export([ api_spec/0
        , purge/2
        , tickets/2
        , ticket/2
        ]).

api_spec() ->
    {[ purge_api()
     , tickets_api()
     , ticket_api()
     ], definitions()}.

definitions() ->
    Rules = #{
        type => array,
        items => #{
            type => object,
            required => [topic, permission, action],
            properties => #{
                topic => #{
                    type => string,
                    example => <<"test/topic/1">>
                },
                permission => #{
                    type => string,
                    enum => [<<"allow">>, <<"deny">>],
                    example => <<"allow">>
                },
                action => #{
                    type => string,
                    enum => [<<"publish">>, <<"subscribe">>, <<"all">>],
                    example => <<"publish">>
                }
            }
        }
    },
    Ticket = #{
        oneOf => [ #{type => object,
                     required => [username, rules],
                     properties => #{
                        username => #{
                            type => string,
                            example => <<"username">>
                        },
                        rules => minirest:ref(<<"rules">>)
                     }
                   }
                 , #{type => object,
                     required => [cleitnid, rules],
                     properties => #{
                        username => #{
                            type => string,
                            example => <<"clientid">>
                        },
                        rules => minirest:ref(<<"rules">>)
                     }
                   }
                 , #{type => object,
                     required => [rules],
                     properties => #{
                        rules => minirest:ref(<<"rules">>)
                     }
                   }
                 ]
    },
    [ #{<<"rules">> => Rules}
    , #{<<"ticket">> => Ticket}
    ].

purge_api() ->
    Metadata = #{
        delete => #{
            description => "Purge all tickets",
            responses => #{
                <<"204">> => #{description => <<"No Content">>},
                <<"400">> => emqx_mgmt_util:bad_request()
            }
        }
     },
    {"/authorization/sources/built-in-database/purge-all", Metadata, purge}.

tickets_api() ->
    Metadata = #{
        get => #{
            description => "List tickets",
            parameters => [
                #{
                    name => type,
                    in => path,
                    schema => #{
                       type => string,
                       enum => [<<"username">>, <<"clientid">>, <<"all">>]
                    },
                    required => true
                }
            ],
            responses => #{
                <<"200">> => #{
                    description => <<"OK">>,
                    content => #{
                        'application/json' => #{
                            schema => #{
                                type => array,
                                items => minirest:ref(<<"ticket">>)
                            },
                            examples => #{
                                username => #{
                                    summary => <<"Username">>,
                                    value => jsx:encode([?EXAMPLE_USERNAME])
                                },
                                clientid => #{
                                    summary => <<"Clientid">>,
                                    value => jsx:encode([?EXAMPLE_CLIENTID])
                                },
                                all => #{
                                    summary => <<"All">>,
                                    value => jsx:encode([?EXAMPLE_ALL])
                                }
                           }
                        }
                    }
                }
            }
        },
        post => #{
            description => "Add new tickets",
            parameters => [
                #{
                    name => type,
                    in => path,
                    schema => #{
                       type => string,
                       enum => [<<"username">>, <<"clientid">>]
                    },
                    required => true
                }
            ],
            requestBody => #{
                content => #{
                    'application/json' => #{
                        schema => minirest:ref(<<"ticket">>),
                        examples => #{
                            username => #{
                                summary => <<"Username">>,
                                value => jsx:encode(?EXAMPLE_USERNAME)
                            },
                            clientid => #{
                                summary => <<"Clientid">>,
                                value => jsx:encode(?EXAMPLE_CLIENTID)
                            }
                        }
                    }
                }
            },
            responses => #{
                <<"204">> => #{description => <<"Created">>},
                <<"400">> => emqx_mgmt_util:bad_request()
            }
        },
        put => #{
            description => "Set the list of rules for all",
            parameters => [
                #{
                    name => type,
                    in => path,
                    schema => #{
                       type => string,
                       enum => [<<"all">>]
                    },
                    required => true
                }
            ],
            requestBody => #{
                content => #{
                    'application/json' => #{
                        schema => minirest:ref(<<"ticket">>),
                        examples => #{
                            all => #{
                                summary => <<"All">>,
                                value => jsx:encode(?EXAMPLE_ALL)
                            }
                        }
                    }
                }
            },
            responses => #{
                <<"204">> => #{description => <<"Created">>},
                <<"400">> => emqx_mgmt_util:bad_request()
            }
        }
    },
    {"/authorization/sources/built-in-database/:type", Metadata, tickets}.

ticket_api() ->
    Metadata = #{
        get => #{
            description => "Get ticket info",
            parameters => [
                #{
                    name => type,
                    in => path,
                    schema => #{
                       type => string,
                       enum => [<<"username">>, <<"clientid">>]
                    },
                    required => true
                },
                #{
                    name => key,
                    in => path,
                    schema => #{
                       type => string
                    },
                    required => true
                }
            ],
            responses => #{
                <<"200">> => #{
                    description => <<"OK">>,
                    content => #{
                        'application/json' => #{
                            schema => minirest:ref(<<"ticket">>),
                            examples => #{
                                username => #{
                                    summary => <<"Username">>,
                                    value => jsx:encode(?EXAMPLE_USERNAME)
                                },
                                clientid => #{
                                    summary => <<"Clientid">>,
                                    value => jsx:encode(?EXAMPLE_CLIENTID)
                                },
                                all => #{
                                    summary => <<"All">>,
                                    value => jsx:encode(?EXAMPLE_ALL)
                                }
                            }
                        }
                    }
                },
                <<"404">> => emqx_mgmt_util:bad_request(<<"Not Found">>)
            }
        },
        put => #{
            description => "Update one ticket",
            parameters => [
                #{
                    name => type,
                    in => path,
                    schema => #{
                       type => string,
                       enum => [<<"username">>, <<"clientid">>]
                    },
                    required => true
                },
                #{
                    name => key,
                    in => path,
                    schema => #{
                       type => string
                    },
                    required => true
                }
            ],
            requestBody => #{
                content => #{
                    'application/json' => #{
                        schema => minirest:ref(<<"ticket">>),
                        examples => #{
                            username => #{
                                summary => <<"Username">>,
                                value => jsx:encode(?EXAMPLE_USERNAME)
                            },
                            clientid => #{
                                summary => <<"Clientid">>,
                                value => jsx:encode(?EXAMPLE_CLIENTID)
                            }
                        }
                    }
                }
            },
            responses => #{
                <<"204">> => #{description => <<"Updated">>},
                <<"400">> => emqx_mgmt_util:bad_request()
            }
        },
        delete => #{
            description => "Delete one ticket",
            parameters => [
                #{
                    name => type,
                    in => path,
                    schema => #{
                       type => string,
                       enum => [<<"username">>, <<"clientid">>]
                    },
                    required => true
                },
                #{
                    name => key,
                    in => path,
                    schema => #{
                       type => string
                    },
                    required => true
                }
            ],
            responses => #{
                <<"204">> => #{description => <<"No Content">>},
                <<"400">> => emqx_mgmt_util:bad_request()
            }
        }
    },
    {"/authorization/sources/built-in-database/:type/:key", Metadata, ticket}.

purge(delete, _) ->
    [ mnesia:dirty_delete(?ACL_TABLE, K) || K <- mnesia:dirty_all_keys(?ACL_TABLE)],
    {204}.

tickets(get, #{bindings := #{type := <<"username">>}}) ->
    MatchSpec = ets:fun2ms(
                  fun({?ACL_TABLE, {username, Username}, Rules}) ->
                          [{username, Username}, {rules, Rules}]
                  end),
    {200, [ #{username => Username,
              rules => [ #{topic => Topic,
                           action => Action,
                           permission => Permission
                          } || {Permission, Action, Topic} <- Rules]
             } || [{username, Username}, {rules, Rules}] <- ets:select(?ACL_TABLE, MatchSpec)]};
tickets(get, #{bindings := #{type := <<"clientid">>}}) ->
    MatchSpec = ets:fun2ms(
                  fun({?ACL_TABLE, {clientid, Clientid}, Rules}) ->
                          [{clientid, Clientid}, {rules, Rules}]
                  end),
    {200, [ #{clientid => Clientid,
              rules => [ #{topic => Topic,
                           action => Action,
                           permission => Permission
                          } || {Permission, Action, Topic} <- Rules]
             } || [{clientid, Clientid}, {rules, Rules}] <- ets:select(?ACL_TABLE, MatchSpec)]};
tickets(get, #{bindings := #{type := <<"all">>}}) ->
    MatchSpec = ets:fun2ms(
                  fun({?ACL_TABLE, all, Rules}) ->
                          [{rules, Rules}]
                  end),
    {200, [ #{rules => [ #{topic => Topic,
                           action => Action,
                           permission => Permission
                          } || {Permission, Action, Topic} <- Rules]
             } || [{rules, Rules}] <- ets:select(?ACL_TABLE, MatchSpec)]};
tickets(post, #{bindings := #{type := <<"username">>},
                body := #{<<"username">> := Username, <<"rules">> := Rules}}) ->
    Ticket = #emqx_acl{
                who = {username, Username},
                rules = format_rules(Rules)
               },
    case ret(mnesia:transaction(fun insert/1, [Ticket])) of
        ok -> {204};
        {error, Reason} ->
            {400, #{code => <<"BAD_REQUEST">>,
                    message => atom_to_binary(Reason)}}
    end;
tickets(post, #{bindings := #{type := <<"clientid">>},
                body := #{<<"clientid">> := Clientid, <<"rules">> := Rules}}) ->
    Ticket = #emqx_acl{
                who = {clientid, Clientid},
                rules = format_rules(Rules)
               },
    case ret(mnesia:transaction(fun insert/1, [Ticket])) of
        ok -> {204};
        {error, Reason} ->
            {400, #{code => <<"BAD_REQUEST">>,
                    message => atom_to_binary(Reason)}}
    end;
tickets(put, #{bindings := #{type := <<"all">>},
               body := #{<<"rules">> := Rules}}) ->
    Ticket = #emqx_acl{
                who = all,
                rules = format_rules(Rules)
               },
    case ret(mnesia:transaction(fun mnesia:write/1, [Ticket])) of
        ok -> {204};
        {error, Reason} ->
            {400, #{code => <<"BAD_REQUEST">>,
                    message => atom_to_binary(Reason)}}
    end.

ticket(get, #{bindings := #{type := <<"username">>, key := Key}}) ->
    case mnesia:dirty_read(?ACL_TABLE, {username, Key}) of
        [] -> {404, #{code => <<"NOT_FOUND">>, message => <<"Not Found">>}};
        [#emqx_acl{who = {username, Username}, rules = Rules}] ->
            {200, #{username => Username,
                    rules => [ #{topic => Topic,
                                 action => Action,
                                 permission => Permission
                                } || {Permission, Action, Topic} <- Rules]}
            }
    end;
ticket(get, #{bindings := #{type := <<"clientid">>, key := Key}}) ->
    case mnesia:dirty_read(?ACL_TABLE, {clientid, Key}) of
        [] -> {404, #{code => <<"NOT_FOUND">>, message => <<"Not Found">>}};
        [#emqx_acl{who = {clientid, Clientid}, rules = Rules}] ->
            {200, #{clientid => Clientid,
                    rules => [ #{topic => Topic,
                                 action => Action,
                                 permission => Permission
                                } || {Permission, Action, Topic} <- Rules]}
            }
    end;
ticket(put, #{bindings := #{type := <<"username">>, key := Username},
              body := #{<<"username">> := Username, <<"rules">> := Rules}}) ->
    case ret(mnesia:transaction(fun update/2, [{username, Username}, format_rules(Rules)])) of
        ok -> {204};
        {error, Reason} ->
            {400, #{code => <<"BAD_REQUEST">>,
                    message => atom_to_binary(Reason)}}
    end;
ticket(put, #{bindings := #{type := <<"clientid">>, key := Clientid},
              body := #{<<"clientid">> := Clientid, <<"rules">> := Rules}}) ->
    case ret(mnesia:transaction(fun update/2, [{clientid, Clientid}, format_rules(Rules)])) of
        ok -> {204};
        {error, Reason} ->
            {400, #{code => <<"BAD_REQUEST">>,
                    message => atom_to_binary(Reason)}}
    end;
ticket(delete, #{bindings := #{type := <<"username">>, key := Key}}) ->
    case ret(mnesia:transaction(fun mnesia:delete/1, [{?ACL_TABLE, {username, Key}}])) of
        ok -> {204};
        {error, Reason} ->
            {400, #{code => <<"BAD_REQUEST">>,
                    message => atom_to_binary(Reason)}}
    end;
ticket(delete, #{bindings := #{type := <<"clientid">>, key := Key}}) ->
    case ret(mnesia:transaction(fun mnesia:delete/1, [{?ACL_TABLE, {clientid, Key}}])) of
        ok -> {204};
        {error, Reason} ->
            {400, #{code => <<"BAD_REQUEST">>,
                    message => atom_to_binary(Reason)}}
    end.

format_rules(Rules) when is_list(Rules) ->
    lists:foldl(fun(#{<<"topic">> := Topic,
                      <<"action">> := Action,
                      <<"permission">> := Permission
                     }, AccIn) when ?PUBSUB(Action)
                            andalso ?ALLOW_DENY(Permission) ->
                   AccIn ++ [{ atom(Permission), atom(Action), Topic }]
                end, [], Rules).

atom(B) when is_binary(B) ->
    try binary_to_existing_atom(B, utf8)
    catch
        _ -> binary_to_atom(B)
    end;
atom(A) when is_atom(A) -> A.

insert(Ticket = #emqx_acl{who = Who}) ->
    case mnesia:read(?ACL_TABLE, Who) of
        []    -> mnesia:write(Ticket);
        [_|_] -> mnesia:abort(existed)
    end.

update(Who, Rules) ->
    case mnesia:read(?ACL_TABLE, Who) of
        [#emqx_acl{} = Ticket] ->
            mnesia:write(Ticket#emqx_acl{rules = Rules});
        [] -> mnesia:abort(noexisted)
    end.

ret({atomic, ok})     -> ok;
ret({aborted, Error}) -> {error, Error}.
